local function hasTablet(source)
    return (exports.ox_inventory:GetItemCount(source, Config.Tablet.item) or 0) > 0
end

local function isAdmin(source)
    if IsPlayerAceAllowed(source, Config.Tablet.adminAce or 'mediora.admin') then return true end
    -- Match Qbox's existing admin/god ACEs, without granting ordinary players access.
    for _, ace in ipairs(Config.Tablet.adminAces or { 'admin', 'god' }) do
        if IsPlayerAceAllowed(source, ace) then return true end
    end
    return false
end

local function getPersonnelManager(source)
    if not hasTablet(source) then return end
    local player = exports.qbx_core:GetPlayer(source)
    local data = player and player.PlayerData
    local job = data and data.job
    if not job or Config.DutyTracking.jobs[job.name] ~= true then return end
    local minimum = Config.Tablet.personnelMinGrades[job.name]
    local level = job.grade and job.grade.level
    if not minimum or type(level) ~= 'number' or level < minimum then return end
    local definition = exports.qbx_core:GetJob(job.name)
    if not definition or not definition.grades[level] then return end
    return data, definition.grades
end

local function characterName(data)
    local info = data.charinfo or {}
    local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
    return name ~= '' and name or '氏名未登録'
end

local personnelDenied = '隊員管理には医療端末と所属先の管理権限が必要です。'

