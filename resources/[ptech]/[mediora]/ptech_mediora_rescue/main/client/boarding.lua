local active
local commandSequence, awaitingCommand = 0, nil
local prefix = 'ptech_mediora_rescue:boarding:'

local function log(stage, text)
    print(('[rescue_boarding] %s %s'):format(stage, text or ''))
end

local function notice(message, kind)
    lib.notify({ title = 'Rescue搭乗テスト', description = message, type = kind or 'inform', duration = 8000 })
end

local function valid(s)
    return active == s and s.ped == PlayerPedId()
end

local function releaseModel(s)
    if s.model and not s.modelReleased then
        SetModelAsNoLongerNeeded(s.model)
        s.modelReleased = true
    end
end

local function restore(s)
    if s.ped ~= PlayerPedId() or not s.warpAttempted then return end
    local vehicle = GetVehiclePedIsIn(s.ped, false)
    local here = GetEntityCoords(s.ped)
    local near = s.lastPosition and #(here - s.lastPosition) < 15.0
    if vehicle == s.heli or (vehicle == 0 and near) then
        ClearPedTasksImmediately(s.ped)
        SetEntityCoordsNoOffset(s.ped, s.origin.x, s.origin.y, s.origin.z, true, true, true)
        SetEntityHeading(s.ped, s.heading)
    end
end

local function clear()
    local s = active
    if not s then return end
    active = nil -- モデル読込や生成待ち中の古い処理を無効化してから片付ける。
    restore(s)
    if s.mode == 'local' and s.heli and DoesEntityExist(s.heli) then DeleteEntity(s.heli) end
    releaseModel(s)
    TriggerServerEvent(prefix .. 'cleared', s.ticket)
    log('CLEARED', ('ticket=%d mode=%s'):format(s.ticket, s.mode))
end

local function fail(s, code, message)
    if not valid(s) then return end
    s.phase = 'failed'
    log(code, ('ticket=%d mode=%s heli=%s actualVehicle=%s'):format(s.ticket, s.mode,
        tostring(s.heli), tostring(GetVehiclePedIsIn(s.ped, false))))
    notice(message .. '（/rescueheli clear で片付け）', 'error')
end

local function logSnapshot(info)
    log('SERVER_SNAPSHOT', ('net=%s exists=%s owner=%s bucket=%s playerBucket=%s xyz=%s,%s,%s')
        :format(tostring(info.netId), tostring(info.exists), tostring(info.owner), tostring(info.bucket),
            tostring(info.playerBucket), tostring(info.x), tostring(info.y), tostring(info.z)))
end

