local status = { eligible = false }
local syncAt, heldAt, sending = 0, nil, false
local statusRevision = 0
local requestAttempt, requestStartedAt, requestId = 0, nil, nil
local requestError, requestErrorUntil, awaitingKeyRelease = nil, 0, false
local running, heli, pilot = false, nil, nil
local stopRequested, activeNetId, pilotNetId = false, nil, nil
local stopMessage
local activeTicket, flightPed, flightOrigin, flightHeading, flightCitizen, boarded, delivered
local lastAircraftPosition
local visibleAircraft = {}
local rescuePanel, rescuePanelResourceState, rescuePanelShared = nil, nil, false
-- GTAのINPUT_RELOADではなく、FiveMの押下・解放コマンドで保持状態を読む。
-- 死亡スクリプトによって標準操作が無効でも、専用キーから長押しを開始できる。
local rescueKeybind = lib.addKeybind({
    name = 'ptech_mediora_rescue_activate',
    description = 'Mediora Rescue：緊急離脱（長押し）',
    defaultKey = Config.Key or Config.ControlLabel or 'R',
    onReleased = function() heldAt = nil end,
})
local function rescueKeyLabel()
    local label = rescueKeybind.currentKey
    return type(label) == 'string' and label ~= '' and label or Config.ControlLabel or 'R'
end
local function notify(message, kind)
    lib.notify({ title = 'Mediora Rescue', description = message, type = kind or 'inform' })
end
local function clock(ms)
    local s = math.ceil(math.max(ms, 0) / 1000)
    return ('%d:%02d'):format(math.floor(s / 60), s % 60)
end
local function hint(message)
    SetTextFont(0); SetTextScale(0.0, 0.35); SetTextColour(255, 255, 255, 240)
    SetTextOutline(); BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(message); EndTextCommandDisplayText(0.02, 0.76)
end
local function setRescuePanel(state, message, progress)
    local coreState = GetResourceState('ptech_mediora_core')
    if not state then
        if rescuePanel and coreState == 'started' then
            pcall(function() exports['ptech_mediora_core']:removeActionPanel('rescue') end)
        end
        rescuePanel, rescuePanelResourceState, rescuePanelShared = nil, coreState, false
        return coreState == 'started'
    end

    local panel = {
        id = 'rescue',
        title = '緊急離脱',
        icon = rescueKeyLabel(),
        state = state,
        text = message or '',
        progress = progress,
        temporaryExpand = state == 'holding' or state == 'active' or state == 'error',
    }
    local unchanged = rescuePanel and rescuePanel.state == panel.state
        and rescuePanel.text == panel.text and rescuePanel.progress == panel.progress
    if unchanged and rescuePanelResourceState == coreState and rescuePanelShared then return true end

    rescuePanel, rescuePanelResourceState = panel, coreState
    rescuePanelShared = false
    if coreState ~= 'started' then return false end
    local ok, accepted = pcall(function() return exports['ptech_mediora_core']:setActionPanel(panel) end)
    rescuePanelShared = ok and accepted == true
    return rescuePanelShared
end
local function drawRescueFallback(message, progress)
    if not rescuePanel or rescuePanelShared then return end
    local text = message or rescuePanel.text
    if progress ~= nil then text = ('%s（%d%%）'):format(text, progress) end
    hint(text)
end
local function playerData()
    local ok, value = pcall(function() return exports.qbx_core:GetPlayerData() end)
    return ok and value or {}
end
local function interruptionReason()
    if stopRequested then return stopMessage or '救助要請が取り消されました' end
    if flightPed ~= PlayerPedId() then return 'プレイヤーの実体が変わったため中断しました' end
    local d = playerData()
    if d.citizenid and flightCitizen and d.citizenid ~= flightCitizen then return 'キャラクターが変わったため中断しました' end
    -- 職業・死亡状態はサーバーが250ms周期と各phaseで検証する。
    -- クライアント側metadataの同期遅延だけでは受理済みの要請を取り消さない。
end
local function canContinue()
    return interruptionReason() == nil
end
local function localNetworkEntity(netId)
    -- サーバー上のIDが存在しても、ローカルへ配信されるまではNetToEntを呼ばない。
    if type(netId) ~= 'number' or netId <= 0 or not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
    local entity = NetworkGetEntityFromNetworkId(netId)
    return entity ~= 0 and DoesEntityExist(entity) and entity or 0