lib.callback.register('ptech_mediora_core:tabletPersonnel', function(source)
    local manager, grades = getPersonnelManager(source)
    if not manager then return { ok = false, error = personnelDenied } end
    local job = manager.job.name
    local managerLevel = manager.job.grade.level
    local members, candidates, options, enrolled = {}, {}, {}, {}
    for level, grade in pairs(grades) do
        if level < managerLevel and grade.isboss ~= true then
            options[#options + 1] = { level = level, name = grade.name }
        end
    end
    table.sort(options, function(a, b) return a.level < b.level end)

    for _, row in ipairs(exports.qbx_core:GetGroupMembers(job, 'job')) do
        local id = row.citizenid
        enrolled[id] = true
        local online = exports.qbx_core:GetPlayerByCitizenId(id)
        local player = online or exports.qbx_core:GetOfflinePlayer(id)
        local data = player and player.PlayerData
        if data then
            local level = data.jobs and data.jobs[job] or tonumber(row.grade)
            local grade = grades[level]
            members[#members + 1] = {
                id = id, name = characterName(data), level = level,
                grade = grade and grade.name or '階級未登録',
                state = online and (data.job.name == job and data.job.onduty and '勤務中' or '退勤中') or 'オフライン',
                editable = id ~= manager.citizenid and grade ~= nil and level < managerLevel and grade.isboss ~= true,
            }
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local online = exports.qbx_core:GetPlayer(tonumber(playerId))
        local data = online and online.PlayerData
        if data and not enrolled[data.citizenid] and not data.jobs[job] then
            candidates[#candidates + 1] = { id = data.citizenid, source = tonumber(playerId), name = characterName(data) }
        end
    end
    local current = getPersonnelManager(source)
    if not current or current.citizenid ~= manager.citizenid or current.job.name ~= job or current.job.grade.level ~= managerLevel then
        return { ok = false, error = personnelDenied }
    end
    table.sort(members, function(a, b) return a.name < b.name end)
    table.sort(candidates, function(a, b) return a.name < b.name end)
    return { ok = true, members = members, candidates = candidates, grades = options }
end)

local personnelLocks = {}

local function changePersonnel(source, request)
    local manager = getPersonnelManager(source)
    if not manager then return { ok = false, error = personnelDenied } end
    local job, managerId = manager.job.name, manager.citizenid
    local id, action = request.id, request.action
    local online = exports.qbx_core:GetPlayerByCitizenId(id)
    local target = online or (action ~= 'hire' and exports.qbx_core:GetOfflinePlayer(id))
    local data = target and target.PlayerData
    if not data or id == managerId or (action == 'hire' and data.source ~= request.source) then
        return { ok = false, error = '対象の隊員を確認できません。' }
    end

    local current, grades = getPersonnelManager(source)
    if not current or current.citizenid ~= managerId or current.job.name ~= job then
        return { ok = false, error = personnelDenied }
    end
    local managerLevel = current.job.grade.level
    local level = data.jobs[job]
    if action == 'hire' then
        if level ~= nil then return { ok = false, error = 'この隊員はすでに所属しています。' } end
    elseif level == nil or level ~= request.currentLevel or level >= managerLevel or not grades[level] or grades[level].isboss == true then
        return { ok = false, error = '対象の階級が変更されたか、操作権限がありません。一覧を更新してください。' }
    end

    local success, err
    if action == 'dismiss' then
        success, err = exports.qbx_core:RemovePlayerFromJob(id, job)
    else
        local nextLevel = request.level
        local grade = type(nextLevel) == 'number' and grades[nextLevel]
        if not grade or nextLevel >= managerLevel or grade.isboss == true then
            return { ok = false, error = 'その階級には設定できません。' }
        end
        local wasOnDuty = online and data.job.name == job and data.job.onduty
        success, err = exports.qbx_core:AddPlayerToJob(id, job, nextLevel)
        if success and type(wasOnDuty) == 'boolean' then
            local updated = exports.qbx_core:GetPlayerByCitizenId(id)
            local updatedJob = updated and updated.PlayerData.job
            if updatedJob and updatedJob.name == job and updatedJob.grade.level == nextLevel and updatedJob.onduty ~= wasOnDuty then
                exports.qbx_core:SetJobDuty(updated.PlayerData.source, wasOnDuty)
            end
        end
    end
    if not success then
        local message = err and err.code == 'max_jobs' and '対象者の兼職枠が上限に達しています。' or '人事情報を保存できませんでした。'
        return { ok = false, error = message }
    end
    print(('[ptech_mediora_core] personnel: %s job=%s actor=%s target=%s grade=%s'):format(action, job, managerId, id, tostring(request.level)))
    return { ok = true }
end

lib.callback.register('ptech_mediora_core:tabletPersonnelAction', function(source, request)
    if not getPersonnelManager(source) then return { ok = false, error = personnelDenied } end
    if type(request) ~= 'table' or type(request.id) ~= 'string' or #request.id > 64 or request.id == ''
        or (request.action ~= 'hire' and request.action ~= 'grade' and request.action ~= 'dismiss') then
        return { ok = false, error = '操作内容を確認できません。' }
    end
    local id = request.id
    if personnelLocks[id] then return { ok = false, error = 'この隊員の変更を処理中です。' } end
    personnelLocks[id] = true
    local ok, result = pcall(changePersonnel, source, request)
    personnelLocks[id] = nil
    if not ok then
        print(('[ptech_mediora_core] personnel action error: %s'):format(tostring(result)))
        return { ok = false, error = '変更結果を確認できませんでした。一覧を更新してください。' }
    end
    return result
end)

lib.callback.register('ptech_mediora_core:tabletAccess', function(source)
    if not hasTablet(source) then return { ok = false, error = 'item_required' } end
    return { ok = true, admin = isAdmin(source), personnel = getPersonnelManager(source) ~= nil }
end)

lib.callback.register('ptech_mediora_core:tabletHome', function(source, request)
    if not hasTablet(source) then return { ok = false, error = '医療端末を所持していません。' } end
    local jobs = Config.DutyTracking.jobs

    local includeRoster = type(request) == 'table' and request.roster == true
    local count, roster = 0, {}
    for _, playerId in ipairs(GetPlayers()) do
        local player = exports.qbx_core:GetPlayer(tonumber(playerId))
        local data = player and player.PlayerData
        local job = data and data.job
        if job and jobs[job.name] and job.onduty == true then
            count = count + 1
            if includeRoster then
                roster[#roster + 1] = {
                    name = characterName(data),
                    grade = job.grade and job.grade.name or '階級未登録',
                }
            end
        end
    end
    table.sort(roster, function(a, b) return a.name < b.name end)
    return { ok = true, count = count, roster = includeRoster and roster or nil, announcements = Config.Tablet.HomeAnnouncements or {} }
end)

local resourceLocks = {}
local operations = {}
local lifecycle = {}
local function markLifecycle(name, event)
    local record = lifecycle[name] or { starts = 0, stops = 0 }
    record[event] = record[event] + 1
    lifecycle[name] = record
end
AddEventHandler('onResourceStop', function(name) markLifecycle(name, 'stops') end)
AddEventHandler('onResourceStart', function(name) markLifecycle(name, 'starts') end)
local function waitForCommand(name, action, before, timeout)
    local deadline = GetGameTimer() + timeout
    local expected = action == 'stop' and 'stopped' or 'started'
    local function completed()
        local events = lifecycle[name] or { starts = 0, stops = 0 }
        if action == 'restart' and (events.starts <= before.starts or events.stops <= before.stops) then return false end
        return GetResourceState(name) == expected
    end
    repeat
        if completed() then return true end
        Wait(100)
    until GetGameTimer() >= deadline
    return completed()
end
lib.callback.register('ptech_mediora_core:tabletResourceAction', function(source, data)
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    if not hasTablet(source) then return { ok = false, error = 'item_required' } end
    if type(data) ~= 'table' then return { ok = false, error = 'invalid_action' } end
    local name, action = data.name, data.action
    if type(name) ~= 'string' or not name:match('^ptech_mediora_[a-z0-9_]+$') then
        return { ok = false, error = 'invalid_resource' }
    end
    if action ~= 'start' and action ~= 'stop' and action ~= 'restart' then
        return { ok = false, error = 'invalid_action' }
    end
    local core = GetCurrentResourceName()
    if name == core then return { ok = false, error = 'core_protected' } end
    if resourceLocks[name] then return { ok = false, error = 'busy' } end
    local state = GetResourceState(name)
    if (action == 'start' and state ~= 'stopped') or (action ~= 'start' and state ~= 'started') then
        return { ok = false, error = 'invalid_state' }
    end
    if not IsPrincipalAceAllowed('resource.' .. core, 'command.' .. action) then
        print(('[%s] Resource command denied: missing command.%s ACE'):format(core, action))
        return { ok = false, error = 'command_permission' }
    end
    resourceLocks[name] = true
    operations[name] = { action = action, phase = 'pending', time = os.time() }
    local events = lifecycle[name] or { starts = 0, stops = 0 }
    local before = { starts = events.starts, stops = events.stops }
    local ok, success = pcall(function()
        -- Run the exact built-in server command, with a validated resource name.
        ExecuteCommand(action .. ' ' .. name)
        return waitForCommand(name, action, before, 8000)
    end)
    operations[name] = { action = action, phase = ok and success and 'complete' or 'failed', time = os.time() }
    SetTimeout(1500, function() resourceLocks[name] = nil end)
    print(('[%s] Resource action: player=%s action=%s resource=%s success=%s'):format(core, source, action, name, tostring(ok and success)))
    return { ok = ok and success == true, error = (not ok or not success) and 'operation_failed' or nil, state = GetResourceState(name) }
end)

lib.callback.register('ptech_mediora_core:tabletResources', function(source)
    -- Always authorize here; hiding a UI button is not access control.
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    if not hasTablet(source) then return { ok = false, error = 'item_required' } end
    local resources = {}
    for index = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(index)
        if name and name:match('^ptech_mediora_') then
            resources[#resources + 1] = { name = name, state = GetResourceState(name), operation = operations[name], consoleOnly = name == GetCurrentResourceName() }
        end
    end
    table.sort(resources, function(a, b) return a.name < b.name end)
    return { ok = true, resources = resources }
end)
