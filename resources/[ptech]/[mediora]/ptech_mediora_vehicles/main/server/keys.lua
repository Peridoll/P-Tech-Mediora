local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function isMedicalEmployee(source)
    local player = getPlayer(source)
    return player and player.PlayerData and player.PlayerData.job
        and player.PlayerData.job.name == Config.Job
end

RegisterNetEvent('ptech_mediora_vehicles:server:requestKeys', function(netId)
    local source = source
    if type(netId) ~= 'number' or netId < 1 or not isMedicalEmployee(source) then
        TriggerClientEvent('ptech_mediora_vehicles:client:keysDenied', source)
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(source)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerClientEvent('ptech_mediora_vehicles:client:keysDenied', source)
        return
    end

    local modelConfig = Config.VehicleModelsByHash[GetEntityModel(vehicle)]
    if not modelConfig or not modelConfig.autoKeys
        or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TriggerClientEvent('ptech_mediora_vehicles:client:keysDenied', source)
        return
    end

    if exports.qbx_vehiclekeys:HasKeys(source, vehicle) then
        TriggerClientEvent('ptech_mediora_vehicles:client:keysGranted', source, netId)
        return
    end

    local ok = pcall(function()
        exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
    end)
    if ok and exports.qbx_vehiclekeys:HasKeys(source, vehicle) then
        TriggerClientEvent('ptech_mediora_vehicles:client:keysGranted', source, netId)
        return
    end

    TriggerClientEvent('ptech_mediora_vehicles:client:keysDenied', source)
end)
