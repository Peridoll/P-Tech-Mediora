local lastVehicle = 0
local requestedVehicle = 0
local accessByModel = {}

for modelName, access in pairs(MedioraVehicles.KeyAccess or {}) do
    accessByModel[joaat(modelName)] = access
end
for _, asset in pairs(VehicleAssets) do
    if asset.KeyAccess then
        for _, modelName in ipairs(asset.Models or {}) do
            accessByModel[joaat(modelName)] = asset.KeyAccess
        end
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        if isDriver and vehicle ~= lastVehicle then
            requestedVehicle = 0
        end

        if isDriver and vehicle ~= requestedVehicle then
            local model = GetEntityModel(vehicle)
            local access = accessByModel[model]

            if access and not exports.qbx_vehiclekeys:HasKeys(vehicle) then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and netId ~= 0 then
                    TriggerServerEvent('ptech_mediora_vehicles:server:requestDriverKey', netId)
                    requestedVehicle = vehicle
                end
            else
                requestedVehicle = vehicle
            end
        elseif not isDriver then
            requestedVehicle = 0
        end

        lastVehicle = isDriver and vehicle or 0
        Wait(250)
    end
end)
