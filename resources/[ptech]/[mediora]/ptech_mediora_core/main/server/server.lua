local currentResource = GetCurrentResourceName()
local locks = {}
local dutySessions = {}

local function log(message)
    print(('[%s] %s'):format(currentResource, message))
end

local function notify(source, message, notifyType)
    if source == 0 then
        log(message)
        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        type = notifyType,
        description = message,
    })
end

local function getPlayer(source)
    if type(source) ~= 'number' or source < 1 then return nil end
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    return ok and player or nil
end

local function getCitizenId(source)
    local player = getPlayer(source)
    local data = player and player.PlayerData
    return data and data.citizenid or nil
end

local function getActorCitizenId(source)
    if type(source) ~= 'number' or source < 1 then return nil end
    return getCitizenId(source)
end

local function invokingResource(fallback)
    local resource = GetInvokingResource()
    if type(resource) == 'string' and resource ~= '' then return resource end
    return fallback or 'unknown'
end

local function validText(value, maxLength, allowEmpty)
    if type(value) ~= 'string' then return false end
    if not allowEmpty and value:match('^%s*$') then return false end
    return #value <= maxLength
end

local function acquireLock(key)
    local lock = locks[key]
    if not lock then
        locks[key] = { busy = true, queue = {} }
        return
    end

    local waiter = promise.new()
    lock.queue[#lock.queue + 1] = waiter
    Citizen.Await(waiter)
end

local function releaseLock(key)
    local lock = locks[key]
    if not lock then return end

    local nextWaiter = table.remove(lock.queue, 1)
    if nextWaiter then
        nextWaiter:resolve(true)
    else
        locks[key] = nil
    end
end

local function withCitizenLock(citizenid, callback)
    acquireLock(citizenid)
    local ok, first, second = xpcall(callback, debug.traceback)
    releaseLock(citizenid)
    if not ok then
        log(('database operation failed for %s: %s'):format(citizenid, tostring(first)))
        return false, 'database_error'
    end
    return first, second
end

local function isInteger(value)
    return type(value) == 'number' and value == math.floor(value)
end

local function changePoints(source, amount, action, reason, actorSource, sourceResource)
    if not isInteger(source) or source < 1 or not isInteger(amount) or amount == 0
        or math.abs(amount) > Config.Points.maxChangePerTransaction then
        return false, 'invalid_arguments'
    end
    if action ~= 'grant' and action ~= 'spend' then return false, 'invalid_action' end
    if action == 'grant' and amount < 0 then return false, 'invalid_amount' end
    if action == 'spend' and amount < 0 then return false, 'invalid_amount' end
    if not validText(reason, 255, false) then return false, 'invalid_reason' end

    local citizenid = getCitizenId(source)
    if not citizenid then return false, 'player_not_found' end

    local delta = action == 'grant' and amount or -amount
    local resourceName = sourceResource or invokingResource(action == 'grant' and 'work' or 'unknown')
    if not validText(resourceName, 64, false) then resourceName = 'unknown' end
    local actorCitizenid = getActorCitizenId(actorSource)

    return withCitizenLock(citizenid, function()
        local row = MySQL.single.await(
            'SELECT `mp_balance` FROM `ptech_mediora_core_accounts` WHERE `citizenid` = ?',
            { citizenid }
        )
        local currentBalance = row and tonumber(row.mp_balance) or 0
        if action == 'spend' and currentBalance < amount then
            return false, 'insufficient_points'
        end

        local newBalance = currentBalance + delta
        local earnedDelta = action == 'grant' and amount or 0
        local success = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO `ptech_mediora_core_accounts`
                        (`citizenid`, `mp_balance`, `mp_earned`)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        `mp_balance` = `mp_balance` + VALUES(`mp_balance`),
                        `mp_earned` = `mp_earned` + VALUES(`mp_earned`)
                ]],
                values = { citizenid, delta, earnedDelta },
            },
            {
                query = [[
                    INSERT INTO `ptech_mediora_core_point_log`
                        (`citizenid`, `delta`, `balance_after`, `action`, `source_resource`, `reason`, `actor_citizenid`)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]],
                values = { citizenid, delta, newBalance, action, resourceName, reason, actorCitizenid },
            },
        })

        if not success then return false, 'database_error' end
        return true, newBalance
    end)
end

local function addPoints(source, amount, reason, actorSource)
    return changePoints(source, amount, 'grant', reason, actorSource, invokingResource('work'))
end

local function spendPoints(source, amount, reason)
    return changePoints(source, amount, 'spend', reason, nil, invokingResource('unknown'))
end

