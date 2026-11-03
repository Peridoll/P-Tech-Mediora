local vehicleConfigs = {}
local states = {}

for modelName, vehicleConfig in pairs(Config.Vehicles) do
    if vehicleConfig.mooring and vehicleConfig.mooring.enabled then
        vehicleConfigs[joaat(modelName)] = vehicleConfig.mooring
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

local function horizontalVelocityChange(first, second)
    local x = first.x - second.x
    local y = first.y - second.y
    return math.sqrt((x * x) + (y * y))
end

local function updateMooring(vehicle, config, now)
    local position = GetEntityCoords(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local speed = horizontalSpeed(velocity)
    local state = states[vehicle]

    if hasOccupant(vehicle) then
        state = state or {}
        state.wasOccupied = true
        state.lastPosition = position
        state.lastSpeed = speed
        state.lastVelocity = velocity
        states[vehicle] = state
        return
    end

    if not state then
        state = { armedAt = now, lastPosition = position, lastSpeed = speed }
        states[vehicle] = state
    end

    if state.wasOccupied then
        state.wasOccupied = nil
        state.armedAt = now
        state.exitDampingUntil = now + config.exitDampingMs
    end

    local moved = horizontalDistance(position, state.lastPosition or position)
    local speedDelta = math.abs(speed - (state.lastSpeed or speed))
    local velocityChange = state.lastVelocity and horizontalVelocityChange(velocity, state.lastVelocity) or 0.0
    state.lastPosition = position
    state.lastSpeed = speed
    state.lastVelocity = velocity

    if not hasPhysicsControl(vehicle) then
        return
    end

    if state.exitDampingUntil and now < state.exitDampingUntil then
        if speedDelta >= config.collisionSpeedDeltaMps or velocityChange >= config.collisionImpulseMps then
            state.exitDampingUntil = nil
            state.releaseUntil = now + config.releaseCooldownMs
            return
        end

        SetEntityVelocity(
            vehicle,
            velocity.x * config.exitVelocityMultiplier,
            velocity.y * config.exitVelocityMultiplier,
            velocity.z
        )
        return
    end

    if config.onlyWhenInWater and not IsEntityInWater(vehicle) then
        state.armedAt = now
        return
    end

    -- 強い衝突や押し出しが起きた車両には一切の減衰をかけず、自由に動かす。
    if speed >= config.releaseSpeedMps or moved >= config.releaseDistanceM then
        state.armedAt = nil
        state.releaseUntil = now + config.releaseCooldownMs
        return
    end

    if state.releaseUntil then
        if now < state.releaseUntil then
            return
        end

        state.releaseUntil = nil
        state.armedAt = now
    end

    if speed > config.passiveDriftSpeedMps then
        state.armedAt = now
        return
    end

    if now - state.armedAt < config.armDelayMs then
        return
    end

    if config.engineStopWhenMoored and GetIsVehicleEngineRunning(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
    end

    -- Z速度は保ち、水上の浮力・沈み込みには干渉しない。座標固定や衝突設定の変更もしない。
    SetEntityVelocity(
        vehicle,
        velocity.x * config.passiveVelocityMultiplier,
        velocity.y * config.passiveVelocityMultiplier,
        velocity.z
    )
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
                shortestInterval = math.min(shortestInterval, config.scanIntervalMs)
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
