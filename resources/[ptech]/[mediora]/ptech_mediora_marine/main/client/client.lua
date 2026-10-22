local floats, floatProps, equipped, shoes, boosted = {}, {}, false, nil, false
local floatTicket, floatZ, blockedTicket
local using = false
local floatRevisions, finsRevision = {}, -1
local deathStarted, holdStarted, textUi = nil, nil, nil

local function notify(text, kind)
    lib.notify({ description = text, type = kind or 'inform' })
end

local function showText(text)
    if textUi == text then return end
    if textUi then lib.hideTextUI() end
    if text then lib.showTextUI(text, { position = 'right-center', icon = 'life-ring' }) end
    textUi = text
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

-- 既製propを各クライアントでローカル生成する。ネットワークentityにしないことで
-- 所有権移行や削除漏れを避け、サーバーの浮上状態だけを正として同期する。
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
        false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)
    floatProps[id] = { entity = object, ped = target, ticket = float.ticket }
end

local function restoreShoes()
    if not shoes then return end
    local ped = PlayerPedId()
    -- 衣装側で履き替え済みなら、その変更を古い靴で上書きしない。
    if ped == shoes.ped and GetEntityModel(ped) == shoes.model
        and GetPedDrawableVariation(ped, 6) == shoes.applied.drawable
        and GetPedTextureVariation(ped, 6) == shoes.applied.texture then
        SetPedComponentVariation(ped, 6, shoes.drawable, shoes.texture, shoes.palette)
    end
    shoes = nil
end

local function setFins(enabled)
    restoreShoes()
    equipped = enabled == true
    if boosted then SetSwimMultiplierForPlayer(PlayerId(), 1.0); boosted = false end
    if not equipped then return end
    local ped = PlayerPedId()
    local appearance
    for model, value in pairs(Config.Fins.Appearance) do
        if GetEntityModel(ped) == joaat(model) then appearance = value; break end
    end
    if not appearance then
        notify('フィン装備：対応する外観モデルは未設定です（泳速のみ適用）')
        return
    end
    local drawable, texture = appearance.drawable, appearance.texture or 0
    if not Marine.finite(drawable) or drawable % 1 ~= 0 or drawable < 0
        or drawable >= GetNumberOfPedDrawableVariations(ped, 6)
        or not Marine.finite(texture) or texture % 1 ~= 0 or texture < 0
        or texture >= GetNumberOfPedTextureVariations(ped, 6, drawable) then
        notify('フィンの外観設定が無効です（泳速のみ適用）', 'error')
        return
    end
    shoes = { ped = ped, model = GetEntityModel(ped), drawable = GetPedDrawableVariation(ped, 6),
        texture = GetPedTextureVariation(ped, 6), palette = GetPedPaletteVariation(ped, 6),
        applied = { drawable = drawable, texture = texture } }
    SetPedComponentVariation(ped, 6, drawable, texture, appearance.palette or 0)
end

local function requestFlotation()
    if using then return end
    using = true
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_marine:activateFlotation', false)
    using = false
    if not ok or not result then notify('浮上装置を使用できません。水中かつ死亡状態であることを確認してください。', 'error') end
end

exports('toggleFins', function(data, slot)
    exports.ox_inventory:useItem(data, function(used)
        if not used then return end
        local result = lib.callback.await('ptech_mediora_marine:toggleFins', false)
        if not result then notify('フィンは所持している勤務中のEMSのみ使用できます', 'error') end
    end)
end)

lib.callback.register('ptech_mediora_marine:water', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if not IsEntityInWater(ped) or IsPedInAnyVehicle(ped, false) or IsEntityAttached(ped) then return nil end
    local found, surface = GetWaterHeightNoWaves(coords.x, coords.y, coords.z)
    if not found or not Marine.finite(surface) or coords.z > surface + Config.Flotation.SurfaceTolerance then return nil end
    return { water = true, x = coords.x, y = coords.y, z = coords.z, surface = surface }
end)

local function receiveFins(enabled, revision)
    if revision < finsRevision then return end
    finsRevision = revision
    setFins(enabled)
end

local function receiveFloat(id, float, revision)
    if revision < (floatRevisions[id] or -1) then return end
    floatRevisions[id] = revision
    floats[id] = float
    if not float then deleteFloatProp(id) end
end

RegisterNetEvent('ptech_mediora_marine:fins', function(enabled, revision)
    if source ~= 65535 then return end
    receiveFins(enabled, revision)
end)

RegisterNetEvent('ptech_mediora_marine:flotation', function(id, float, revision)
    if source ~= 65535 then return end
    receiveFloat(id, float, revision)
end)

local function reset()
    clearFloatProps()
    floats = {}
    floatRevisions, finsRevision = {}, -1
    floatTicket, floatZ, blockedTicket = nil, nil, nil
    deathStarted, holdStarted = nil, nil
    showText(nil)
    setFins(false)
end

RegisterNetEvent('ptech_mediora_marine:reset', function()
    if source == 65535 then reset() end
end)