end
local function logAircraftFailure(stage)
    print(('[ptech_mediora_rescue] %s ticket=%s heliNet=%s pilotNet=%s heliLocal=%s pilotLocal=%s')
        :format(stage, tostring(activeTicket), tostring(activeNetId), tostring(pilotNetId), tostring(heli), tostring(pilot)))
end
local function cleanup(reason)
    if reason then
        logAircraftFailure('搬送中断: ' .. reason)
        requestError, requestErrorUntil = reason, GetGameTimer() + 4000
    end
    -- 搬送失敗時に空中で降ろさない。別キャラクターや外部処理で移動済みの患者は動かさない。
    local inAircraft = heli and DoesEntityExist(heli) and flightPed and IsPedInVehicle(flightPed, heli, false)
    local aircraftLost = boarded and heli and not DoesEntityExist(heli) and lastAircraftPosition
        and flightPed == PlayerPedId() and GetVehiclePedIsIn(flightPed, false) == 0
        and #(GetEntityCoords(flightPed) - lastAircraftPosition) < 15.0
    if boarded and not delivered and flightPed == PlayerPedId() and playerData().citizenid == flightCitizen
        and (inAircraft or aircraftLost) then
        ClearPedTasksImmediately(flightPed)
        SetEntityCoordsNoOffset(flightPed, flightOrigin.x, flightOrigin.y, flightOrigin.z, true, true, true)
        SetEntityHeading(flightPed, flightHeading)
    end
    if activeTicket then TriggerServerEvent('ptech_mediora_rescue:finish', activeTicket) end
    activeTicket, flightPed, flightOrigin, flightCitizen, boarded, delivered = nil, nil, nil, nil, false, false
    lastAircraftPosition = nil
    activeNetId, pilotNetId = nil, nil
    pilot, heli = nil, nil
    setRescuePanel(reason and 'error' or nil, reason)
    statusRevision = statusRevision + 1
    status = { eligible = false }
    syncAt = 0
end
local function acquireAircraft()
    local deadline = GetGameTimer() + 3000
    repeat
        if not canContinue() or not DoesEntityExist(heli) or not DoesEntityExist(pilot) then return false end
        if NetworkHasControlOfEntity(heli) and NetworkHasControlOfEntity(pilot) then return true end
        NetworkRequestControlOfEntity(heli)
        NetworkRequestControlOfEntity(pilot)
        Wait(50)
    until GetGameTimer() >= deadline
    return NetworkHasControlOfEntity(heli) and NetworkHasControlOfEntity(pilot)
end
local function confirmPhase(phase)
    local deadline = GetGameTimer() + 3000
    repeat
        if not canContinue() then return false end
        local ok, accepted = pcall(lib.callback.await, 'ptech_mediora_rescue:phase', false, activeTicket, phase)
        if ok and accepted then return true end
        Wait(150)
    until GetGameTimer() >= deadline
    return false
end
local function ghost()
    if not heli or not DoesEntityExist(heli) then return end
    lastAircraftPosition = GetEntityCoords(heli)
    -- 接触と破壊を無効にし続ける。NPC AIとの両立は実機で確認する。
    SetEntityCollision(heli, false, false)
    SetEntityCompletelyDisableCollision(heli, true, false)
    SetEntityInvincible(heli, true)
    if pilot and DoesEntityExist(pilot) then
        SetEntityCollision(pilot, false, false)
        SetEntityInvincible(pilot, true)
    end
end
local function roofHeight(pos)
    local h = Config.Helicopter.RoofProbeHeight
    local ray = StartShapeTestLosProbe(pos.x, pos.y, pos.z + h, pos.x, pos.y, pos.z + 0.5, 1 + 16, PlayerPedId(), 7)
    local code, hit, endCoords = GetShapeTestResult(ray)
    local deadline = GetGameTimer() + 500
    while code == 1 and GetGameTimer() < deadline do
        Wait(0)
        code, hit, endCoords = GetShapeTestResult(ray)
    end
    if code == 2 and (hit == true or hit == 1) and endCoords and endCoords.z > pos.z then return endCoords.z end
    return pos.z
