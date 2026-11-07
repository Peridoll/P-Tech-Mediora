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

local resourceLocks = {}
local coreRestartPending = false
local operations = {}
local lifecycle = {}
local function markLifecycle(name, event)
    local record = lifecycle[name] or { starts = 0, stops = 0 }
    record[event] = record[event] + 1
    lifecycle[name] = record
end
AddEventHandler('onResourceStop', function(name) markLifecycle(name, 'stops') end)
local coreHistoryKey = 'tablet:lastCoreRestart'
local function saveCoreHistory(phase)
    local record = { action = 'restart', phase = phase, time = os.time() }
    SetResourceKvp(coreHistoryKey, json.encode(record))
end
local function coreHistory()
    local saved = GetResourceKvpString(coreHistoryKey)
    if not saved then return nil end
    local ok, value = pcall(json.decode, saved)
    return ok and type(value) == 'table' and value or nil
end
AddEventHandler('onResourceStart', function(name)
    markLifecycle(name, 'starts')
    if name ~= GetCurrentResourceName() then return end
    local previous = coreHistory()
    if not previous or previous.phase ~= 'pending' then return end
    SetTimeout(1000, function()
        saveCoreHistory(os.time() - (previous.time or 0) < 60 and GetResourceState(name) == 'started' and 'complete' or 'failed')
    end)
end)
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
    if name == core and action ~= 'restart' then return { ok = false, error = 'core_protected' } end
    if coreRestartPending or resourceLocks[name] then return { ok = false, error = 'busy' } end
    local state = GetResourceState(name)
    if (action == 'start' and state ~= 'stopped') or (action ~= 'start' and state ~= 'started') then
        return { ok = false, error = 'invalid_state' }
    end
    if not IsPrincipalAceAllowed('resource.' .. core, 'command.' .. action) then
        print(('[%s] Resource command denied: missing command.%s ACE'):format(core, action))
        return { ok = false, error = 'command_permission' }
    end
    if name == core then
        coreRestartPending = true
        saveCoreHistory('pending')
        print(('[%s] Resource action: player=%s action=restart resource=%s'):format(core, source, name))
        -- Reply first, close all tablets, then let the engine perform the self restart.
        SetTimeout(1000, function()
            if not isAdmin(source) or not hasTablet(source) then coreRestartPending = false; saveCoreHistory('failed'); return end
            TriggerClientEvent('ptech_mediora_core:tabletRestarting', -1)
            SetTimeout(250, function()
                ExecuteCommand('restart ' .. core)
                SetTimeout(2000, function() coreRestartPending = false; saveCoreHistory('failed') end)
            end)
        end)
        return { ok = true, restartingCore = true }
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
            resources[#resources + 1] = { name = name, state = GetResourceState(name), operation = name == GetCurrentResourceName() and coreHistory() or operations[name] }
        end
    end
    table.sort(resources, function(a, b) return a.name < b.name end)
    return { ok = true, resources = resources }
end)
