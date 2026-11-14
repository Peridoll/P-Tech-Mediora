MedicalWoundClient = {}
local C, W = MedicalWoundClient, MedicalWounds
local snapshot, citizenId, token, revision, sequence = nil, nil, nil, -1, 0
local generation, lastHealth, lastPed, applying, suspended = 0, nil, nil, false, false
local lastPin, nextAction, wasAction, nextBleed = 0, 0, false, 0
local function removeAutoRevivePanel()
    if GetResourceState('ptech_mediora_core') == 'started' then
        pcall(function() exports.ptech_mediora_core:removeActionPanel('medical-auto-revive') end)
    end
end

local autoReviveDisplay
local function renderAutoRevivePanel(seconds)
    if seconds == false then removeAutoRevivePanel(); return end
    local idle = seconds == true
    if not idle and (not W.finite(seconds) or seconds < 0 or seconds > 15) then return end
    if GetResourceState('ptech_mediora_core') == 'started' then
        pcall(function()
            exports.ptech_mediora_core:setActionPanel({
                id = 'medical-auto-revive', title = 'ピースフルモード', icon = '✚',
                text = idle and '死亡後自動蘇生' or seconds > 0 and ('あと%d秒で蘇生'):format(seconds) or '蘇生しています…',
                progress = not idle and (15 - seconds) / 15 * 100 or nil, state = 'active',
                temporaryExpand = not idle,
                startMinimized = idle,
            })
        end)
    end
end

RegisterNetEvent('ptech_mediora_medical:autoReviveStatus', function(seconds)
    if source ~= 65535 then return end
    if seconds ~= true and seconds ~= false and (not W.finite(seconds) or seconds < 0 or seconds > 15) then return end
    autoReviveDisplay = seconds
    renderAutoRevivePanel(seconds)
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then removeAutoRevivePanel() end
end)

local accumulationVisible = false
local function showAccumulation(state)
    SendNUIMessage({
        action = 'wounds:accumulation',
        data = { visible = accumulationVisible, parts = state and state.parts },
    })
end

RegisterCommand('medwounds', function()
    accumulationVisible = not accumulationVisible
    C.refresh()
    showAccumulation(snapshot)
end, false)

local weapons = {}
for name, kind in pairs(Config.Wounds.WeaponKinds) do weapons[GetHashKey(name)] = kind end

local function identity()
    local data = exports.qbx_core:GetPlayerData()
    return not suspended and data and data.citizenid, data
end

local function reset()
    generation = generation + 1
    accumulationVisible = false
    autoReviveDisplay = nil
    removeAutoRevivePanel()
    showAccumulation(nil)
    snapshot, citizenId, token, revision, sequence = nil, nil, nil, -1, 0
    lastHealth, lastPed, nextAction, wasAction, nextBleed = nil, nil, 0, false, 0
end

function C.apply(result)
    if type(result) ~= 'table' or result.citizenId ~= citizenId or identity() ~= citizenId
        or type(result.state) ~= 'table' or not W.finite(result.revision) or result.revision < revision then return false end
    snapshot, revision = result.state, result.revision
    if accumulationVisible then showAccumulation(snapshot) end
    return true
end

function C.refresh()
    local id = identity()
    if type(id) ~= 'string' or id == '' then if citizenId then reset() end; return end
    if citizenId ~= id then reset(); citizenId = id end
    if token then
        if autoReviveDisplay ~= nil then renderAutoRevivePanel(autoReviveDisplay) end
        return
    end
    local request = generation
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:wounds:get', false, id)
    if request ~= generation or identity() ~= id then return end
    if ok and result and result.token and C.apply(result) then
        token, sequence = result.token, result.sequence or 0
        lastPed, lastHealth = PlayerPedId(), GetEntityHealth(PlayerPedId())
    end
end

function C.send(part, kind, percent)
    if not token or identity() ~= citizenId then return end
    sequence = sequence + 1
    TriggerServerEvent('ptech_mediora_medical:damage', { citizenId = citizenId, token = token,
        sequence = sequence, part = part, kind = kind, percent = math.min(100, math.max(0, percent)) })
end

local function healthRange(ped) return math.max(1, GetEntityMaxHealth(ped) - Config.Wounds.HealthBase) end

local function cause(weapon)
    if weapons[weapon] then return weapons[weapon] end
    local damageType = GetWeaponDamageType(weapon)
    if damageType == 3 then return 'shot' end
    if damageType == 2 or damageType == 8 or damageType == 14 then return 'blunt' end
    if damageType == 5 or damageType == 6 then return 'burn' end
    if damageType == 11 then return 'cut' end
    -- 未知の原因やガスを無条件に打ち身へ読み替えない。
end