end
local function flight(request)
    if running then return end
    running = true
    stopRequested = false
    stopMessage = nil
    setRescuePanel('active', '救助機を確認しています')
    activeNetId, pilotNetId, activeTicket = request.heli, request.pilot, request.ticket
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    flightPed, flightOrigin, flightHeading, flightCitizen = ped, start, GetEntityHeading(ped), request.citizenid or playerData().citizenid
    boarded, delivered = false, false
    local cfg = Config.Helicopter
    local syncStarted = GetGameTimer()
    local timeout = syncStarted + 10000
    repeat
        if not canContinue() then cleanup(interruptionReason()); running = false; return end
        heli = localNetworkEntity(activeNetId)
        pilot = localNetworkEntity(pilotNetId)
        -- 先に届いた方を固定し、残りを待つ間の落下を防ぐ。
        for _, entity in ipairs({ heli, pilot }) do
            if entity ~= 0 then
                if NetworkHasControlOfEntity(entity) then FreezeEntityPosition(entity, true)
                else NetworkRequestControlOfEntity(entity) end
            end
        end
        ghost()
        if heli ~= 0 and pilot ~= 0 and DoesEntityExist(heli) and DoesEntityExist(pilot) then break end
        local missing = heli == 0 and (pilot == 0 and 'ヘリ・操縦士' or 'ヘリ') or '操縦士'
        setRescuePanel('active', ('%sの到着を待っています（%d秒）'):format(missing, math.floor((GetGameTimer() - syncStarted) / 1000)))
        Wait(100)
    until GetGameTimer() >= timeout
    if heli == 0 or pilot == 0 or not DoesEntityExist(heli) or not DoesEntityExist(pilot) then
        local missing = heli == 0 and (pilot == 0 and 'ヘリ・操縦士' or 'ヘリ') or '操縦士'
        logAircraftFailure('配信待ちタイムアウト')
        notify(missing .. 'の到着を確認できませんでした。再度要請してください', 'error')
        cleanup(); running = false; return
    end
    setRescuePanel('active', '救助機の準備をしています')
    if not acquireAircraft() then
        if not canContinue() then cleanup(interruptionReason()); running = false; return end
        logAircraftFailure('機体制御取得失敗')
        notify('救助機の制御を取得できません。再度お試しください', 'error')
        cleanup(); running = false; return
    end
    ghost()
    FreezeEntityPosition(heli, true)
    local roof = roofHeight(start)
    if not canContinue() then cleanup(interruptionReason()); running = false; return end
    local hoverZ = math.max(GetEntityCoords(heli).z, roof + cfg.HoverOffset)
    SetEntityCoordsNoOffset(heli, start.x, start.y, hoverZ, false, false, true)
    local spawnZ = GetEntityCoords(heli).z
    SetVehicleEngineOn(heli, true, true, false)
    SetHeliBladesFullSpeed(heli)
    SetBlockingOfNonTemporaryEvents(pilot, true)
    SetPedKeepTask(pilot, true)
    SetDriverAbility(pilot, 1.0)
    SetDriverAggressiveness(pilot, 0.0)
    FreezeEntityPosition(pilot, false)
    TaskWarpPedIntoVehicle(pilot, heli, -1)
    local pilotDeadline = GetGameTimer() + 3000
    while GetVehiclePedIsIn(pilot, false) ~= heli and GetGameTimer() < pilotDeadline and canContinue() do Wait(50) end
    if not canContinue() then cleanup(interruptionReason()); running = false; return end
    if GetVehiclePedIsIn(pilot, false) ~= heli then
        logAircraftFailure('パイロット搭乗失敗')
        notify('パイロットが搭乗できません', 'error')
        cleanup(); running = false; return
    end
    setRescuePanel('active', '救助機が到着しました。患者を回収しています')
    ghost()
    -- 1秒回収: GTA標準ロープは屋内・地下への長距離描画に制限があるため、
    -- 現段階ではロープの視覚演出を保証せず、1秒後の搭乗処理を優先する。
    local pickupEnd = GetGameTimer() + cfg.PickupSeconds * 1000
    while GetGameTimer() < pickupEnd and canContinue() do
        Wait(0); ghost()
    end
    -- ダウン状態を変更せず、ヘリの空席へ配置する。
    if not canContinue() then cleanup(interruptionReason()); running = false; return end
    SetPedIntoVehicle(ped, heli, 0)
    if not IsPedInVehicle(ped, heli, false) then
        notify('ヘリへの搭乗に失敗しました', 'error')
        SetEntityCoordsNoOffset(ped, start.x, start.y, start.z, false, false, false)
        cleanup(); running = false; return
    end
    boarded = true
    if not confirmPhase('transporting') then
        if not canContinue() then cleanup(interruptionReason()); running = false; return end
        notify('搭乗を確認できません。回収前の位置へ戻ります', 'error')
        cleanup(); running = false; return
    end
    FreezeEntityPosition(heli, false)
    setRescuePanel('active', '本院へ搬送中です')
    CreateThread(function()
        while running do
            DisableControlAction(0, 75, true) -- 降車禁止。視点操作は維持。
            DisableControlAction(0, 76, true) -- ハンドブレーキ等の操作禁止。
            Wait(0)
        end
    end)
    local target = Config.Hospital.Helipad
    local cruiseZ = math.max(spawnZ + 30.0, target.z + cfg.CruiseHeight)
    TaskHeliMission(pilot, heli, 0, 0, target.x, target.y, cruiseZ, 4, cfg.Speed, 12.0, -1.0, -1, -1, -1.0, 0)
    local started, lastMoved, previous = GetGameTimer(), GetGameTimer(), GetEntityCoords(heli)
    local near = false
    while GetGameTimer() - started < cfg.MaxFlightSeconds * 1000 do
        Wait(100)
        if not canContinue() or not DoesEntityExist(heli) or not DoesEntityExist(pilot)
            or not IsPedInVehicle(ped, heli, false) then break end
        if (not NetworkHasControlOfEntity(heli) or not NetworkHasControlOfEntity(pilot))
            and not acquireAircraft() then break end
        ghost()
        local here = GetEntityCoords(heli)
        if #(here - vector3(target.x, target.y, here.z)) < 35.0 then near = true; break end
        if #(here - previous) > 8.0 then previous = here; lastMoved = GetGameTimer() end
        if GetGameTimer() - lastMoved > cfg.StallSeconds * 1000 then
            TaskHeliMission(pilot, heli, 0, 0, target.x, target.y, cruiseZ, 4, cfg.Speed, 12.0, -1.0, -1, -1, -1.0, 0)
            lastMoved = GetGameTimer()
        end
    end
    local landed = false
    if near then
        -- 接近してから着陸指示。失敗した場合は病院周辺でのみ最終搬送。
        TaskHeliMission(pilot, heli, 0, 0, target.x, target.y, target.z, 20, 12.0, 8.0, target.w, -1, -1, -1.0, 0)
        local landingEnd = GetGameTimer() + cfg.LandingTimeout * 1000
        while GetGameTimer() < landingEnd and canContinue() and DoesEntityExist(heli) and DoesEntityExist(pilot)
            and IsPedInVehicle(ped, heli, false) do
            Wait(100); ghost()
            if GetEntityHeightAboveGround(heli) < 1.8 and #(GetEntityCoords(heli) - vector3(target.x, target.y, target.z)) < 15.0 then landed = true; break end
        end
    end
    if not canContinue() then
        cleanup(interruptionReason()); running = false; return
    end
    local here = heli and DoesEntityExist(heli) and GetEntityCoords(heli)
    if near and here and #(here - vector3(target.x, target.y, here.z)) < 50.0
        and IsPedInVehicle(ped, heli, false) then
        if not landed then notify('着陸が安定せず、病院入口へ搬送します', 'warning') end
        local entrance = Config.Hospital.Entrance
        -- SetEntityCoordsNoOffsetはダウン・HPを変えない。実機のWasabi死亡アニメとの併用を要確認。
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, entrance.x, entrance.y, entrance.z, true, true, true)
        SetEntityHeading(ped, entrance.w)
        delivered = true
        if not confirmPhase('arrived') then
            notify('到着通知を確認できません。EMSへ直接連絡してください', 'warning')
        end
        notify('本院に到着しました。EMSによる救助をお待ちください', 'success')
    else
        notify('ヘリが病院に到達できませんでした。回収前の位置へ戻ります', 'error')
    end
    cleanup(); running = false