CreateThread(function()
    local snapshot = lib.callback.await('ptech_mediora_marine:snapshot', false)
    if snapshot then
        for id, float in pairs(snapshot.floats or {}) do receiveFloat(id, float, snapshot.revision) end
        receiveFins(snapshot.fins, snapshot.revision)
    end
end)

local function formatRemaining(milliseconds)
    local seconds = math.max(0, math.ceil(milliseconds / 1000))
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

-- Wasabiの死亡画面は変更せず、独立したTextUIで残り時間とF長押しを案内する。
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local own = GetPlayerServerId(PlayerId())
        local isDown = Marine.down(LocalPlayer.state, {}) or IsEntityDead(ped)
        if isDown then deathStarted = deathStarted or GetGameTimer() else deathStarted, holdStarted = nil, nil end

        local ownFloat = floats[own]
        local active = isDown or ownFloat ~= nil
        Wait(active and 0 or 250)
        if ownFloat then
            holdStarted = nil
            showText('浮上装置作動中：水面でEMSを待機中')
        elseif not isDown or not Config.Flotation.Enabled then
            showText(nil)
        else
            local remaining = math.max(0, Config.Flotation.Countdown * 1000 - (GetGameTimer() - deathStarted))
            if remaining > 0 then
                holdStarted = nil
                showText(('浮上装置使用まで：%s'):format(formatRemaining(remaining)))
            elseif not IsEntityInWater(ped) then
                holdStarted = nil
                showText('浮上装置は水中でのみ使用できます')
            elseif Marine.busy(LocalPlayer.state) or IsEntityAttached(ped) or IsPedInAnyVehicle(ped, false) then
                holdStarted = nil
                showText('搬送中は浮上装置を使用できません')
            else
                local held = IsControlPressed(0, Config.Flotation.Control)
                if held then
                    holdStarted = holdStarted or GetGameTimer()
                    local holdFor = math.max(0, Config.Flotation.HoldDuration) * 1000
                    local progress = math.min(100, math.floor((GetGameTimer() - holdStarted) / math.max(holdFor, 1) * 100))
                    showText(('%sを長押しして浮上装置を使用（%d%%）'):format(Config.Flotation.ControlLabel, progress))
                    if GetGameTimer() - holdStarted >= holdFor then
                        holdStarted = nil
                        requestFlotation()
                    end
                else
                    holdStarted = nil
                    showText(('%sを長押しして浮上装置を使用'):format(Config.Flotation.ControlLabel))
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        local own = GetPlayerServerId(PlayerId())
        local float, ped = floats[own], PlayerPedId()
        local active = float ~= nil or equipped or next(floats) ~= nil
        Wait(active and 0 or 250)
        if equipped then
            local swim = IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
            if swim then
                SetSwimMultiplierForPlayer(PlayerId(), math.max(1.0, math.min(1.49, Config.Fins.SwimMultiplier)))
                boosted = true
            elseif boosted then SetSwimMultiplierForPlayer(PlayerId(), 1.0); boosted = false end
            if shoes and shoes.ped ~= ped then setFins(false) end
        end
        if float then
            if floatTicket ~= float.ticket then
                floatTicket, floatZ, blockedTicket = float.ticket, GetEntityCoords(ped).z, nil
            end
            -- Escortのattachと同フレームから譲る。凍結・アニメ解除・蘇生は行わない。
            if Marine.busy(LocalPlayer.state) or IsEntityAttached(ped) or IsPedInAnyVehicle(ped, false) then
                blockedTicket = float.ticket
            end
            if blockedTicket ~= float.ticket then
                floatZ = math.min(float.surface, floatZ + math.max(0.0, Config.Flotation.RiseSpeed) * math.min(GetFrameTime(), 0.1))
                SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                SetEntityCoordsNoOffset(ped, float.x, float.y, floatZ, true, true, true)
            end
        else floatTicket, floatZ, blockedTicket = nil, nil, nil end

        if Config.Flotation.Visual and Config.Flotation.Visual.Enabled then
            for id, activeFloat in pairs(floats) do syncFloatProp(id, activeFloat, ped) end
            local stale = {}
            for id in pairs(floatProps) do if not floats[id] then stale[#stale + 1] = id end end
            for _, id in ipairs(stale) do deleteFloatProp(id) end
        else
            clearFloatProps()
        end
        if Config.Flotation.Marker then
            for id in pairs(floats) do
                local player = GetPlayerFromServerId(id)
                if player ~= -1 then
                    local target = GetPlayerPed(player)
                    if target ~= 0 and not IsEntityAttached(target) and not Marine.busy(Player(id).state) then
                        local pos = GetEntityCoords(target)
                        if #(GetEntityCoords(ped) - pos) < 80.0 then
                            DrawMarker(25, pos.x, pos.y, pos.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                1.1, 1.1, 0.25, 255, 120, 0, 190, false, false, 2, false, nil, nil, false)
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    reset()
end)
