local lastVehicle = 0
local requesting = false

CreateThread(function()
    while true do
        local ped = cache.ped or PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local shouldRequest = vehicle ~= 0
            and GetPedInVehicleSeat(vehicle, -1) == ped
            and Config.VehicleModelsByHash[GetEntityModel(vehicle)]
            and Config.VehicleModelsByHash[GetEntityModel(vehicle)].autoKeys

        if not shouldRequest then
            lastVehicle = 0
            requesting = false
        elseif vehicle ~= lastVehicle and not requesting then
            lastVehicle = vehicle
            requesting = true
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if netId and netId > 0 then
                TriggerServerEvent('ptech_mediora_vehicles:server:requestKeys', netId)
            else
                requesting = false
            end
        end

        Wait(500)
    end
end)

RegisterNetEvent('ptech_mediora_vehicles:client:keysGranted', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        lib.notify({ description = '車両キーを受け取りました。', type = 'success' })
    end
    requesting = false
end)

RegisterNetEvent('ptech_mediora_vehicles:client:keysDenied', function()
    requesting = false
end)
