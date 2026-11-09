-- 緊急浮上装置。死亡状態・水面観測・開始可否はサーバーが確認し、
-- クライアントは自分自身の緩やかな移動と、全員に見える浮輪表示だけを担当する。

local floats, floatProps, revisions = {}, {}, {}
local floatTicket, floatX, floatY, floatZ, blockedTicket, using = nil, nil, nil, nil, nil, false
local obstacleCheckAt, obstacleProbe, ascentObstructed = 0, nil, false
local deathStarted, holdStarted, activationErrorUntil = nil, nil, 0
local floatUi

local function notify(text, kind)
    lib.notify({ title = '緊急浮上装置', description = text, type = kind or 'inform' })
end

local function sendActionPanel(id, panel)
    SendNUIMessage({
        action = panel and 'setPanel' or 'removePanel',
        id = id,
        panel = panel,
        switchKey = Config.ActionPanel and Config.ActionPanel.SwitchKey or 'F6',
    })
end

-- Rescueから任意で呼び出す共通表示API。Marineを導入しない環境でもRescueは動作する。
exports('setActionPanel', function(panel)
    if type(panel) ~= 'table' or panel.id ~= 'rescue' or type(panel.text) ~= 'string' then return false end
    sendActionPanel('rescue', panel)
    return true
end)

exports('removeActionPanel', function(id)
    if id ~= 'rescue' then return false end
    sendActionPanel('rescue', nil)
    return true
end)

if lib.addKeybind then
    lib.addKeybind({
        name = 'ptech_mediora_action_panel_next',
        description = 'Medioraのアクション表示タブを切り替える',
        defaultKey = Config.ActionPanel and Config.ActionPanel.SwitchKey or 'F6',
        onPressed = function()
            SendNUIMessage({ action = 'nextTab' })
        end,
    })
end

local function isPlayerOrVehicleInWater(ped)
    if IsEntityInWater(ped) then return true end
    local vehicle = GetVehiclePedIsIn(ped, false)
    return vehicle ~= 0 and IsEntityInWater(vehicle)
end

local function showUi(state, text, progress)
    if state == nil then
        if not floatUi then return end
        sendActionPanel('marine', nil)
        floatUi = nil
        return
    end
    progress = progress and math.max(0, math.min(100, progress)) or nil
    if floatUi and floatUi.state == state and floatUi.text == text and floatUi.progress == progress then return end
    sendActionPanel('marine', {
        title = '緊急浮上装置',
        icon = '◌',
        state = state,
        text = text,
        progress = progress,
    })
    floatUi = { state = state, text = text, progress = progress }
end

local function deleteFloatProp(id)
    local entry = floatProps[id]
    if not entry then return end
    if DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    floatProps[id] = nil
end

local function clearFloatProps()
    local ids = {}
    for id in pairs(floatProps) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do deleteFloatProp(id) end
end

