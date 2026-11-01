local carrierConfigs = {}
local deployedByCarrier = {}

for assetId, vehicleConfig in pairs(VehicleAssets) do
    local callout = vehicleConfig.Callout
    if callout then
        for _, modelName in ipairs(callout.CarrierModels or {}) do
            carrierConfigs[joaat(modelName)] = { assetId = assetId, vehicle = vehicleConfig, callout = callout }
        end
    end
end

local function notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = message, type = kind or 'inform' })
end

local function playerNearVehicle(src, vehicle, maxDistance)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and DoesEntityExist(ped)
        and #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= maxDistance
end

local function hasKeys(src, vehicle)
    return GetResourceState('qbx_vehiclekeys') == 'started'
        and exports.qbx_vehiclekeys:HasKeys(src, vehicle) == true
end

local function sendState(src, carrierNetId)
    local deployed = deployedByCarrier[carrierNetId]
    local deployedNetId = deployed and DoesEntityExist(deployed) and NetworkGetNetworkIdFromEntity(deployed) or nil
    TriggerClientEvent('ptech_mediora_vehicles:client:setCalloutState', src, carrierNetId, deployedNetId)
end

RegisterNetEvent('ptech_mediora_vehicles:server:deployCallout', function(carrierNetId)
    local src = source
    if type(carrierNetId) ~= 'number' then return end
    local carrier = NetworkGetEntityFromNetworkId(carrierNetId)
    if carrier == 0 or not DoesEntityExist(carrier) then return end

    local registration = carrierConfigs[GetEntityModel(carrier)]
    if not registration or not hasKeys(src, carrier) then return end
    if GetEntityRoutingBucket(carrier) ~= GetPlayerRoutingBucket(src) then return end
    if not playerNearVehicle(src, carrier, MedioraVehicles.Callout.ServerDistance) then return end

    local existing = deployedByCarrier[carrierNetId]
    if existing and DoesEntityExist(existing) then
        sendState(src, carrierNetId)
        return
    end
    deployedByCarrier[carrierNetId] = nil

    local callout = registration.callout
    local modelName = registration.vehicle.Models[1]
    local modelHash = joaat(modelName)
    local offset = callout.SpawnOffset or vector3(0.0, -4.8, 0.2)
    local spawn = GetOffsetFromEntityInWorldCoords(carrier, offset.x, offset.y, offset.z)
    local heading = GetEntityHeading(carrier) + (callout.SpawnHeadingOffset or 180.0)

    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, MedioraVehicles.Callout.SpawnClearance) then
        notify(src, '後方に車両を展開するスペースがありません。', 'error')
        return
    end

    local deployed = CreateVehicleServerSetter(modelHash, callout.ModelType or 'bike',
        spawn.x, spawn.y, spawn.z, heading)
    if deployed == 0 or not DoesEntityExist(deployed) then
        notify(src, '車両を展開できませんでした。', 'error')
        return
    end

    SetEntityRoutingBucket(deployed, GetPlayerRoutingBucket(src))
    SetEntityOrphanMode(deployed, 2)
    exports.qbx_vehiclekeys:GiveKeys(src, deployed, true)
    if not hasKeys(src, deployed) then
        DeleteEntity(deployed)
        notify(src, '車両キーを渡せなかったため、展開を取り消しました。', 'error')
        return
    end

    deployedByCarrier[carrierNetId] = deployed
    local deployedNetId = NetworkGetNetworkIdFromEntity(deployed)
    TriggerClientEvent('ptech_mediora_vehicles:client:setCalloutState', -1, carrierNetId, deployedNetId)
    notify(src, 'EMSブレイザーを展開しました。')
end)

RegisterNetEvent('ptech_mediora_vehicles:server:storeCallout', function(carrierNetId, deployedNetId)
    local src = source
    if type(carrierNetId) ~= 'number' or type(deployedNetId) ~= 'number' then return end
    local carrier = NetworkGetEntityFromNetworkId(carrierNetId)
    local deployed = NetworkGetEntityFromNetworkId(deployedNetId)
    if carrier == 0 or deployed == 0 or not DoesEntityExist(carrier) or not DoesEntityExist(deployed) then return end
    if not carrierConfigs[GetEntityModel(carrier)] or not hasKeys(src, carrier) then return end
    if GetEntityRoutingBucket(carrier) ~= GetPlayerRoutingBucket(src)
        or GetEntityRoutingBucket(deployed) ~= GetPlayerRoutingBucket(src) then return end
    if not playerNearVehicle(src, carrier, MedioraVehicles.Callout.ServerDistance) then return end
    if deployedByCarrier[carrierNetId] ~= deployed then return end

    local playerPed = GetPlayerPed(src)
    if #(GetEntityCoords(playerPed) - GetEntityCoords(deployed)) > MedioraVehicles.Callout.ServerDistance then return end
    for _, seatPed in ipairs({ GetPedInVehicleSeat(deployed, -1), GetPedInVehicleSeat(deployed, 0) }) do
        if seatPed ~= 0 then
            notify(src, '乗員がいる車両は格納できません。', 'error')
            return
        end
    end

    DeleteEntity(deployed)
    deployedByCarrier[carrierNetId] = nil
    TriggerClientEvent('ptech_mediora_vehicles:client:setCalloutState', -1, carrierNetId, nil)
    notify(src, 'EMSブレイザーを格納しました。')
end)

RegisterNetEvent('ptech_mediora_vehicles:server:requestCalloutState', function()
    local src = source
    for carrierNetId, deployed in pairs(deployedByCarrier) do
        if DoesEntityExist(deployed) then sendState(src, carrierNetId) end
    end
end)

