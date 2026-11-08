local trackedModels = {}

for modelName, blip in pairs(MedioraVehicles.GPS.Blips or {}) do
    trackedModels[joaat(modelName)] = blip
end
for _, asset in pairs(VehicleAssets) do
    for _, modelName in ipairs(asset.Models or {}) do
        if asset.GPS and asset.GPS.Blip then
            trackedModels[joaat(modelName)] = asset.GPS.Blip
        end
    end
end

local function hasKeys(src, vehicle)
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false end
    local ok, result = pcall(function()
        return exports.qbx_vehiclekeys:HasKeys(src, vehicle)
    end)
    return ok and result == true
end

CreateThread(function()
    while true do
        local vehicles = {}
        for _, vehicle in ipairs(GetAllVehicles()) do
            local blip = trackedModels[GetEntityModel(vehicle)]
            if blip then
                local coords = GetEntityCoords(vehicle)
                vehicles[#vehicles + 1] = {
                    netId = NetworkGetNetworkIdFromEntity(vehicle),
                    model = GetEntityModel(vehicle),
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    label = blip.label,
                    sprite = blip.sprite,
                    color = blip.color,
                    scale = blip.scale,
                }
            end
        end

        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local ped = src and GetPlayerPed(src) or 0
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                local visible = {}
                for _, info in ipairs(vehicles) do
                    local vehicle = NetworkGetEntityFromNetworkId(info.netId)
                    if vehicle ~= 0 and hasKeys(src, vehicle) then
                        local dx, dy, dz = info.x - playerCoords.x, info.y - playerCoords.y, info.z - playerCoords.z
                        if (dx * dx + dy * dy + dz * dz) <= (MedioraVehicles.GPS.VisibleDistance ^ 2) then
                            visible[#visible + 1] = info
                        end
                    end
                end
                TriggerClientEvent('ptech_mediora_vehicles:client:updateGps', src, visible)
            end
        end
        Wait(MedioraVehicles.GPS.UpdateIntervalMs)
    end
end)
