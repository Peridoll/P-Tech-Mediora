MedicalFractureClient = {}
local citizenId, revision = nil, -1
local fractures, generation, nextTrip, wasAction = {}, 0, 0, false
local suspended = false

local function reset()
    citizenId, revision, fractures = nil, -1, {}
    generation, nextTrip, wasAction = generation + 1, 0, false
end

local function current(id, request)
    local data = exports.qbx_core:GetPlayerData()
    return not suspended and generation == request and data and data.citizenid == id
end

function MedicalFractureClient.apply(result)
    if type(result) ~= 'table' or type(result.parts) ~= 'table' or result.citizenId ~= citizenId
        or type(result.revision) ~= 'number' or result.revision % 1 ~= 0 or result.revision < revision then return false end
    if not current(citizenId, generation) then return false end
    local parts = {}
    for _, part in ipairs(Medical.fractureParts) do
        local severity = result.parts[part]
        if type(severity) == 'number' and severity % 1 == 0 and severity >= 0 and severity <= 4 then
            parts[part] = severity
        end
    end
    fractures, revision = parts, result.revision
    return true
end

function MedicalFractureClient.refresh()
    if suspended then return end
    local data = exports.qbx_core:GetPlayerData()
    local id = data and data.citizenid
    if type(id) ~= 'string' or id == '' then reset(); return end
    if citizenId ~= id then
        reset()
        citizenId = id
    end
    if revision < 0 then
        local request = generation
        local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:fractures:get', false, id)
        if not current(id, request) then return end
        if ok then MedicalFractureClient.apply(result) end
    end
    if GetResourceState('wasabi_ambulance') ~= 'started' then return end
    local request = generation
    -- Wasabi v1のtrue引数は自分の負傷表を返す。UI・医療職コマンドは開かない。
    local ok, injuries = pcall(function() return exports.wasabi_ambulance:diagnosePlayer(true) end)
    if not current(id, request) or not ok or type(injuries) ~= 'table' then return end
    local report = Medical.report(injuries, true)
    if next(injuries) ~= nil and #report.rows == 0 then return end
    -- 観察対象の7部位だけを送る。未知の形式は回復として送信しない。
    local observation = {}
    for _, row in ipairs(report.rows) do
        observation[row.part] = { type = row.kind, data = {level = row.severity, bleed = row.bleed} }
    end
    local synced, result = pcall(lib.callback.await, 'ptech_mediora_medical:fractures:observe', false, id, observation, true)
    if synced and current(id, request) then MedicalFractureClient.apply(result) end
end

function MedicalFractureClient.step()
    if suspended then return 500 end
    local data = exports.qbx_core:GetPlayerData()
    if not data or data.citizenid ~= citizenId then reset(); return 500 end
    if next(fractures) == nil then wasAction = false; return 500 end
    local ped = PlayerPedId()
    local death = Medical.death(LocalPlayer and LocalPlayer.state.dead, data.metadata)
    if ped == 0 or GetEntityHealth(ped) <= 0 or IsPedDeadOrDying(ped, true)
        or death == '死亡' or death == '瀕死（laststand）'
        or IsPedInAnyVehicle(ped, true) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
        or IsEntityAttached(ped) then
        wasAction = false
        return 100
    end
    local action = IsPedJumping(ped) or IsPedClimbing(ped) or IsPedVaulting(ped)
    if not action then wasAction = false; return 50 end
    if not wasAction then
        if IsPedRagdoll(ped) then wasAction = true; return 50 end
        -- 登り動作中など一時的に転倒できない場合、同じ動作中は次の確認で再試行する。
        if not CanPedRagdoll(ped) then return 50 end
        if GetGameTimer() >= nextTrip then
            local duration = Config.Fracture.RagdollDuration
            SetPedToRagdoll(ped, duration, duration, 0, false, false, false)
            nextTrip = GetGameTimer() + Config.Fracture.RagdollCooldown
        end
    end
    wasAction = true
    return 50
end

RegisterNetEvent('ptech_mediora_medical:fractures', function(result)
    if source == 65535 then MedicalFractureClient.apply(result) end
end)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() suspended = false; reset() end)
AddEventHandler('QBCore:Client:OnPlayerUnload', function() suspended = true; reset() end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then suspended = true; reset() end
end)

CreateThread(function()
    while true do
        MedicalFractureClient.refresh()
        Wait(Config.Fracture.ObserveInterval)
    end
end)
CreateThread(function()
    while true do Wait(MedicalFractureClient.step()) end
end)
