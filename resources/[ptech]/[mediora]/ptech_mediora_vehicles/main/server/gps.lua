local function buildTrackedVehicles()
    local vehicles = {}

    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) then
            local config = Config.VehicleModelsByHash[GetEntityModel(vehicle)]
            if config and config.gps then
                vehicles[#vehicles + 1] = {
                    netId = NetworkGetNetworkIdFromEntity(vehicle),
                    coords = GetEntityCoords(vehicle),
                    heading = GetEntityHeading(vehicle),
                    label = config.label or 'EMS車両',
                    entity = vehicle,
                }
            end
        end
    end

    return vehicles
end

CreateThread(function()
    while true do
        local vehicles = buildTrackedVehicles()

        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            local keyedVehicles = {}

            for _, vehicleData in ipairs(vehicles) do
                if exports.qbx_vehiclekeys:HasKeys(source, vehicleData.entity) then
                    keyedVehicles[#keyedVehicles + 1] = {
                        netId = vehicleData.netId,
                        coords = vehicleData.coords,
                        heading = vehicleData.heading,
                        label = vehicleData.label,
                    }
                end
            end

            TriggerClientEvent('ptech_mediora_vehicles:client:updateGps', source, keyedVehicles)
        end

        Wait(Config.GpsIntervalMs)
    end
end)
