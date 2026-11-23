-- 段階検証: 死亡 -> 待機 -> R長押し -> NPC操縦ヘリへ搭乗 -> 5秒で片付け。
-- ヘリ・NPCは本人のクライアントだけに生成し、旧ネットワーク搬送は読み込まない。
print('[rescue_pickup] LOAD build=pickup-v2')
local active, downAt, downPed, heldAt
local awaitingRelease = false
local lastPanel, lastCoreState
local panelStatus
local errorUntil = 0
local CORE = 'ptech_mediora_core'

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
    if s.ped == PlayerPedId() and exists(s.ped) and s.warpAttempted then
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
        if GetGameTimer() >= deadline then error(message, 0) end
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

    local pos = s.origin
    s.phase = 'ヘリ・操縦士を生成中'
    s.heli = CreateVehicle(heliModel, pos.x, pos.y, pos.z + cfg.HoverOffset, s.heading, false, true)
    waitFor(s, function() return exists(s.heli) end, Config.SpawnTimeout, 'ヘリの生成に失敗しました')
    SetEntityAsMissionEntity(s.heli, true, true)
    SetEntityInvincible(s.heli, true)
    SetEntityCollision(s.heli, false, false)
    FreezeEntityPosition(s.heli, true)
    SetVehicleEngineOn(s.heli, true, true, false)
    SetHeliBladesFullSpeed(s.heli)

    s.pilot = CreatePedInsideVehicle(s.heli, 26, pilotModel, -1, false, true)
    waitFor(s, function() return exists(s.pilot) end, Config.SpawnTimeout, '操縦士の生成に失敗しました')
    SetEntityAsMissionEntity(s.pilot, true, true)
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
    FreezeEntityPosition(s.heli, false)
    -- ホバリング位置へ操縦させる。病院までの飛行はこの段階では行わない。
    TaskHeliMission(s.pilot, s.heli, 0, 0, s.lastPosition.x, s.lastPosition.y, s.lastPosition.z,
        4, 5.0, 5.0, s.heading, -1.0, -1.0, -1.0, 0)
    log('BOARD_OK', ('heli=%d pilot=%d passenger=%d seat=%d duration=%.1f')
        :format(s.heli, s.pilot, s.ped, seat, cfg.TestDuration))

    local deadline = s.boardedAt + cfg.TestDuration * 1000
    while GetGameTimer() < deadline do
        check(s)
        if not exists(s.heli) or not exists(s.pilot) then error('ヘリまたは操縦士が消失しました', 0) end
        s.lastPosition = GetEntityCoords(s.heli)
        if GetPedInVehicleSeat(s.heli, -1) ~= s.pilot or GetPedInVehicleSeat(s.heli, seat) ~= s.ped then
            error('搭乗状態が解除されました', 0)
        end
        Wait(math.min(50, deadline - GetGameTimer()))
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
    log('READY', ('build=pickup-v2 countdown=%s hold=%s duration=%s'):format(Config.Countdown, Config.HoldDuration, Config.Helicopter.TestDuration))
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
            downAt, downPed, heldAt, errorUntil = nil, nil, nil, 0
            panel(nil)
            Wait(100)
        else
            if downPed ~= ped then
                if active then cleanup(active, 'PED_CHANGED') end
                downAt, downPed, heldAt, errorUntil = now, ped, nil, 0
                log('DOWN', ('ped=%d countdown=%s'):format(ped, Config.Countdown))
            end
            local remaining = math.max(0, Config.Countdown * 1000 - (now - downAt))
            if active then
                heldAt = nil
                if active.boardedAt then
                    local duration = Config.Helicopter.TestDuration * 1000
                    local elapsed = now - active.boardedAt
                    panel('active', ('搭乗確認済み：%d秒後にヘリを削除'):format(math.max(0, math.ceil((duration - elapsed) / 1000))), math.min(100, math.floor(elapsed / duration * 100)))
                else
                    panel('active', active.phase, 0)
                end
            elseif errorUntil > now then
                heldAt = nil
                panel('error', '検証を中断しました。F8ログを確認してください', 0)
            elseif remaining > 0 then
                heldAt = nil
                local seconds = math.ceil(remaining / 1000)
                panel('waiting', ('使用可能まで %d:%02d'):format(math.floor(seconds / 60), seconds % 60), math.floor((1 - remaining / (Config.Countdown * 1000)) * 100))
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
