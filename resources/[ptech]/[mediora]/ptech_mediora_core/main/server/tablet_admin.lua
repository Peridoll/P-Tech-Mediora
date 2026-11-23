-- Rank labels come from the current Qbox definition, never cached PlayerData names.
local function currentGradeName(job, fallback)
    local level = job and job.grade and tonumber(job.grade.level)
    local definition = job and job.name and exports.qbx_core:GetJob(job.name)
    local grade = definition and definition.grades and level and definition.grades[level]
    return grade and grade.name or fallback
end

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

local rescueSettingsKey = 'tabletRescueSettings'
local rescueSettings = {
    pd = { enabled = true, minutes = 5 },
    other = { enabled = false, minutes = 5 },
}

local function validRescueSettings(settings)
    if type(settings) ~= 'table' then return false end
    for _, group in ipairs({ 'pd', 'other' }) do
        local entry = settings[group]
        if type(entry) ~= 'table' or type(entry.enabled) ~= 'boolean'
            or type(entry.minutes) ~= 'number' or entry.minutes < 0 or entry.minutes > 1440
            or entry.minutes % 1 ~= 0 then return false end
    end
    return true
end

local storedRescueSettings = GetResourceKvpString(rescueSettingsKey)
if storedRescueSettings then
    local ok, decoded = pcall(json.decode, storedRescueSettings)
    if ok and validRescueSettings(decoded) then rescueSettings = decoded end
end

exports('getRescueSettings', function(isPd)
    local entry = rescueSettings[isPd and 'pd' or 'other']
    return entry.enabled, entry.minutes * 60000
end)

lib.callback.register('ptech_mediora_core:tabletRescueSave', function(source, settings)
    if not hasTablet(source) or not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    if not validRescueSettings(settings) then return { ok = false, error = 'invalid_settings' } end
    local clean = {
        pd = { enabled = settings.pd.enabled, minutes = settings.pd.minutes },
        other = { enabled = settings.other.enabled, minutes = settings.other.minutes },
    }
    SetResourceKvp(rescueSettingsKey, json.encode(clean))
    rescueSettings = clean
    return { ok = true }
end)

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

local function personnelMultijob()
    local resource = Config.Tablet.multijobResource
    if resource == false then return nil end
    resource = resource or 'ps-multijob'
    local state = GetResourceState(resource)
    if state == 'missing' then return nil end
    if state ~= 'started' then
        return nil, 'マルチジョブ管理が停止中です。起動してから役職を変更してください。'
    end
    return resource
end

local function syncPersonnelMultijob(resource, citizenid, job, grade)
    if not resource then return true end
    local ok, err = pcall(function()
        if grade == nil then exports[resource]:RemoveJob(citizenid, job)
        else exports[resource]:AddJob(citizenid, job, grade) end
    end)
    if not ok then return false, err end
    -- ps-multijob writes asynchronously. Do not report success until its saved roster agrees.
    local deadline = GetGameTimer() + 5000
    repeat
        if GetResourceState(resource) ~= 'started' then return false, 'multijob_stopped' end
        local readOk, jobs = pcall(function() return exports[resource]:GetJobs(citizenid) end)
        if not readOk then return false, jobs end
        if type(jobs) == 'table' and ((grade == nil and jobs[job] == nil)
            or (grade ~= nil and tonumber(jobs[job]) == grade)) then return true end
        Wait(100)
    until GetGameTimer() >= deadline
    return false, 'multijob_save_not_confirmed'
end

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

    local multijob, multijobError = personnelMultijob()
    if multijobError then return { ok = false, error = multijobError } end
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
    local syncedGrade
    if action ~= 'dismiss' then syncedGrade = request.level end
    local synced, syncError = syncPersonnelMultijob(multijob, id, job, syncedGrade)
    if not synced then
        print(('[ptech_mediora_core] personnel multijob sync failed: job=%s target=%s error=%s'):format(job, id, tostring(syncError)))
        return { ok = false, error = '役職は変更されましたが、マルチジョブ側の保存を確認できませんでした。一覧を更新し、同じ役職でもう一度設定してください。' }
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


local announcementKey = 'tabletHomeAnnouncements'
local function validAnnouncementText(value, limit)
    if type(value) ~= 'string' or #value > limit * 4 then return false end
    local length = utf8.len(value)
    return length ~= nil and length > 0 and length <= limit and value:find('%S') ~= nil
end

local function validAnnouncementState(state)
    if type(state) ~= 'table' or type(state.items) ~= 'table'
        or type(state.revision) ~= 'number' or state.revision < 0 or state.revision % 1 ~= 0
        or type(state.nextId) ~= 'number' or state.nextId < 1 or state.nextId % 1 ~= 0 then return false end
    local ids = {}
    for _, item in ipairs(state.items) do
        if type(item) ~= 'table' or type(item.id) ~= 'number' or item.id < 1
            or item.id % 1 ~= 0 or item.id >= state.nextId or ids[item.id]
            or not validAnnouncementText(item.title, 120) or not validAnnouncementText(item.body, 4000) then return false end
        ids[item.id] = true
    end
    return true
end

-- Configured notices seed the state until its first successful tablet save.
local announcementState = { revision = 0, nextId = 1, items = {} }
for _, item in ipairs(Config.Tablet.HomeAnnouncements or {}) do
    if validAnnouncementText(item.title, 120) and validAnnouncementText(item.body, 4000) then
        announcementState.items[#announcementState.items + 1] = {
            id = announcementState.nextId, title = item.title, body = item.body,
        }
        announcementState.nextId = announcementState.nextId + 1
    end
