local vehicleConfigs = {}
local states = {}

for _, vehicleConfig in pairs(VehicleAssets) do
    for _, modelName in ipairs(vehicleConfig.Models or {}) do
        if vehicleConfig.Mooring and vehicleConfig.Mooring.Enabled then
            vehicleConfigs[joaat(modelName)] = vehicleConfig.Mooring
        end
    end
end

local function hasOccupant(vehicle)
    if GetPedInVehicleSeat(vehicle, -1) ~= 0 then
        return true
    end

    for seat = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
            return true
        end
    end

    return false
end

local function hasPhysicsControl(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        return true
    end

    if NetworkHasControlOfEntity(vehicle) then
        return true
    end

    NetworkRequestControlOfEntity(vehicle)
    return false
end

local function horizontalSpeed(velocity)
    return math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
end

local function horizontalDistance(first, second)
    local x = first.x - second.x
    local y = first.y - second.y
    return math.sqrt((x * x) + (y * y))
end

local function updateMooring(vehicle, config, now)
    if hasOccupant(vehicle) or (config.OnlyWhenInWater and not IsEntityInWater(vehicle)) then
        states[vehicle] = nil
        return
    end

    if not hasPhysicsControl(vehicle) then
        return
    end

    local position = GetEntityCoords(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local speed = horizontalSpeed(velocity)
    local state = states[vehicle]

    if not state then
        states[vehicle] = {
            armedAt = now,
            lastPosition = position,
        }
        return
    end

    local moved = horizontalDistance(position, state.lastPosition)
    state.lastPosition = position

    -- 強い衝突や押し出しが起きた車両には一切の減衰をかけず、自由に動かす。
    if speed >= config.ReleaseSpeedMps or moved >= config.ReleaseDistanceM then
        state.armedAt = nil
        state.releaseUntil = now + config.ReleaseCooldownMs
        return
    end

    if state.releaseUntil then
        if now < state.releaseUntil then
            return
        end

        state.releaseUntil = nil
        state.armedAt = now
    end

    if speed > config.PassiveDriftSpeedMps then
        state.armedAt = now
        return
    end

    if now - state.armedAt < config.ArmDelayMs then
        return
    end

    -- Z速度は保ち、水上の浮力・沈み込みには干渉しない。座標固定や衝突設定の変更もしない。
    SetEntityVelocity(
        vehicle,
        velocity.x * config.PassiveVelocityMultiplier,
        velocity.y * config.PassiveVelocityMultiplier,
        velocity.z
    )
    if config.StopEngineWhenMooring and speed < 0.08 and GetIsVehicleEngineRunning(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
    end
end

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local activeVehicles = {}
        local shortestInterval = 500

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            local config = vehicleConfigs[GetEntityModel(vehicle)]
            if config then
                activeVehicles[vehicle] = true
                shortestInterval = math.min(shortestInterval, config.ScanIntervalMs)
                updateMooring(vehicle, config, now)
            end
        end

        for vehicle in pairs(states) do
            if not activeVehicles[vehicle] or not DoesEntityExist(vehicle) then
                states[vehicle] = nil
            end
        end

        Wait(shortestInterval)
    end
end)

local lastVehicle = 0
local lastInVehicle = false
local dismountUntil = 0
local dampingVehicle = 0
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local inVehicle = vehicle ~= 0
        if lastInVehicle and not inVehicle and lastVehicle ~= 0 then
            local config = vehicleConfigs[GetEntityModel(lastVehicle)]
            if config and config.DismountDampingMs then
                dampingVehicle = lastVehicle
                dismountUntil = GetGameTimer() + config.DismountDampingMs
                if NetworkGetEntityIsNetworked(dampingVehicle) and not NetworkHasControlOfEntity(dampingVehicle) then
                    NetworkRequestControlOfEntity(dampingVehicle)
                end
                if NetworkHasControlOfEntity(dampingVehicle) then
                    local velocity = GetEntityVelocity(dampingVehicle)
                    SetEntityVelocity(dampingVehicle,
                        velocity.x * (config.DismountVelocityMultiplier or 0.12),
                        velocity.y * (config.DismountVelocityMultiplier or 0.12),
                        velocity.z)
                end
            end
        end
        if inVehicle then lastVehicle = vehicle end
        lastInVehicle = inVehicle
        if dismountUntil > GetGameTimer() and DoesEntityExist(dampingVehicle) then
            local config = vehicleConfigs[GetEntityModel(dampingVehicle)]
            if config and NetworkHasControlOfEntity(dampingVehicle) then
                local velocity = GetEntityVelocity(dampingVehicle)
                SetEntityVelocity(dampingVehicle,
                    velocity.x * (config.DismountVelocityMultiplier or 0.12),
                    velocity.y * (config.DismountVelocityMultiplier or 0.12),
                    velocity.z)
            end
            Wait(100)
        else
            dismountUntil = 0
            dampingVehicle = 0
            Wait(25)
        end
    end
end)
