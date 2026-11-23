-- 搭乗と短時間飛行を確認する。機体とNPCはサーバーで生成する。
print('[rescue_pickup] LOAD build=entry-v3 file=main/client/client.lua local-transport=v1')
local active, downPed, heldAt
local eligibility, nextStatusAt, statusPending = nil, 0, false
local downGeneration = 0
local awaitingRelease = false
local lastPanel, lastCoreState
local panelStatus
local errorUntil = 0
local CORE = 'ptech_mediora_core'
local event = 'ptech_mediora_rescue:pickupTest:'

local keybind = lib.addKeybind({
    name = 'ptech_mediora_rescue_activate',
    description = 'Mediora Rescue：緊急離脱（長押し）',
    defaultKey = Config.Key or 'R',
    onReleased = function()
        heldAt = nil
        awaitingRelease = false
    end,
})

local function log(stage, message)
    print(('[rescue_pickup] %s %s'):format(stage, message or ''))
end

local function reportPanel(status, detail)
    if panelStatus == status then return end
    panelStatus = status
    log(status, detail)
end

local function isDown(ped)
    if IsEntityDead(ped) then return true end
    local dead = LocalPlayer.state.dead
    if dead == true or dead == 1 or dead == 2 or dead == 'dead' or dead == 'laststand' then return true end
    if GetResourceState('qbx_core') == 'started' then
        local data = exports.qbx_core:GetPlayerData()
        local metadata = data and data.metadata or {}
        return metadata.isdead == true or metadata.inlaststand == true
    end
    return false
end

local function panel(state, text, progress)
    local coreState = GetResourceState(CORE)
    if not state then
        if lastPanel and coreState == 'started' then
            pcall(function() exports[CORE]:removeActionPanel('rescue') end)
        end
        lastPanel, lastCoreState, panelStatus = nil, coreState, nil
        return
    end
    local key = keybind.currentKey or Config.Key or 'R'
    if lastPanel and lastCoreState == coreState and lastPanel.state == state
        and lastPanel.text == text and lastPanel.progress == progress and lastPanel.icon == key then return end
    lastPanel, lastCoreState = nil, coreState
    if coreState ~= 'started' then
        reportPanel('PANEL_UNAVAILABLE', 'core=' .. tostring(coreState))
        return
    end
    local value = {
        id = 'rescue', title = '緊急離脱', icon = key, state = state,
        text = text, progress = progress,
        -- COREは初期状態が折りたたみ。死亡中は待機・操作可能時もゲージを展開する。
        temporaryExpand = true,
    }
    local ok, accepted = pcall(function() return exports[CORE]:setActionPanel(value) end)
    if ok and accepted == true then
        lastPanel = value
        reportPanel('PANEL_REGISTERED', 'core=' .. CORE)
    else
        reportPanel('PANEL_FAILED', tostring(accepted))
    end
end

local function exists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function cleanup(s, reason)
    if active ~= s then return end
    active = nil -- 読込待ち中のスレッドを無効化してから実体を削除する。
    heldAt, awaitingRelease = nil, true
    if s.ped == PlayerPedId() and exists(s.ped) and s.warpAttempted and not s.arrived then
        local here = GetEntityCoords(s.ped)
        local vehicle = GetVehiclePedIsIn(s.ped, false)
        local inHeli = s.heli and s.heli ~= 0 and vehicle == s.heli
        local lostNearby = s.boarded and not exists(s.heli) and vehicle == 0
            and s.lastPosition and #(here - s.lastPosition) < 15.0
        if inHeli or lostNearby then
            ClearPedTasksImmediately(s.ped)
            SetEntityCoordsNoOffset(s.ped, s.origin.x, s.origin.y, s.origin.z, true, true, true)
            SetEntityHeading(s.ped, s.heading)
        end
    end
    if exists(s.pilot) then DeleteEntity(s.pilot) end
    if exists(s.heli) then DeleteEntity(s.heli) end
    if s.faded then DoScreenFadeIn(350) end
    if s.request and not s.arrived then TriggerServerEvent(event .. 'cleanup', s.request) end
    for _, model in ipairs(s.models) do SetModelAsNoLongerNeeded(model) end
    log('CLEANUP', reason)
end

local function check(s)
    if active ~= s or s.ped ~= PlayerPedId() or not isDown(s.ped) then
        error('死亡状態またはプレイヤーが変更されました', 0)
    end
end

local function waitFor(s, predicate, timeout, message)
    local deadline = GetGameTimer() + timeout
    while not predicate() do
        check(s)
        if GetGameTimer() >= deadline then
            error(type(message) == 'function' and message() or message, 0)
        end
        Wait(0)
    end
    check(s)
end

