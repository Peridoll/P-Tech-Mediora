local accessByModel = {}
local requestCooldowns = {}

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

RegisterNetEvent('ptech_mediora_vehicles:server:requestDriverKey', function(netId)
    local src = source
    if type(netId) ~= 'number' or netId <= 0 then return end
    local now = GetGameTimer()
    if requestCooldowns[src] and now - requestCooldowns[src] < 2000 then return end
    requestCooldowns[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local access = accessByModel[GetEntityModel(vehicle)]
    if not access then return end

    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData and player.PlayerData.job
    if access.Job and (not job or job.name ~= access.Job) then return end
    if access.RequireDuty and (not job or job.onduty ~= true) then return end

    exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    if exports.qbx_vehiclekeys:HasKeys(src, vehicle) then
        TriggerClientEvent('ox_lib:notify', src, {
            description = '車両キーを受け取りました。',
            type = 'success',
        })
    end
end)

AddEventHandler('playerDropped', function()
    requestCooldowns[source] = nil
end)