function C.sampleDamage(weapon, part)
    local ped = PlayerPedId()
    if not token or identity() ~= citizenId or applying or ped ~= lastPed then return end
    local kind = cause(weapon)
    if not kind then lastHealth = GetEntityHealth(ped); return end
    local health = GetEntityHealth(ped)
    local lost = math.max(0, (lastHealth or health) - math.max(Config.Wounds.HealthBase, health))
    lastHealth = health
    if kind == 'pin' then
        if GetGameTimer() - lastPin < 150 then return end
        lastPin = GetGameTimer()
    elseif lost <= 0 and kind ~= 'drowning' then return end
    local hasPin = false
    for _, p in pairs(snapshot and snapshot.parts or {}) do if p.wounds.pin then hasPin = true; break end end
    if kind == 'burn' and hasPin and Config.Wounds.PinMultiplier > 1 and lost > 0 then
        -- GTAが適用した火傷ダメージに差分だけ追加。生成したダメージを再蓄積しない。
        applying = true
        ApplyDamageToPed(ped, math.ceil(lost * (Config.Wounds.PinMultiplier - 1)), false)
        applying = false
        lost = lost * Config.Wounds.PinMultiplier
        lastHealth = GetEntityHealth(ped)
    end
    C.send(part, kind, lost / healthRange(ped) * 100)
end

AddEventHandler('entityDamaged', function(victim, _, weapon)
    if victim ~= PlayerPedId() or applying or not token then return end
    local found, bone = GetPedLastDamageBone(victim)
    local part = found and Config.Wounds.BoneParts[bone] or Config.Wounds.FallbackPart
    part = W.validPart(part) and part or Config.Wounds.FallbackPart
    -- HPの実減少をその場で読む。次の定期サンプルへ持ち越して差分を失わない。
    -- baseDamageは修正倍率を含まないため、HP実減少量の代わりに使わない。
    C.sampleDamage(weapon, part)
end)

local function alive()
    local id, data = identity()
    local ped = PlayerPedId()
    if id ~= citizenId or not snapshot or ped == 0 then return false end
    local death = Medical.death(LocalPlayer and LocalPlayer.state.dead, data.metadata)
    return GetEntityHealth(ped) > 0 and not IsPedDeadOrDying(ped, true)
        and death ~= '死亡' and death ~= '瀕死（laststand）'
end

local function ownDamage(percent, fatalAtBase)
    local ped = PlayerPedId()
    applying = true
    ApplyDamageToPed(ped, math.max(1, math.ceil(healthRange(ped) * percent / 100)), false)
    if fatalAtBase and GetEntityHealth(ped) <= Config.Wounds.HealthBase
        and not IsPedDeadOrDying(ped, true) then
        SetEntityHealth(ped, 0)
    end
    applying = false
    lastHealth = GetEntityHealth(ped)
end