-- 浮輪は各クライアントでローカル表示する。ネットワークentityを持たないため、
-- 所有権移行や停止時の削除漏れを避けられる。
local function syncFloatProp(id, float, viewer)
    local visual = Config.Flotation.Visual
    if not visual or not visual.Enabled or not float then deleteFloatProp(id); return end
    local player = GetPlayerFromServerId(id)
    if player == -1 then deleteFloatProp(id); return end
    local target = GetPlayerPed(player)
    if target == 0 or not DoesEntityExist(target) or IsEntityAttached(target) or Marine.busy(Player(id).state) then
        deleteFloatProp(id)
        return
    end
    local distance = tonumber(visual.Distance) or 0.0
    if distance > 0.0 and #(GetEntityCoords(viewer) - GetEntityCoords(target)) > distance then
        deleteFloatProp(id)
        return
    end
    local current = floatProps[id]
    if current and current.ticket == float.ticket and current.ped == target and DoesEntityExist(current.entity) then return end
    deleteFloatProp(id)

    local model = type(visual.Model) == 'string' and joaat(visual.Model) or visual.Model
    if not model or not IsModelInCdimage(model) or not IsModelValid(model) then return end
    if not HasModelLoaded(model) then RequestModel(model); return end
    local pos = GetEntityCoords(target)
    local object = CreateObjectNoOffset(model, pos.x, pos.y, pos.z, false, false, false)
    if object == 0 then return end
    local offset, rotation = visual.Offset or {}, visual.Rotation or {}
    SetEntityCollision(object, false, false)
    SetEntityInvincible(object, true)
    SetEntityAsMissionEntity(object, true, true)
    AttachEntityToEntity(object, target, GetPedBoneIndex(target, visual.Bone or 24818),
        offset.x or 0.0, offset.y or 0.0, offset.z or 0.0,
        rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    floatProps[id] = { entity = object, ped = target, ticket = float.ticket }
end

local function requestFlotation()
    if using then return end
    using = true
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_marine:activateFlotation', false)
    if ok and type(result) == 'table' and Marine.finite(result.ejectToken) then
        CreateThread(function()
            local deadline = GetGameTimer() + 2500
            while IsPedInAnyVehicle(PlayerPedId(), false) and GetGameTimer() < deadline do
                local ped = PlayerPedId()
                TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
                Wait(100)
            end

            local ped = PlayerPedId()
            local confirmed, started = false, false
            if not IsPedInAnyVehicle(ped, false) then
                local confirmDeadline = GetGameTimer() + 1500
                repeat
                    confirmed, started = pcall(lib.callback.await,
                        'ptech_mediora_marine:confirmFlotationEjection', false, result.ejectToken)
                    if confirmed and started then break end
                    Wait(150)
                until GetGameTimer() >= confirmDeadline
            end
            using = false
            if not confirmed or not started then
                activationErrorUntil = GetGameTimer() + 3000
                showUi('error', '車外への退避を確認できません。安全な場所で再度お試しください。')
                notify('車外への退避または浮上開始を確認できませんでした。', 'error')
            end
        end)
        return
    end

    using = false
    if ok and result then return end
    activationErrorUntil = GetGameTimer() + 3000
    showUi('error', '浮上装置を使用できません。水中かつ死亡状態を確認してください。')
    notify('浮上装置を使用できません。水中かつ死亡状態であることを確認してください。', 'error')
end

-- サーバーはクライアントから水面位置を受け取るが、死亡時刻・水深・座標・バケットを
-- そのまま信用しない。詳細な検証はサーバーのactivateFlotationで行う。
lib.callback.register('ptech_mediora_marine:flotationWater', function()
    local ped = PlayerPedId()
    if not isPlayerOrVehicleInWater(ped) or IsEntityAttached(ped) then return nil end
    local coords = GetEntityCoords(ped)
    local found, surface = GetWaterHeightNoWaves(coords.x, coords.y, coords.z)
    if not found or not Marine.finite(surface) or coords.z > surface + Config.Flotation.SurfaceTolerance then return nil end
    return { water = true, x = coords.x, y = coords.y, z = coords.z, surface = surface }
end)

local function receiveFloat(id, float, revision)
    if type(id) ~= 'number' or type(revision) ~= 'number' then return end
    if revision < (revisions[id] or -1) then return end
    revisions[id] = revision
    floats[id] = float
    if not float then deleteFloatProp(id) end
end

RegisterNetEvent('ptech_mediora_marine:flotation', function(id, float, revision)
    -- クライアントではsource値をサーバーイベントの認証に使えない。
    -- このイベントをローカルで偽装しても他者・サーバー状態は変化しないため、
    -- 引数を検証したうえでサーバー配信をそのまま表示へ反映する。
    receiveFloat(id, float, revision)
end)

local function reset()
    clearFloatProps()
    floats, revisions = {}, {}
    floatTicket, floatX, floatY, floatZ, blockedTicket = nil, nil, nil, nil, nil
    obstacleCheckAt, obstacleProbe, ascentObstructed = 0, nil, false
    using = false
    deathStarted, holdStarted, activationErrorUntil = nil, nil, 0
    floatUi = nil
    SendNUIMessage({ action = 'clearPanels' })
end

RegisterNetEvent('ptech_mediora_marine:resetFlotation', function()
    reset()
end)

CreateThread(function()
    local snapshot = lib.callback.await('ptech_mediora_marine:flotationSnapshot', false)
    if snapshot then
        for id, float in pairs(snapshot.floats or {}) do receiveFloat(id, float, snapshot.revision) end
    end
end)

local function formatRemaining(milliseconds)
    local seconds = math.max(0, math.ceil(milliseconds / 1000))
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function capsuleBlocked(x1, y1, z1, x2, y2, z2, ped)
    local handle = StartShapeTestCapsule(x1, y1, z1, x2, y2, z2, 0.35, 1 | 16, ped, 7)
    local status, hit = GetShapeTestResult(handle)
    local deadline = GetGameTimer() + 100
    while status == 1 and GetGameTimer() < deadline do
        Wait(0)
        status, hit = GetShapeTestResult(handle)
    end
    return status ~= 2 or hit == true or hit == 1
end

local function findAscentRoute(ped, x, y, z, surface)
    -- 近い順に水平方向の退避路を探し、そこから水面までの縦道が空いている場所を選ぶ。
    for _, radius in ipairs({ 2.0, 4.0, 6.0, 8.0 }) do
        for direction = 0, 7 do
            local angle = direction * math.pi / 4
            local candidateX = x + math.cos(angle) * radius
            local candidateY = y + math.sin(angle) * radius
            local horizontalClear = not capsuleBlocked(x, y, z,
                candidateX, candidateY, z, ped)
            local verticalClear = horizontalClear and not capsuleBlocked(candidateX, candidateY, z,
                candidateX, candidateY, surface - 0.25, ped)
            if verticalClear then return candidateX, candidateY end
        end
    end
    return nil
end

local function checkAscentRoute(own, ped, float, z)
    local probe = {}
    obstacleProbe = probe
    obstacleCheckAt = GetGameTimer() + 750

    local function currentFloat()
        local current = floats[own]
        if obstacleProbe == probe and current and current.ticket == float.ticket and blockedTicket ~= float.ticket
            and current.x == float.x and current.y == float.y and current.surface == float.surface
            and PlayerPedId() == ped and not IsPedInAnyVehicle(ped, false)
            and not Marine.busy(LocalPlayer.state) and not IsEntityAttached(ped)
            and floatZ < current.surface - 0.5 then
            return current
        end
    end

    local function reportRoute(x, y, blocked)
        local ok, accepted = pcall(lib.callback.await, 'ptech_mediora_marine:reportFlotationObstacle',
            false, float.ticket, { x = x, y = y, z = floatZ, blocked = blocked })
        return ok and accepted
    end

    CreateThread(function()
        local blocked = capsuleBlocked(float.x, float.y, z, float.x, float.y, float.surface - 0.25, ped)
        local current = currentFloat()
        local retry = false
        if current then
            ascentObstructed = blocked
            if blocked then
                -- 迂回路を探す前にサーバー側の上昇も止める。
                if current.blocked or reportRoute(float.x, float.y, true) then
                    if currentFloat() then
                        local routeX, routeY = findAscentRoute(ped, float.x, float.y, floatZ, float.surface)
                        if currentFloat() then
                            retry = not routeX or not reportRoute(routeX, routeY, false)
                        end
                    end
                else
                    retry = true
                end
            elseif current.blocked then
                retry = not reportRoute(float.x, float.y, false)
            end
        end
        if obstacleProbe == probe then
            obstacleProbe = nil
            if retry then obstacleCheckAt = GetGameTimer() + 3000 end
        end
    end)
end

CreateThread(function()
    while true do
        local ped, own = PlayerPedId(), GetPlayerServerId(PlayerId())
        local isDown = Marine.down(LocalPlayer.state, {}) or IsEntityDead(ped)
        if isDown then deathStarted = deathStarted or GetGameTimer() else deathStarted, holdStarted = nil, nil end

        local ownFloat = floats[own]
        Wait((isDown or ownFloat ~= nil) and 0 or 250)
        local inWater = isPlayerOrVehicleInWater(ped)

        if ownFloat then
            holdStarted = nil
            if ownFloat.blocked then
                showUi('unavailable', '地形に遮られています：周囲の救助を待機中')
            elseif inWater then
                showUi('active', '浮上装置作動中：水面で救助を待機中')
            else
                showUi(nil)
            end
        elseif not Config.Flotation.Enabled or not isDown or not inWater then
            holdStarted = nil
            showUi(nil)
        elseif activationErrorUntil > GetGameTimer() then
            holdStarted = nil
        elseif using then
            holdStarted = nil
            showUi('holding', '浮上準備中：車外へ退避しています')
        else
            local remaining = math.max(0, Config.Flotation.Countdown * 1000 - (GetGameTimer() - deathStarted))
            if remaining > 0 then
                holdStarted = nil
                showUi('countdown', ('浮上装置使用まで：%s'):format(formatRemaining(remaining)))
            elseif Marine.busy(LocalPlayer.state) or IsEntityAttached(ped) then
                holdStarted = nil
                showUi('unavailable', '搬送中は浮上装置を使用できません')
            else
                -- 車内ではFが通常の降車操作にも使われるため、発動待ちの間だけ入力を捕捉する。
                local inVehicle = IsPedInAnyVehicle(ped, false)
                if inVehicle then DisableControlAction(0, Config.Flotation.Control, true) end
                local held = IsControlPressed(0, Config.Flotation.Control)
                    or IsDisabledControlPressed(0, Config.Flotation.Control)
                if held then
                    holdStarted = holdStarted or GetGameTimer()
                    local holdFor = math.max(0, Config.Flotation.HoldDuration) * 1000
                    local progress = math.min(100, math.floor((GetGameTimer() - holdStarted) / math.max(holdFor, 1) * 100))
                    showUi('holding', ('%sを長押しして浮上装置を使用'):format(Config.Flotation.ControlLabel), progress)
                    if GetGameTimer() - holdStarted >= holdFor then holdStarted = nil; requestFlotation() end
                else
                    holdStarted = nil
                    showUi('ready', ('%sを長押しして浮上装置を使用'):format(Config.Flotation.ControlLabel), 0)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(next(floats) ~= nil and 0 or 250)
        local own, ped = GetPlayerServerId(PlayerId()), PlayerPedId()
        local float = floats[own]
        if float then
            if not IsPedInAnyVehicle(ped, false) then
                if floatTicket ~= float.ticket then
                    local coords = GetEntityCoords(ped)
                    floatTicket, floatX, floatY, floatZ, blockedTicket =
                        float.ticket, coords.x, coords.y, coords.z, nil
                    obstacleCheckAt, obstacleProbe, ascentObstructed = 0, nil, false
                end
                -- Escortのattachが始まった時点で制御権を譲り、同じticketで再開しない。
                if Marine.busy(LocalPlayer.state) or IsEntityAttached(ped) then blockedTicket = float.ticket end
                if blockedTicket ~= float.ticket then
                    local dx, dy = float.x - floatX, float.y - floatY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if not obstacleProbe and GetGameTimer() >= obstacleCheckAt
                        and distance < 0.1 and floatZ < float.surface - 0.5 then
                        checkAscentRoute(own, ped, float, floatZ)
                    end

                    local riseSpeed = math.max(0.0, Config.Flotation.RiseSpeed)
                    local horizontalStep = riseSpeed * math.min(GetFrameTime(), 0.1)
                    local step = horizontalStep
                    if float.blocked then
                        floatZ = floatZ + math.max(-step, math.min(0.0, float.z - floatZ))
                    elseif not ascentObstructed then
                        -- 通常は毎フレーム定速で上昇し、配信座標から最大250ms分だけ先行する。
                        local maxLead = riseSpeed * 0.25
                        local ceiling = math.min(float.surface, float.z + maxLead)
                        if float.z - floatZ > maxLead then step = step * 2.0 end
                        floatZ = math.max(floatZ, math.min(ceiling, floatZ + step))
                    end
                    floatZ = math.min(float.surface, floatZ)
                    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                    if distance <= horizontalStep then
                        floatX, floatY = float.x, float.y
                    elseif distance > 0.0 then
                        floatX = floatX + dx / distance * horizontalStep
                        floatY = floatY + dy / distance * horizontalStep
                    end
                    SetEntityCoordsNoOffset(ped, floatX, floatY, floatZ, true, true, true)
                end
            end
        else
            floatTicket, floatX, floatY, floatZ, blockedTicket = nil, nil, nil, nil, nil
            obstacleCheckAt, obstacleProbe, ascentObstructed = 0, nil, false
        end

        if Config.Flotation.Visual and Config.Flotation.Visual.Enabled then
            for id, activeFloat in pairs(floats) do syncFloatProp(id, activeFloat, ped) end
            local stale = {}
            for id in pairs(floatProps) do if not floats[id] then stale[#stale + 1] = id end end
            for _, id in ipairs(stale) do deleteFloatProp(id) end
        else
            clearFloatProps()
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then reset() end
end)