local function run(s)
    log('MODEL_REQUEST', RescueBoarding.Model)
    s.model = joaat(RescueBoarding.Model)
    if not IsModelInCdimage(s.model) or not IsModelValid(s.model) or not IsThisModelAHeli(s.model) then
        fail(s, 'MODEL_INVALID', 'ヘリのモデルが見つかりません'); return
    end
    RequestModel(s.model)
    local deadline = GetGameTimer() + RescueBoarding.ModelTimeout
    while valid(s) and not HasModelLoaded(s.model) and GetGameTimer() < deadline do Wait(0) end
    if not valid(s) then releaseModel(s); return end
    if not HasModelLoaded(s.model) then fail(s, 'MODEL_TIMEOUT', 'モデル読込が完了しません'); return end
    log('MODEL_OK', ('model=%s hash=%s'):format(RescueBoarding.Model, s.model))
    notice('1/3 ヘリのモデル読込OK')
    s.phase = 'creating'
    if s.mode == 'local' then
        s.heli = CreateVehicle(s.model, s.origin.x, s.origin.y, s.origin.z + RescueBoarding.Height, s.heading, false, false)
    else
        TriggerServerEvent(prefix .. 'create', s.ticket)
        deadline = GetGameTimer() + RescueBoarding.SpawnTimeout + 2000
        while valid(s) and not s.reply and GetGameTimer() < deadline do Wait(50) end
        if not valid(s) then return end
        if not s.reply or s.reply.error or not s.reply.netId or s.reply.netId == 0 then
            fail(s, 'SERVER_REPLY_FAIL', 'サーバー生成の応答を確認できません'); return
        end
        logSnapshot(s.reply)
        s.netId = s.reply.netId
        deadline = GetGameTimer() + RescueBoarding.StreamTimeout
        while valid(s) and GetGameTimer() < deadline do
            if NetworkDoesEntityExistWithNetworkId(s.netId) then
                s.heli = NetworkGetEntityFromNetworkId(s.netId)
                if s.heli ~= 0 and DoesEntityExist(s.heli) then break end
            end
            Wait(50)
        end
    end
    if not valid(s) then
        if s.mode == 'local' and s.heli and DoesEntityExist(s.heli) then DeleteEntity(s.heli) end
        return
    end
    if not s.heli or s.heli == 0 or not DoesEntityExist(s.heli) then
        if s.mode == 'server' then TriggerServerEvent(prefix .. 'inspect', s.ticket) end
        fail(s, 'ENTITY_MISSING', 'ヘリの実体をクライアントで確認できません'); return
    end
    if s.mode == 'server' then
        deadline = GetGameTimer() + 3000
        while valid(s) and DoesEntityExist(s.heli) and not NetworkHasControlOfEntity(s.heli)
            and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(s.heli); Wait(50)
        end
        if not valid(s) then return end
        if not DoesEntityExist(s.heli) or not NetworkHasControlOfEntity(s.heli) then
            fail(s, 'CONTROL_FAIL', 'ヘリの制御を取得できません'); return
        end
    end
    SetEntityAsMissionEntity(s.heli, true, true)
    FreezeEntityPosition(s.heli, true)
    SetEntityCollision(s.heli, false, false)
    SetEntityInvincible(s.heli, true)
    releaseModel(s)
    s.lastPosition = GetEntityCoords(s.heli)
    log('ENTITY_OK', ('ticket=%d mode=%s heli=%d networked=%s'):format(s.ticket, s.mode, s.heli, tostring(s.mode == 'server')))
    notice('2/3 ヘリ生成OK。助手席へ配置します')
    s.phase, s.warpAttempted = 'boarding', true
    log('BOARD_ATTEMPT', ('ped=%d heli=%d seat=%d'):format(s.ped, s.heli, RescueBoarding.Seat))
    SetPedIntoVehicle(s.ped, s.heli, RescueBoarding.Seat)
    deadline = GetGameTimer() + RescueBoarding.SeatTimeout
    while valid(s) and DoesEntityExist(s.heli) and GetVehiclePedIsIn(s.ped, false) ~= s.heli
        and GetGameTimer() < deadline do Wait(50) end
    if not valid(s) then return end
    if not DoesEntityExist(s.heli) or GetVehiclePedIsIn(s.ped, false) ~= s.heli then
        restore(s)
        fail(s, 'BOARD_FAIL', 'ヘリは生成できましたが、搭乗を確認できません'); return
    end
    s.phase = 'boarded'
    log('BOARD_OK', ('ticket=%d heli=%d health=%d'):format(s.ticket, s.heli, GetEntityHealth(s.ped)))
    notice('3/3 搭乗確認OK。飛行せず固定しています。/rescueheli clear で戻ります', 'success')
    local stableAt = GetGameTimer() + 2000
    while valid(s) and s.phase == 'boarded' do
        Wait(100)
        if not valid(s) then return end
        if not DoesEntityExist(s.heli) then
            restore(s)
            if s.mode == 'server' then TriggerServerEvent(prefix .. 'inspect', s.ticket) end
            fail(s, 'ENTITY_LOST', '搭乗後にヘリの実体が消えました'); return
        end
        s.lastPosition = GetEntityCoords(s.heli)
        if GetVehiclePedIsIn(s.ped, false) ~= s.heli then
            restore(s)
            fail(s, 'SEAT_LOST', 'ヘリは存在しますが、プレイヤーが座席から外れました'); return
        end
        if stableAt and GetGameTimer() >= stableAt then
            log('BOARD_STABLE', ('ticket=%d seconds=2'):format(s.ticket))
            notice('搭乗状態を2秒維持できました', 'success')
            stableAt = nil
        end
    end
end

RegisterNetEvent(prefix .. 'start', function(ticket, mode)
    log('START_RECEIVED', ('source=%s ticket=%s mode=%s'):format(tostring(source), tostring(ticket), tostring(mode)))
    if source ~= 65535 or active or (mode ~= 'local' and mode ~= 'server') then return end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        notice('車外で実行してください', 'error'); TriggerServerEvent(prefix .. 'cleared', ticket); return
    end
    local s = { ticket = ticket, mode = mode, ped = ped, origin = GetEntityCoords(ped), heading = GetEntityHeading(ped), phase = 'loading' }
    active = s
    CreateThread(function()
        local ok, err = xpcall(function() run(s) end, debug.traceback)
        if not ok then log('ERROR', tostring(err)); restore(s); fail(s, 'ERROR', '検証処理でエラーが発生しました。F8ログを確認してください') end
    end)
end)

RegisterNetEvent(prefix .. 'created', function(ticket, info)
    if source == 65535 and active and active.ticket == ticket and type(info) == 'table' then active.reply = info end
end)
RegisterNetEvent(prefix .. 'snapshot', function(ticket, info)
    if source == 65535 and active and active.ticket == ticket and type(info) == 'table' then logSnapshot(info) end
end)
RegisterNetEvent(prefix .. 'stop', function(ticket)
    if source == 65535 and active and active.ticket == ticket then clear() end
end)
AddEventHandler('onClientResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)


RegisterNetEvent(prefix .. 'ack', function(id)
    if source ~= 65535 then return end
    log('SERVER_ACK', 'request=' .. tostring(id))
    if awaitingCommand == id then awaitingCommand = nil end
end)
RegisterNetEvent(prefix .. 'feedback', function(message, kind)
    if source ~= 65535 then return end
    log('SERVER_FEEDBACK', 'kind=' .. tostring(kind) .. ' message=' .. tostring(message))
end)
log('CLIENT_READY', 'build=boarding-input-v2 command=rescueheli')