local function getPoints(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return nil end
    local row = MySQL.single.await([[
        SELECT `mp_balance`, `mp_earned`
        FROM `ptech_mediora_core_accounts`
        WHERE `citizenid` = ?
    ]], { citizenid })

    local balance = row and tonumber(row.mp_balance) or 0
    local totalEarned = row and tonumber(row.mp_earned) or 0
    return {
        id = Config.Points.identifier,
        balance = balance,
        totalEarned = totalEarned,
        totalSpent = math.max(0, totalEarned - balance),
    }
end

local function getProfile(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return nil end

    local account = MySQL.single.await([[
        SELECT `mp_balance`, `mp_earned`, `duty_seconds`
        FROM `ptech_mediora_core_accounts`
        WHERE `citizenid` = ?
    ]], { citizenid })
    local rows = MySQL.query.await([[
        SELECT `metric_key`, `total`
        FROM `ptech_mediora_core_activity_stats`
        WHERE `citizenid` = ?
    ]], { citizenid }) or {}

    local activities = {}
    for i = 1, #rows do
        activities[rows[i].metric_key] = tonumber(rows[i].total) or 0
    end

    local balance = account and tonumber(account.mp_balance) or 0
    local totalEarned = account and tonumber(account.mp_earned) or 0
    return {
        citizenid = citizenid,
        points = {
            id = Config.Points.identifier,
            balance = balance,
            totalEarned = totalEarned,
            totalSpent = math.max(0, totalEarned - balance),
        },
        dutySeconds = account and tonumber(account.duty_seconds) or 0,
        activities = activities,
    }
end

local function recordActivity(source, metricKey, amount, reason)
    if not isInteger(source) or source < 1 then return false, 'invalid_source' end
    if type(metricKey) ~= 'string' or #metricKey < 1 or #metricKey > Config.ActivityTracking.maxKeyLength then
        return false, 'invalid_metric_key'
    end
    if not metricKey:match('^[a-z0-9_%-]+$') then return false, 'invalid_metric_key' end
    if type(amount) ~= 'number' or amount <= 0 or amount > Config.ActivityTracking.maxAmount then
        return false, 'invalid_amount'
    end
    if not validText(reason or '', 255, true) then return false, 'invalid_reason' end

    local citizenid = getCitizenId(source)
    if not citizenid then return false, 'player_not_found' end
    local resourceName = invokingResource('unknown')

    local success = MySQL.transaction.await({
        {
            query = [[
                INSERT INTO `ptech_mediora_core_activity_stats` (`citizenid`, `metric_key`, `total`)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE `total` = `total` + VALUES(`total`)
            ]],
            values = { citizenid, metricKey, amount },
        },
        {
            query = [[
                INSERT INTO `ptech_mediora_core_activity_log`
                    (`citizenid`, `metric_key`, `amount`, `source_resource`, `reason`)
                VALUES (?, ?, ?, ?, ?)
            ]],
            values = { citizenid, metricKey, amount, resourceName, reason or '' },
        },
    })

    if not success then return false, 'database_error' end
    return true
end

local function getActivityTotal(source, metricKey)
    local citizenid = getCitizenId(source)
    if not citizenid or type(metricKey) ~= 'string' then return nil end
    local total = MySQL.scalar.await([[
        SELECT `total` FROM `ptech_mediora_core_activity_stats`
        WHERE `citizenid` = ? AND `metric_key` = ?
    ]], { citizenid, metricKey })
    return tonumber(total) or 0
end

local function getLeaderboard(metricKey, limit)
    if type(metricKey) ~= 'string' or #metricKey < 1 or #metricKey > Config.ActivityTracking.maxKeyLength
        or not metricKey:match('^[a-z0-9_%-]+$') then
        return nil, 'invalid_metric_key'
    end
    limit = tonumber(limit) or 10
    if not isInteger(limit) then return nil, 'invalid_limit' end
    limit = math.max(1, math.min(limit, 50))

    local rows
    if metricKey == 'duty_seconds' or metricKey == 'mp_earned' then
        rows = MySQL.query.await(([[
            SELECT `citizenid`, `%s` AS `total`
            FROM `ptech_mediora_core_accounts`
            WHERE `%s` > 0
            ORDER BY `%s` DESC, `citizenid` ASC
            LIMIT %d
        ]]):format(metricKey, metricKey, metricKey, limit))
    else
        rows = MySQL.query.await(([[
            SELECT `citizenid`, `total`
            FROM `ptech_mediora_core_activity_stats`
            WHERE `metric_key` = ?
            ORDER BY `total` DESC, `citizenid` ASC
            LIMIT %d
        ]]):format(limit), { metricKey })
    end

    return rows or {}
end

local function addDutySeconds(citizenid, seconds)
    if not citizenid or seconds <= 0 then return true end
    local ok, err = pcall(function()
        MySQL.update.await([[
            INSERT INTO `ptech_mediora_core_accounts` (`citizenid`, `duty_seconds`)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE `duty_seconds` = `duty_seconds` + VALUES(`duty_seconds`)
        ]], { citizenid, seconds })
    end)
    if not ok then log(('failed to save duty time for %s: %s'):format(citizenid, tostring(err))) end
    return ok
end

local function flushDuty(source, now)
    local session = dutySessions[source]
    if not session then return end
    now = now or os.time()
    local seconds = math.max(0, now - session.lastSavedAt)
    if addDutySeconds(session.citizenid, seconds) then
        session.lastSavedAt = now
    end
end

local function isTrackedDuty(job)
    return type(job) == 'table'
        and type(job.name) == 'string'
        and Config.DutyTracking.jobs[job.name] == true
        and job.onduty == true
end

local function syncDuty(source, jobOverride)
    local player = getPlayer(source)
    if not player or not player.PlayerData then
        flushDuty(source)
        dutySessions[source] = nil
        return
    end

    local data = player.PlayerData
    local job = jobOverride or data.job
    local citizenid = data.citizenid
    local activeSession = dutySessions[source]
    local shouldTrack = citizenid and isTrackedDuty(job)

    if activeSession and (not shouldTrack or activeSession.citizenid ~= citizenid) then
        flushDuty(source)
        dutySessions[source] = nil
        activeSession = nil
    end

    if shouldTrack and not activeSession then
        dutySessions[source] = {
            citizenid = citizenid,
            jobName = job.name,
            lastSavedAt = os.time(),
        }
    end
end

local function saveDutyAll()
    local now = os.time()
    for source in pairs(dutySessions) do flushDuty(source, now) end
end

exports('AddPoints', addPoints)
exports('SpendPoints', spendPoints)
exports('GetPoints', getPoints)
exports('GetProfile', getProfile)
exports('RecordActivity', recordActivity)
exports('GetActivityTotal', getActivityTotal)
exports('GetLeaderboard', getLeaderboard)

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    local player = getPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if job and type(onDuty) == 'boolean' then
        local updatedJob = {}
        for key, value in pairs(job) do updatedJob[key] = value end
        updatedJob.onduty = onDuty
        syncDuty(source, updatedJob)
        return
    end
    syncDuty(source)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    syncDuty(source, job)
end)

AddEventHandler('qbx_core:server:onGroupUpdate', function(source, group, grade)
    if grade == nil and Config.DutyTracking.jobs[group] then syncDuty(source) end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    flushDuty(source)
    dutySessions[source] = nil
end)

AddEventHandler('playerDropped', function()
    local source = source
    flushDuty(source)
    dutySessions[source] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    syncDuty(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= currentResource then return end
    CreateThread(function()
        Wait(1000)
        for _, source in ipairs(GetPlayers()) do
            syncDuty(tonumber(source))
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == currentResource then saveDutyAll() end
end)

CreateThread(function()
    while true do
        Wait(math.max(30, Config.DutyTracking.saveIntervalSeconds) * 1000)
        saveDutyAll()
    end
end)

RegisterCommand(Config.Points.manualGrantCommand, function(source, args)
    local targetSource = tonumber(args[1])
    local amount = tonumber(args[2])
    local reason = table.concat(args, ' ', 3)

    if not targetSource or not isInteger(targetSource) or not amount or not isInteger(amount) or amount <= 0
        or not validText(reason, 255, false) then
        local usage = ('使い方: /%s [プレイヤーID] [MP数] [理由]'):format(Config.Points.manualGrantCommand)
        notify(source, usage, 'error')
        return
    end

    local actorSource = source > 0 and source or nil
    local ok, balance = changePoints(targetSource, amount, 'grant', reason, actorSource, 'manual')
    if not ok then
        local message = ('MP付与に失敗しました: %s'):format(tostring(balance))
        notify(source, message, 'error')
        return
    end

    local targetName = GetPlayerName(targetSource) or tostring(targetSource)
    local message = ('%s に %d MP を付与しました（現在: %d MP）'):format(targetName, amount, balance)
    notify(source, message, 'success')
    log(('%s: %s'):format(source > 0 and (getCitizenId(source) or 'unknown') or 'console', message))
end, true)

log(('共有%s・業務実績・勤務時間記録を起動しました。SQL導入を確認してください。'):format(Config.Points.label))