local function run(s)
    local cfg = Config.Helicopter
    local heliModel, pilotModel = joaat(cfg.Model), joaat(cfg.Pilot)
    if not IsModelInCdimage(heliModel) or not IsModelValid(heliModel) or not IsThisModelAHeli(heliModel)
        or not IsModelInCdimage(pilotModel) or not IsModelValid(pilotModel) or not IsModelAPed(pilotModel) then
        error('ヘリまたは操縦士のモデルが無効です', 0)
    end
    s.phase = 'モデル読込中'
    for _, model in ipairs({ heliModel, pilotModel }) do
        s.models[#s.models + 1] = model
        RequestModel(model)
    end
    waitFor(s, function() return HasModelLoaded(heliModel) and HasModelLoaded(pilotModel) end,
        Config.SpawnTimeout, 'ヘリまたは操縦士のモデル読込がタイムアウトしました')
    log('MODEL_OK', ('heli=%s pilot=%s'):format(cfg.Model, cfg.Pilot))

    s.phase = '搬送準備中'
    s.faded = true
    DoScreenFadeOut(350)
    waitFor(s, IsScreenFadedOut, 2000, 'FADE_OUT_TIMEOUT')
    s.request = GetGameTimer()
    local started = lib.callback.await(event .. 'begin', false, s.request)
    check(s)
    if not started then error('TRANSPORT_BEGIN_FAILED', 0) end
    local origin = s.origin
    s.heli = CreateVehicle(heliModel, origin.x, origin.y, origin.z + cfg.HoverOffset, s.heading, false, true)
    if not exists(s.heli) then error('LOCAL_HELI_FAILED', 0) end
    SetEntityInvincible(s.heli, true)
    SetEntityCollision(s.heli, false, false)
    FreezeEntityPosition(s.heli, true)
    SetVehicleEngineOn(s.heli, true, true, false)
    SetHeliBladesFullSpeed(s.heli)

    s.pilot = CreatePedInsideVehicle(s.heli, 26, pilotModel, -1, false, true)
    if not exists(s.pilot) then error('LOCAL_PILOT_FAILED', 0) end
    SetEntityInvincible(s.pilot, true)
    SetBlockingOfNonTemporaryEvents(s.pilot, true)
    SetPedKeepTask(s.pilot, true)
    SetDriverAbility(s.pilot, 1.0)
    waitFor(s, function() return exists(s.heli) and GetPedInVehicleSeat(s.heli, -1) == s.pilot end,
        2000, '操縦席への配置を確認できません')
    log('PILOT_OK', ('heli=%d pilot=%d seat=-1'):format(s.heli, s.pilot))

    s.phase, s.warpAttempted = '助手席へ配置中', true
    local seat = cfg.PassengerSeat or 0
    SetPedIntoVehicle(s.ped, s.heli, seat)
    waitFor(s, function() return exists(s.heli) and GetPedInVehicleSeat(s.heli, seat) == s.ped end,
        2000, 'プレイヤーの助手席への配置を確認できません')
    s.boarded, s.boardedAt = true, GetGameTimer()
    s.lastPosition = GetEntityCoords(s.heli)
    local departure = s.lastPosition
    -- 搭乗準備中に無効化した衝突判定を戻し、通常の機体物理で飛行させる。
    SetEntityCollision(s.heli, true, true)
    FreezeEntityPosition(s.heli, false)
    Wait(0)
    check(s)
    SetVehicleEngineOn(s.heli, true, true, false)
    SetHeliBladesFullSpeed(s.heli)
    local helipad = Config.Hospital.Helipad
    local cruiseZ = math.max(departure.z + 30.0, helipad.z + cfg.CruiseHeight)
    TaskHeliMission(s.pilot, s.heli, 0, 0, helipad.x, helipad.y, cruiseZ,
        4, cfg.Speed, 12.0, -1.0, -1, -1, -1.0, 0)
    log('BOARD_OK', ('heli=%d pilot=%d passenger=%d seat=%d duration=%.1f')
        :format(s.heli, s.pilot, s.ped, seat, cfg.TestDuration))

    DoScreenFadeIn(350)
    s.boardedAt = GetGameTimer()
    local deadline = s.boardedAt + cfg.TestDuration * 1000
    local arrivalReason = 'timeout'
    while GetGameTimer() < deadline do
        check(s)
        if not exists(s.heli) or not exists(s.pilot) then error('ヘリまたは操縦士が消失しました', 0) end
        s.lastPosition = GetEntityCoords(s.heli)
        if GetPedInVehicleSeat(s.heli, -1) ~= s.pilot or GetPedInVehicleSeat(s.heli, seat) ~= s.ped then
            error('搭乗状態が解除されました', 0)
        end
        local dx, dy = s.lastPosition.x - helipad.x, s.lastPosition.y - helipad.y
        if s.lastPosition.z >= helipad.z and dx * dx + dy * dy <= cfg.ArrivalRadius ^ 2 then
            arrivalReason = 'near_hospital'
            break
        end
        Wait(math.max(0, math.min(50, deadline - GetGameTimer())))
    end
    log('TRANSPORT_ARRIVAL', ('reason=%s elapsed=%.1fs'):format(arrivalReason, (GetGameTimer() - s.boardedAt) / 1000))
    s.phase = '病院に到着'
    DoScreenFadeOut(350)
    waitFor(s, IsScreenFadedOut, 2000, 'ARRIVAL_FADE_TIMEOUT')
    local arrival = Config.Hospital.Entrance
    RequestCollisionAtCoord(arrival.x, arrival.y, arrival.z)
    local accepted = lib.callback.await(event .. 'finish', false, s.request)
    if active ~= s or s.ped ~= PlayerPedId() then return end
    if not accepted then error('TRANSPORT_ARRIVAL_FAILED', 0) end
    s.arrived = true
    ClearPedTasksImmediately(s.ped)
    SetEntityCoordsNoOffset(s.ped, arrival.x, arrival.y, arrival.z, true, true, true)
    SetEntityHeading(s.ped, arrival.w)
    local collisionDeadline = GetGameTimer() + 2000
    while active == s and not HasCollisionLoadedAroundEntity(s.ped) and GetGameTimer() < collisionDeadline do
        Wait(0)
    end
    cleanup(s, 'COMPLETE')
end

local function beginPickup(ped)
    if active then return end
    local s = { ped = ped, origin = GetEntityCoords(ped), heading = GetEntityHeading(ped), models = {}, phase = '準備中' }
    active = s
    awaitingRelease, heldAt, errorUntil = true, nil, 0
    log('START', ('ped=%d'):format(ped))
    CreateThread(function()
        local ok, err = xpcall(function() run(s) end, debug.traceback)
        if not ok and active == s then
            log('FAIL', tostring(err))
            cleanup(s, 'FAILED')
            errorUntil = GetGameTimer() + 5000
            lib.notify({ title = '緊急離脱', description = 'ヘリ検証を中断しました。F8の[rescue_pickup]ログを確認してください。', type = 'error' })
        end
    end)
end

CreateThread(function()
    log('READY', ('build=local-transport-v1 hold=%s duration=%s'):format(Config.HoldDuration, Config.Helicopter.TestDuration))
    while true do
        local now, ped = GetGameTimer(), PlayerPedId()
        local held = keybind:isControlPressed()
        if IsPauseMenuActive() or (IsNuiFocused() and not IsNuiFocusKeepingInput()) then
            keybind.isPressed = false
            held = false
        end
        if not held then awaitingRelease = false end

        if not isDown(ped) then
            if active then cleanup(active, 'DEATH_ENDED') end
            if downPed then downGeneration = downGeneration + 1 end
            downPed, heldAt, errorUntil = nil, nil, 0
            eligibility, nextStatusAt = nil, 0
            panel(nil)
            Wait(100)
        else
            if downPed ~= ped then
                if active then cleanup(active, 'PED_CHANGED') end
                downPed, heldAt, errorUntil = ped, nil, 0
                downGeneration = downGeneration + 1
                eligibility, nextStatusAt = nil, 0
                log('DOWN', ('ped=%d'):format(ped))
            end
            if not active and not statusPending and now >= nextStatusAt then
                statusPending = true
                nextStatusAt = now + 1000
                local generation = downGeneration
                CreateThread(function()
                    local ok, result = pcall(lib.callback.await, event .. 'status', false)
                    statusPending = false
                    if generation == downGeneration then
                        eligibility = ok and type(result) == 'table' and result or nil
                    end
                end)
            end
            local remaining = eligibility and eligibility.remaining
            if active then
                heldAt = nil
                if active.boardedAt then
                    local duration = Config.Helicopter.TestDuration * 1000
                    local elapsed = now - active.boardedAt
                    panel('active', ('病院へ搬送中：あと%d秒'):format(math.max(0, math.ceil((duration - elapsed) / 1000))), math.min(100, math.floor(elapsed / duration * 100)))
                else
                    panel('active', active.phase, 0)
                end
            elseif not eligibility or not eligibility.enabled then
                heldAt = nil
                panel(nil)
            elseif errorUntil > now then
                heldAt = nil
                panel('error', '検証を中断しました。F8ログを確認してください', 0)
            elseif remaining > 0 then
                heldAt = nil
                local seconds = math.ceil(remaining / 1000)
                panel('waiting', ('使用可能まで %d:%02d'):format(math.floor(seconds / 60), seconds % 60), math.floor((1 - remaining / eligibility.duration) * 100))
            elseif held and not awaitingRelease then
                heldAt = heldAt or now
                local percent = math.min(100, math.floor((now - heldAt) / (Config.HoldDuration * 1000) * 100))
                panel('holding', ('%s 長押し中（%d%%）'):format(keybind.currentKey or Config.Key, percent), percent)
                if percent >= 100 then beginPickup(ped) end
            else
                heldAt = nil
                panel('ready', ('%sを%s秒長押しで緊急離脱'):format(keybind.currentKey or Config.Key, Config.HoldDuration), 0)
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(name)
    if name == CORE then lastPanel, lastCoreState = nil, nil end
end)
AddEventHandler('onClientResourceStop', function(name)
    if name == CORE then lastPanel, lastCoreState = nil, nil end
    if name ~= GetCurrentResourceName() then return end
    if active then cleanup(active, 'RESOURCE_STOP') end
    panel(nil)
end)