end
local function startFlight(request)
    CreateThread(function()
        local ok, err = xpcall(function() flight(request) end, debug.traceback)
        if not ok then
            print('[ptech_mediora_rescue] 搬送処理エラー: '..tostring(err))
            cleanup('救助機の搬送処理でエラーが発生しました。F8ログを確認してください'); running = false
        end
    end)
end
local function validDispatch(reply)
    return type(reply) == 'table' and type(reply.ticket) == 'number'
        and type(reply.heli) == 'number' and reply.heli > 0
        and type(reply.pilot) == 'number' and reply.pilot > 0
end
local function requestFailed(message)
    sending, heldAt, requestStartedAt, requestId = false, nil, nil, nil
    requestError, requestErrorUntil = message, GetGameTimer() + 4000
    syncAt = 0
    setRescuePanel('error', message)
    notify(message, 'error')
    print('[ptech_mediora_rescue] 要請失敗: ' .. message)
end
local function beginRequest()
    if sending or running then return end
    sending, heldAt, awaitingKeyRelease = true, nil, true
    statusRevision = statusRevision + 1
    requestAttempt = requestAttempt + 1
    local attempt = requestAttempt
    requestStartedAt = GetGameTimer()
    requestId = ('%d:%d:%d'):format(GetPlayerServerId(PlayerId()), requestStartedAt, attempt)
    local token = requestId
    setRescuePanel('active', '救助要請を送信しています')
    print('[ptech_mediora_rescue] 長押し完了・要請送信 request=' .. token)
    -- ox_libの応答待ちを表示・入力スレッドから切り離す。
    CreateThread(function()
        local ok, accepted, reason = pcall(lib.callback.await, 'ptech_mediora_rescue:request', false, token)
        if attempt ~= requestAttempt then
            if ok and validDispatch(accepted) then
                TriggerServerEvent('ptech_mediora_rescue:finish', accepted.ticket)
            end
            return
        end
        sending, requestStartedAt, requestId = false, nil, nil
        if ok and validDispatch(accepted) then
            status.used = true
            print(('[ptech_mediora_rescue] 要請応答 ticket=%s heliNet=%s pilotNet=%s')
                :format(accepted.ticket, accepted.heli, accepted.pilot))
            setRescuePanel('active', '救助機を呼び出しています')
            startFlight(accepted)
        else
            if not ok then print('[ptech_mediora_rescue] 要請通信エラー: ' .. tostring(accepted)) end
            TriggerServerEvent('ptech_mediora_rescue:cancelPending', token)
            requestFailed(type(reason) == 'string' and reason or '救助要請を受理できませんでした')
        end
    end)
