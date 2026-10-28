local status = { eligible = false }
local syncAt, heldAt, sending = 0, nil, false
local running, heli, pilot = false, nil, nil
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
local function loadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local untilTime = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < untilTime do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
local function cleanup()
    if pilot and DoesEntityExist(pilot) then DeleteEntity(pilot) end
    if heli and DoesEntityExist(heli) then DeleteEntity(heli) end
    pilot, heli = nil, nil
end
local function ghost()
    if not heli or not DoesEntityExist(heli) then return end
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
    if hit == 1 and endCoords and endCoords.z > pos.z then return endCoords.z end
    return pos.z
end
local function flight()
    if running then return end
    running = true
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local cfg = Config.Helicopter
    local vehicleModel, pilotModel = loadModel(cfg.Model), loadModel(cfg.Pilot)
    if not vehicleModel or not pilotModel then notify('回収機を読み込めませんでした', 'error'); running = false; return end
    local spawnZ = roofHeight(start) + cfg.HoverOffset
    heli = CreateVehicle(vehicleModel, start.x, start.y, spawnZ, GetEntityHeading(ped), false, false)
    if not heli or heli == 0 then notify('回収機の生成に失敗しました', 'error'); running = false; return end
    SetEntityAsMissionEntity(heli, true, true)
    SetEntityAlpha(heli, cfg.Transparency, false)
    SetVehicleEngineOn(heli, true, true, false)
    pilot = CreatePedInsideVehicle(heli, 4, pilotModel, -1, false, false)
    SetModelAsNoLongerNeeded(vehicleModel); SetModelAsNoLongerNeeded(pilotModel)
    if not pilot or pilot == 0 then cleanup(); running = false; return end
    ghost()
    -- 1秒回収: GTA標準ロープは屋内・地下への長距離描画に制限があるため、
    -- 現段階ではロープの視覚演出を保証せず、1秒後の搭乗処理を優先する。
    local pickupEnd = GetGameTimer() + cfg.PickupSeconds * 1000
    while GetGameTimer() < pickupEnd do
        Wait(0); ghost()
    end
    -- ダウン状態を変更せず、ヘリの空席へ配置する。
    if not Rescue.down(LocalPlayer.state, {}) and not IsEntityDead(ped) then cleanup(); running = false; return end
    SetPedIntoVehicle(ped, heli, 0)
    if not IsPedInVehicle(ped, heli, false) then
        notify('ヘリへの搭乗に失敗しました', 'error')
        SetEntityCoordsNoOffset(ped, start.x, start.y, start.z, false, false, false)
        cleanup(); running = false; return
    end
    TriggerServerEvent('ptech_mediora_rescue:phase', 'transporting')
    CreateThread(function()
        while running do
            Wait(0)
            DisableControlAction(0, 75, true) -- 降車禁止。視点操作は維持。
            DisableControlAction(0, 76, true) -- ハンドブレーキ等の操作禁止。
        end
    end)
    local target = Config.Hospital.Helipad
    local cruiseZ = math.max(spawnZ + 30.0, target.z + cfg.CruiseHeight)
    TaskHeliMission(pilot, heli, 0, 0, target.x, target.y, cruiseZ, 4, cfg.Speed, 12.0, -1.0, -1, -1, -1.0, 0)
    local started, lastMoved, previous = GetGameTimer(), GetGameTimer(), GetEntityCoords(heli)
    local near = false
    while GetGameTimer() - started < cfg.MaxFlightSeconds * 1000 do
        Wait(100)
        if not DoesEntityExist(heli) or not DoesEntityExist(pilot) then break end
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
        while GetGameTimer() < landingEnd and DoesEntityExist(heli) do
            Wait(100); ghost()
            if GetEntityHeightAboveGround(heli) < 1.8 and #(GetEntityCoords(heli) - vector3(target.x, target.y, target.z)) < 15.0 then landed = true; break end
        end
    end
    if near then
        if not landed then notify('着陸が安定せず、病院入口へ搬送します', 'warning') end
        local entrance = Config.Hospital.Entrance
        -- SetEntityCoordsNoOffsetはダウン・HPを変えない。実機のWasabi死亡アニメとの併用を要確認。
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, entrance.x, entrance.y, entrance.z, false, false, false)
        SetEntityHeading(ped, entrance.w)
        TriggerServerEvent('ptech_mediora_rescue:phase', 'arrived')
        notify('本院に到着しました。EMSによる救助をお待ちください', 'success')
    else
        notify('ヘリが病院に到達できませんでした。現在地で救助をお待ちください', 'error')
        -- 病院から遠い場合は長距離TPせず、現在のヘリ位置で解放。
        if DoesEntityExist(heli) then
            local p = GetEntityCoords(heli)
            ClearPedTasksImmediately(ped)
            SetEntityCoordsNoOffset(ped, p.x, p.y, p.z - 2.0, false, false, false)
        end
    end
    cleanup(); running = false
end
RegisterNetEvent('ptech_mediora_rescue:dispatch', function()
    if source ~= 65535 or running then return end
    CreateThread(flight)
end)
RegisterNetEvent('ptech_mediora_rescue:emsNotify', function(stage)
    if source ~= 65535 then return end
    notify(stage == '搬送開始' and '警察官を本院へ緊急搬送中です' or '警察官が本院に到着しました。救助対応をお願いします')
end)
CreateThread(function()
    while true do
        local now = GetGameTimer()
        if not running and now >= syncAt and not sending then
            syncAt = now + math.max(250, Config.SyncInterval)
            local ok, reply = pcall(lib.callback.await, 'ptech_mediora_rescue:status', false)
            status = ok and reply or { eligible = false }
            if status.eligible and not status.used then
                status.remaining = math.max(0, status.remaining or 0)
                status.receivedAt = GetGameTimer()
            end
        end
        if running or not status.eligible or status.used then heldAt = nil; Wait(250)
        else
            local remaining = math.max(0, (status.remaining or 0) - (now - (status.receivedAt or now)))
            if remaining > 0 then heldAt = nil; hint('緊急離脱まで ' .. clock(remaining))
            else
                DisableControlAction(0, Config.Control, true)
                if IsDisabledControlPressed(0, Config.Control) then
                    heldAt = heldAt or now
                    local pct = math.min(100, math.floor((now - heldAt) / (Config.HoldDuration * 1000) * 100))
                    hint(('%s 長押しで緊急離脱（%d%%）'):format(Config.ControlLabel, pct))
                    if pct >= 100 and not sending then
                        sending, heldAt = true, nil
                        local ok, accepted = pcall(lib.callback.await, 'ptech_mediora_rescue:request', false)
                        sending = false
                        if ok and accepted then status.used = true else notify('救助要請を受理できませんでした', 'error'); syncAt = 0 end
                    end
                else heldAt = nil; hint(Config.ControlLabel .. ' 長押しで緊急離脱') end
            end
            Wait(0)
        end
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cleanup() end
end)
