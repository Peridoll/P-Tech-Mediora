local sessions, sequence = {}, 0
local prefix = 'ptech_mediora_rescue:boarding:'

local function notify(src, message, kind)
    print(('[rescue_boarding] FEEDBACK src=%d kind=%s'):format(src, kind or 'inform'))
    TriggerClientEvent(prefix .. 'feedback', src, message, kind or 'inform')
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Rescue搭乗テスト', description = message, type = kind or 'inform', duration = 8000,
    })
end

local function destroy(src, s, restore)
    if s.heli and DoesEntityExist(s.heli) then
        if restore and GetPlayerPed(src) == s.ped and GetPlayerRoutingBucket(src) == s.bucket
            and GetVehiclePedIsIn(s.ped) == s.heli then
            SetEntityCoords(s.ped, s.origin.x, s.origin.y, s.origin.z, false, false, false, false)
        end
        DeleteEntity(s.heli)
    end
    if sessions[src] == s then sessions[src] = nil end
end

local function snapshot(src, s)
    local exists = s.heli ~= nil and DoesEntityExist(s.heli)
    local coords = exists and GetEntityCoords(s.heli) or s.origin
    return {
        ticket = s.ticket, mode = s.mode, exists = exists,
        netId = exists and NetworkGetNetworkIdFromEntity(s.heli) or 0,
        owner = exists and NetworkGetEntityOwner(s.heli) or -1,
        bucket = exists and GetEntityRoutingBucket(s.heli) or s.bucket,
        playerBucket = GetPlayerRoutingBucket(src), x = coords.x, y = coords.y, z = coords.z,
    }
end

local function executeCommand(src, args)
    print(('[rescue_boarding] COMMAND_RECEIVED src=%s mode=%s'):format(tostring(src), tostring(args[1] or 'local')))
    if src == 0 then print('[rescue_boarding] Run /rescueheli in game.'); return end
    local mode = args[1] or 'local'
    if #args > 1 or (mode ~= 'local' and mode ~= 'server' and mode ~= 'clear') then
        notify(src, '使い方: /rescueheli [local|server|clear]', 'error'); return
    end
    local current = sessions[src]
    if mode == 'clear' then
        if not current then notify(src, '検証中のヘリはありません'); return end
        current.clearing = true
        TriggerClientEvent(prefix .. 'stop', src, current.ticket)
        SetTimeout(2000, function()
            if sessions[src] == current then destroy(src, current, true) end
        end)
        return
    end
    if not IsPlayerAceAllowed(src, 'command.rescueheli') and not IsPlayerAceAllowed(src, 'command.rescueskip') then
        notify(src, '検証コマンドの権限がありません（command.rescueheli）', 'error'); return
    end
    if current then notify(src, '先に /rescueheli clear で前の検証を片付けてください', 'error'); return end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then notify(src, 'プレイヤーを確認できません', 'error'); return end
    sequence = sequence + 1
    local s = {
        ticket = sequence, mode = mode, ped = ped, bucket = GetPlayerRoutingBucket(src),
        origin = GetEntityCoords(ped), phase = 'loading',
    }
    sessions[src] = s
    print(('[rescue_boarding] BEGIN src=%d ticket=%d mode=%s bucket=%d'):format(src, s.ticket, mode, s.bucket))
    TriggerClientEvent(prefix .. 'start', src, s.ticket, mode)
end
RegisterNetEvent(prefix .. 'request', function(mode, requestId)
    local src = source
    if type(requestId) ~= 'number' or requestId % 1 ~= 0 then return end
    TriggerClientEvent(prefix .. 'ack', src, requestId)
    executeCommand(src, { mode })
end)
print('[rescue_boarding] SERVER_READY build=boarding-input-v2')

-- モデル読込が済んだクライアントからだけ生成へ進む。通常のRescue callbackは使用しない。
RegisterNetEvent(prefix .. 'create', function(ticket)
    local src = source
    local s = sessions[src]
    if not s or s.ticket ~= ticket or s.mode ~= 'server' or s.phase ~= 'loading' or s.clearing then return end
    if GetPlayerPed(src) ~= s.ped or GetPlayerRoutingBucket(src) ~= s.bucket then return end
    s.phase = 'creating'
    local ok, err = xpcall(function()
        s.heli = CreateVehicleServerSetter(joaat(RescueBoarding.Model), 'heli', s.origin.x, s.origin.y,
            s.origin.z + RescueBoarding.Height, GetEntityHeading(s.ped))
        if not s.heli or s.heli == 0 then error('CREATE_RETURNED_ZERO') end
        local deadline = GetGameTimer() + RescueBoarding.SpawnTimeout
        while not DoesEntityExist(s.heli) and GetGameTimer() < deadline do Wait(50) end
        if sessions[src] ~= s or s.clearing then destroy(src, s, false); return end
        if not DoesEntityExist(s.heli) then error('SERVER_ENTITY_TIMEOUT') end
        SetEntityRoutingBucket(s.heli, s.bucket)
        SetEntityOrphanMode(s.heli, 2)
        FreezeEntityPosition(s.heli, true)
        s.phase = 'created'
        local info = snapshot(src, s)
        print(('[rescue_boarding] SERVER_CREATED ticket=%d net=%d owner=%d bucket=%d xyz=%.2f,%.2f,%.2f')
            :format(s.ticket, info.netId, info.owner, info.bucket, info.x, info.y, info.z))
        TriggerClientEvent(prefix .. 'created', src, s.ticket, info)
    end, debug.traceback)
    if not ok then
        print('[rescue_boarding] SERVER_CREATE_FAIL ' .. tostring(err))
        if sessions[src] == s and not s.clearing then
            TriggerClientEvent(prefix .. 'created', src, s.ticket, { error = 'SERVER_CREATE_FAIL' })
        end
    end
end)

RegisterNetEvent(prefix .. 'inspect', function(ticket)
    local src = source
    local s = sessions[src]
    if s and s.ticket == ticket and not s.clearing then
        TriggerClientEvent(prefix .. 'snapshot', src, ticket, snapshot(src, s))
    end
end)

RegisterNetEvent(prefix .. 'cleared', function(ticket)
    local src = source
    local s = sessions[src]
    if s and s.ticket == ticket then destroy(src, s, false) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if sessions[src] then destroy(src, sessions[src], false) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src, s in pairs(sessions) do destroy(src, s, true) end
end)