end
RegisterNetEvent('ptech_mediora_rescue:cancel', function(ticket, recover, reason)
    if source ~= 65535 or activeTicket ~= ticket then return end
    if not recover then boarded = false end
    stopMessage = type(reason) == 'string' and reason or 'サーバーが救助要請を取り消しました'
    logAircraftFailure('サーバー取消受信: ' .. stopMessage)
    stopRequested = true
end)
RegisterNetEvent('ptech_mediora_rescue:emsNotify', function(stage)
    if source ~= 65535 then return end
    notify(stage == '搬送開始' and '警察官を本院へ緊急搬送中です' or '警察官が本院に到着しました。救助対応をお願いします')
end)
CreateThread(function()
    while true do
        local now = GetGameTimer()
        if not running and now >= syncAt and not sending then
            local revision = statusRevision
            syncAt = now + math.max(250, Config.SyncInterval)
            local ok, reply = pcall(lib.callback.await, 'ptech_mediora_rescue:status', false)
            -- 要請開始や搬送終了より前に送った応答は、現在の表示へ上書きしない。
            if revision == statusRevision and not running and not sending and ok and type(reply) == 'table' then
                reply.remaining = math.max(0, tonumber(reply.remaining) or 0)
                reply.receivedAt = GetGameTimer()
                status = reply
            end
        end
        Wait(50)
    end
end)
-- 入力と表示は通信待ちを挟まず毎フレーム処理する。
-- RPC前の時刻と応答受信時刻を混ぜると、待機時間が一瞬復活して長押しが消えてしまう。
CreateThread(function()
    while true do
        local now = GetGameTimer()
        if not rescueKeybind:isControlPressed() then awaitingKeyRelease = false end
        -- 一時的な取得失敗では長押しを維持するが、古い状態を無期限には使わない。
        if status.receivedAt and now - status.receivedAt > math.max(5000, Config.SyncInterval * 3) then
            status = { eligible = false }
        end
        if running then
            heldAt = nil
            if rescuePanel then drawRescueFallback() else
                local shared = setRescuePanel('active', '緊急搬送を実行中です')
                if not shared then drawRescueFallback() end
            end
            Wait(rescuePanelShared and 250 or 0)
        elseif sending then
            if now - requestStartedAt >= (Config.RequestTimeout or 15000) then
                local token = requestId
                requestAttempt = requestAttempt + 1
                TriggerServerEvent('ptech_mediora_rescue:cancelPending', token)
                requestFailed('救助要請の応答がありません。キーを離してから再度要請してください')
            else
                setRescuePanel('active', ('救助要請を送信中（応答待ち：%d秒）'):format(math.floor((now - requestStartedAt) / 1000)))
                drawRescueFallback()
            end
            Wait(rescuePanelShared and 50 or 0)
        elseif requestErrorUntil > now then
            heldAt = nil
            setRescuePanel('error', requestError)
            drawRescueFallback()
            Wait(rescuePanelShared and 50 or 0)
        elseif not status.eligible or status.used then
            heldAt = nil
            setRescuePanel(nil)
            Wait(250)
        else
            local remaining = math.max(0, (status.remaining or 0) - (now - (status.receivedAt or now)))
            if remaining > 0 then
                heldAt = nil
                local message = '緊急離脱まで ' .. clock(remaining)
                local shared = setRescuePanel('countdown', message)
                if not shared then hint(message) end
            else
                DisableControlAction(0, Config.Control, true)
                local held = rescueKeybind:isControlPressed()
                -- メニューやチャットへ移った間に解放コマンドを受け損ねても保持を残さない。
                if IsPauseMenuActive() or (IsNuiFocused() and not IsNuiFocusKeepingInput()) then
                    rescueKeybind.isPressed = false
                    held = false
                end
                if held and not awaitingKeyRelease then
                    heldAt = heldAt or now
                    local pct = math.min(100, math.floor((now - heldAt) / (Config.HoldDuration * 1000) * 100))
                    local message = ('%s 長押し中（%d%%）'):format(rescueKeyLabel(), pct)
                    local shared = setRescuePanel('holding', message, pct)
                    if not shared then hint(('%s（%d%%）'):format(message, pct)) end
                    if pct >= 100 and not sending then
                        beginRequest()
                    end
                else
                    heldAt = nil
                    local message = ('%sを%s秒長押しで緊急離脱'):format(rescueKeyLabel(), Config.HoldDuration)
                    local shared = setRescuePanel('ready', message, 0)
                    if not shared then hint(message) end
                end
            end
            Wait(0)
        end
    end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        requestAttempt = requestAttempt + 1
        if sending and requestId then TriggerServerEvent('ptech_mediora_rescue:cancelPending', requestId) end
        sending, requestStartedAt, requestId = false, nil, nil
        stopRequested = true; cleanup(); running = false
    end
    if resource == 'ptech_mediora_core' then rescuePanelShared = false end
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'ptech_mediora_core' or not rescuePanel then return end
    rescuePanelShared = false
    setRescuePanel(rescuePanel.state, rescuePanel.text, rescuePanel.progress)
end)

-- サーバー管理のネットワーク機体を公開前は他人から隠す。
-- スナップショット受信とエンティティのstream-in遅延による一瞬の露出は実機確認事項。
CreateThread(function()
    while true do
        local ok, entries = pcall(lib.callback.await, 'ptech_mediora_rescue:aircraftSnapshot', false)
        if ok and type(entries) == 'table' then visibleAircraft = entries end
        Wait(1000)
    end
end)
CreateThread(function()
    while true do
        if #visibleAircraft == 0 then Wait(250) else
            local own = GetPlayerServerId(PlayerId())
            for _, entry in ipairs(visibleAircraft) do
                for _, net in ipairs({ entry.heli, entry.pilot }) do
                    local entity = localNetworkEntity(net)
                    if entity ~= 0 and DoesEntityExist(entity) then
                        SetEntityCollision(entity, false, false)
                        SetEntityCompletelyDisableCollision(entity, true, false)
                        SetEntityInvincible(entity, true)
                        if not entry.published and entry.owner ~= own then
                            SetEntityLocallyInvisible(entity)
                        elseif not entry.published then
                            SetEntityAlpha(entity, Config.Helicopter.Transparency, false)
                        else
                            ResetEntityAlpha(entity)
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)