function C.step()
    if not alive() then wasAction = false; return end
    local now, ped = GetGameTimer(), PlayerPedId()
    if now >= nextBleed then
        nextBleed = now + 1000
        if W.active(snapshot, 'bleeding') then ownDamage(Config.Wounds.BleedDamage, true) end
    end
    if not alive() then wasAction = false; return end
    if IsPedInAnyVehicle(ped, true) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
        or IsEntityAttached(ped) then wasAction = false; return end
    local action = IsPedJumping(ped) or IsPedClimbing(ped) or IsPedVaulting(ped) or IsPedDiving(ped)
        or (IsPedEvasiveDiving and IsPedEvasiveDiving(ped)) or C.sliding == true
    if not action then wasAction = false; return end
    if wasAction or now < nextAction or IsPedRagdoll(ped) then return end
    local ordered = {}
    for _, part in ipairs(Medical.fractureParts) do
        if snapshot.parts[part].fracture == 'active' then ordered[#ordered + 1] = part end
    end
    for _, part in ipairs(Medical.fractureParts) do
        if snapshot.parts[part].fracture == 'suppressed' then ordered[#ordered + 1] = part end
    end
    for _, part in ipairs(ordered) do
        local status = snapshot.parts[part].fracture
        if status then
            if status == 'suppressed' then
                ownDamage(Config.Wounds.ActionDamage)
                C.send(part, 'blunt', Config.Wounds.ActionDamage)
            else
                if not CanPedRagdoll(ped) then return end
                local duration = Config.Fracture.RagdollDuration
                SetPedToRagdoll(ped, duration, duration, 0, false, false, false)
            end
            nextAction, wasAction = now + Config.Fracture.RagdollCooldown, true
            return
        end
    end
end

RegisterNetEvent('ptech_mediora_medical:wounds', function(result)
    if source == 65535 then C.apply(result) end
end)
local body = { head = '頭部', upper_body = '上半身', lower_body = '下半身', left_arm = '左腕', right_arm = '右腕', left_leg = '左脚', right_leg = '右脚' }
RegisterNetEvent('ptech_mediora_medical:symptom', function(data)
    if source ~= 65535 or type(data) ~= 'table' or not body[data.part] then return end
    local message = { bruise = 'に鈍い痛みを感じる..', fracture = 'の骨が折れてしまったようだ..', bleeding = 'から血が出ているようだ..',
        fractureRelapse = 'の骨折が再度悪化してしまったようだ..', bleedingRelapse = 'の出血が再度悪化してしまったようだ..',
        fractureSuppressed = 'の骨折の症状が緩和された..', bleedingSuppressed = 'の出血の症状が緩和された..' }
    if message[data.symptom] then lib.notify({ title = '負傷', description = body[data.part] .. message[data.symptom], type = 'error' }) end
end)
local testWounds = {
    { value = 'blunt:light', label = '軽度の打ち身' },
    { value = 'blunt:heavy', label = '重度の打ち身' },
    { value = 'bruise:light', label = '軽度の打撲' },
    { value = 'bruise:heavy', label = '重度の打撲' },
    { value = 'cut:light', label = '軽度の切り傷' },
    { value = 'cut:heavy', label = '重度の切り傷' },
    { value = 'shot', label = '銃創' },
    { value = 'burn', label = '火傷' },
    { value = 'pin', label = '通電ピン' },
    { value = 'fracture:active', label = '骨折' },
    { value = 'fracture:suppressed', label = '骨折（緩和中）' },
    { value = 'bleeding:active', label = '出血' },
    { value = 'bleeding:suppressed', label = '出血（緩和中）' },
}

RegisterNetEvent('ptech_mediora_medical:openTestSettings', function(name)
    if source ~= 65535 then return end
    local target = { type = 'number', label = '対象のサーバーID', required = true, min = 1, precision = 0 }
    if name == 'medinjury' then
        local parts = {}
        for _, part in ipairs(W.parts) do parts[#parts + 1] = { value = part, label = body[part] } end
        local values = lib.inputDialog('Medical テスト · 負傷設定', {
            target,
            { type = 'select', label = '負傷部位', options = parts, required = true },
            { type = 'select', label = '傷と重さ・状態', options = testWounds, required = true },
        })
        if not values then return end
        local kind, level = values[3]:match('^([a-z]+):?([a-z]*)$')
        if not kind then return end
        TriggerServerEvent('ptech_mediora_medical:applyTestSettings', name,
            { tostring(values[1]), values[2], kind, level ~= '' and level or nil })
    elseif name == 'meddamage' then
        local values = lib.inputDialog('Medical テスト · HPダメージ', {
            target,
            { type = 'number', label = '減らすHP', required = true, min = 1, precision = 0 },
        })
        if values then
            TriggerServerEvent('ptech_mediora_medical:applyTestSettings', name, { tostring(values[1]), tostring(values[2]) })
        end
    end
end)

RegisterNetEvent('ptech_mediora_medical:damageTest', function(id, amount)
    if source ~= 65535 or type(id) ~= 'string' or identity() ~= id or not Medical.validId(amount) then return end
    local ped = PlayerPedId()
    if ped == 0 then return end
    applying = true
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - amount))
    applying = false
    lastHealth = GetEntityHealth(ped)
end)

RegisterNetEvent('ptech_mediora_medical:starvationTest', function(id)
    if source ~= 65535 or type(id) ~= 'string' or identity() ~= id then return end
    local ped = PlayerPedId()
    if ped ~= 0 then SetEntityHealth(ped, 0) end
end)

RegisterNetEvent('ptech_mediora_medical:health', function(percent, id)
    if source ~= 65535 or identity() ~= id or not W.finite(percent) or percent <= 0 or percent > 100 or not alive() then return end
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + math.ceil(healthRange(ped) * percent / 100)))
    lastHealth = GetEntityHealth(ped)
end)

-- 独自スライディングリソースから開始・終了を通知するクライアントexport。
-- GTAに存在しない追加アクションを入力キーだけから推定しない。
exports('setMedicalSliding', function(active) C.sliding = active == true end)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() suspended = false; reset() end)
AddEventHandler('QBCore:Client:OnPlayerUnload', function() suspended = true; reset() end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then suspended = true; reset() end end)
CreateThread(function()
    while true do C.refresh(); Wait(Config.Fracture.ObserveInterval) end
end)
CreateThread(function()
    while true do
        C.step()
        local ped = PlayerPedId()
        if ped ~= lastPed then lastPed, lastHealth = ped, GetEntityHealth(ped)
        elseif token then lastHealth = GetEntityHealth(ped) end
        Wait(Config.Wounds.SampleInterval)
    end
end)