end
local savedAnnouncements = GetResourceKvpString(announcementKey)
if savedAnnouncements then
    local ok, state = pcall(json.decode, savedAnnouncements)
    if ok and validAnnouncementState(state) then
        announcementState = state
    else
        announcementState = nil
        print('[ptech_mediora_core] Saved home announcements could not be read')
    end
end

lib.callback.register('ptech_mediora_core:tabletAnnouncementSave', function(source, request)
    local manager = getPersonnelManager(source)
    if not manager then return { ok = false, error = 'お知らせの編集には上官以上の権限が必要です。' } end
    if not announcementState then return { ok = false, error = 'お知らせを保存できません。管理者に確認してください。' } end
    if type(request) ~= 'table' then return { ok = false, error = '投稿内容を確認してください。' } end
    if request.revision ~= announcementState.revision then
        return { ok = false, error = 'ほかの職員がお知らせを更新しました。ホームを開き直して内容を確認してください。' }
    end
    local title = type(request.title) == 'string' and request.title:match('^%s*(.-)%s*$')
    local body = type(request.body) == 'string' and request.body:match('^%s*(.-)%s*$')
    if not validAnnouncementText(title, 120) or not validAnnouncementText(body, 4000) then
        return { ok = false, error = '見出しは120文字、本文は4000文字以内で入力してください。' }
    end
    local index
    if request.id ~= nil then
        for i, item in ipairs(announcementState.items) do
            if item.id == request.id then index = i; break end
        end
        if not index then return { ok = false, error = '編集するお知らせが見つかりません。' } end
    elseif #announcementState.items >= 50 then
        return { ok = false, error = 'お知らせは50件まで掲載できます。' }
    end

    local nextState = {
        revision = announcementState.revision + 1,
        nextId = announcementState.nextId,
        items = {},
    }
    for i, item in ipairs(announcementState.items) do nextState.items[i] = item end
    local item = {
        id = index and request.id or nextState.nextId,
        title = title, body = body, author = characterName(manager), updatedAt = os.time(),
    }
    if index then nextState.items[index] = item
    else
        table.insert(nextState.items, 1, item)
        nextState.nextId = nextState.nextId + 1
    end
    local encoded = json.encode(nextState)
    local ok, err = pcall(function()
        SetResourceKvp(announcementKey, encoded)
        assert(GetResourceKvpString(announcementKey) == encoded, 'announcement persistence failed')
    end)
    if not ok then
        -- The write may have succeeded before its acknowledgement failed.
        local stored = GetResourceKvpString(announcementKey)
        if stored then
            local decoded, state = pcall(json.decode, stored)
            announcementState = decoded and validAnnouncementState(state) and state or nil
        end
        print(('[ptech_mediora_core] Home announcement save failed: %s'):format(tostring(err)))
        return { ok = false, error = '保存結果を確認できませんでした。ホームを開き直して確認してください。' }
    end
    announcementState = nextState
    return { ok = true }
end)

lib.callback.register('ptech_mediora_core:tabletAnnouncementDelete', function(source, request)
    if not getPersonnelManager(source) then
        return { ok = false, error = 'お知らせの削除には上官以上の権限が必要です。' }
    end
    if not announcementState then return { ok = false, error = 'お知らせを削除できません。管理者に確認してください。' } end
    if type(request) ~= 'table' or type(request.id) ~= 'number' or request.id <= 0 or request.id % 1 ~= 0 then
        return { ok = false, error = '削除するお知らせを選択してください。' }
    end
    if request.revision ~= announcementState.revision then
        return { ok = false, error = 'ほかの職員がお知らせを更新しました。更新して内容を確認してください。' }
    end
    local nextState = { revision = announcementState.revision + 1, nextId = announcementState.nextId, items = {} }
    local found = false
    for _, item in ipairs(announcementState.items) do
        if item.id == request.id then found = true
        else nextState.items[#nextState.items + 1] = item end
    end
    if not found then return { ok = false, error = '削除するお知らせが見つかりません。更新して確認してください。' } end
    local encoded = json.encode(nextState)
    local ok, err = pcall(function()
        SetResourceKvp(announcementKey, encoded)
        assert(GetResourceKvpString(announcementKey) == encoded, 'announcement persistence failed')
    end)
    if not ok then
        local stored = GetResourceKvpString(announcementKey)
        if stored then
            local decoded, state = pcall(json.decode, stored)
            announcementState = decoded and validAnnouncementState(state) and state or nil
        end
        print(('[ptech_mediora_core] Home announcement delete failed: %s'):format(tostring(err)))
        return { ok = false, error = '削除結果を確認できませんでした。更新して確認してください。' }
    end
    announcementState = nextState
    return { ok = true }
end)

lib.callback.register('ptech_mediora_core:tabletAccess', function(source)
    if not hasTablet(source) then return { ok = false, error = 'item_required' } end
    local player = exports.qbx_core:GetPlayer(source)
    local data = player and player.PlayerData
    if not data then return { ok = false, error = 'player_unavailable' } end
    local job = data.job or {}
    local admin = isAdmin(source)
    return {
        ok = true, admin = admin, personnel = getPersonnelManager(source) ~= nil,
        rescue = admin and rescueSettings or nil,
        profile = {
            name = characterName(data),
            role = currentGradeName(job, '役職未設定'),
        },
    }
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
                    grade = currentGradeName(job, '階級未登録'),
                }
            end
        end
    end
    table.sort(roster, function(a, b) return a.name < b.name end)
    return { ok = true, count = count, roster = includeRoster and roster or nil, announcements = announcementState and announcementState.items or {},
        announcementRevision = announcementState and announcementState.revision or 0,
        announcementError = not announcementState and 'お知らせを読み込めませんでした。管理者に確認してください。' or nil,
        canEditAnnouncements = announcementState ~= nil and getPersonnelManager(source) ~= nil }
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
