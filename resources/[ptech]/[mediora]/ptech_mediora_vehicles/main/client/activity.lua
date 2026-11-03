local activeTrip
local maintenanceSamples = {}

local function getFuel(vehicle)
    if GetResourceState('lc_fuel') == 'started' then
        local ok, fuel = pcall(function()
            return exports.lc_fuel:GetFuel(vehicle)
        end)
        if ok and type(fuel) == 'number' then return fuel end
    end

    return GetVehicleFuelLevel(vehicle)
end

local function getVehicleState(vehicle)
    return {
        fuel = getFuel(vehicle),
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
    }
end

local function reportMaintenance(vehicle, modelConfig, current)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId < 1 then return end

    local sample = maintenanceSamples[netId]
    if not sample or sample.entity ~= vehicle then
        current.entity = vehicle
        maintenanceSamples[netId] = current
        return
    end

    local fuelAdded = current.fuel - sample.fuel
    if fuelAdded >= (modelConfig.minimumFuelIncrease or 1.0) then
        TriggerServerEvent('ptech_mediora_vehicles:server:maintenanceActivity', netId, 'fuel', fuelAdded)
    end

    local repairAmount = math.max(0.0, current.engine - sample.engine)
        + math.max(0.0, current.body - sample.body)
    if repairAmount >= (modelConfig.minimumRepairIncrease or 50.0) then
        TriggerServerEvent('ptech_mediora_vehicles:server:maintenanceActivity', netId, 'repair', repairAmount)
    end

    current.entity = vehicle
    maintenanceSamples[netId] = current
end

CreateThread(function()
    local lastTripSampleAt = 0
    local lastMaintenanceSampleAt = 0
    while true do
        local ped = cache.ped or PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local config = isDriver and Config.VehicleModelsByHash[GetEntityModel(vehicle)] or nil

        if config then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if not activeTrip or activeTrip.netId ~= netId then
                if activeTrip then
                    TriggerServerEvent('ptech_mediora_vehicles:server:stopTrip', activeTrip.netId, activeTrip.distance)
                end
                activeTrip = {
                    netId = netId,
                    lastCoords = GetEntityCoords(vehicle),
                    distance = 0.0,
                }
                TriggerServerEvent('ptech_mediora_vehicles:server:startTrip', netId)
            end

            local now = GetGameTimer()
            if now - lastTripSampleAt >= 1000 then
                local coords = GetEntityCoords(vehicle)
                activeTrip.distance = activeTrip.distance + #(coords - activeTrip.lastCoords)
                activeTrip.lastCoords = coords
                lastTripSampleAt = now
            end
        elseif activeTrip then
            TriggerServerEvent('ptech_mediora_vehicles:server:stopTrip', activeTrip.netId, activeTrip.distance)
            activeTrip = nil
        end

        if GetGameTimer() - lastMaintenanceSampleAt >= 1000 then
            local playerCoords = GetEntityCoords(ped)
            for _, nearbyVehicle in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(nearbyVehicle) then
                    local modelConfig = Config.VehicleModelsByHash[GetEntityModel(nearbyVehicle)]
                    if modelConfig and modelConfig.trackMaintenance
                        and #(GetEntityCoords(nearbyVehicle) - playerCoords) <= 6.0 then
                        reportMaintenance(nearbyVehicle, modelConfig, getVehicleState(nearbyVehicle))
                    end
                end
            end
            lastMaintenanceSampleAt = GetGameTimer()
        end

        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if activeTrip then
        TriggerServerEvent('ptech_mediora_vehicles:server:stopTrip', activeTrip.netId, activeTrip.distance)
        activeTrip = nil
    end
end)
