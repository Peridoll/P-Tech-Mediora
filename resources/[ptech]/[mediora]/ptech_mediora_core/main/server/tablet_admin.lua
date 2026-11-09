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

lib.callback.register('ptech_mediora_core:tabletAccess', function(source)
    if not hasTablet(source) then return { ok = false, error = 'item_required' } end
    return { ok = true, admin = isAdmin(source) }
end)

lib.callback.register('ptech_mediora_core:tabletHome', function(source, request)
    if not hasTablet(source) then return { ok = false, error = '医療端末を所持していません。' } end
    local jobs = Config.DutyTracking.jobs
    local viewer = exports.qbx_core:GetPlayer(source)
    local viewerJob = viewer and viewer.PlayerData.job
    if not viewerJob or not jobs[viewerJob.name] then
        return { ok = false, error = '院内情報は医療職のみ確認できます。' }
    end

    local includeRoster = type(request) == 'table' and request.roster == true
    local count, roster = 0, {}
    for _, playerId in ipairs(GetPlayers()) do
        local player = exports.qbx_core:GetPlayer(tonumber(playerId))
        local data = player and player.PlayerData
        local job = data and data.job
        if job and jobs[job.name] and job.onduty == true then
            count = count + 1
            if includeRoster then
                local info = data.charinfo or {}
                local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
                roster[#roster + 1] = {
                    name = name ~= '' and name or '氏名未登録',
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
