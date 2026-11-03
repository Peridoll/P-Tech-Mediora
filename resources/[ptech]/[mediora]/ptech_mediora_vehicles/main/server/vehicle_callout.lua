local deployedByCarrier = {}

local function notify(source, success, message)
    TriggerClientEvent('ptech_mediora_vehicles:client:calloutResult', source, success, message)
end

local function isMedicalEmployee(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData and player.PlayerData.job
        and player.PlayerData.job.name == Config.Job
end

local function getCalloutForCarrier(modelHash)
    local configurations = Config.CalloutCarriers[modelHash]
    return configurations and configurations[1]
end

local function getCarrier(source, netId)
    if type(netId) ~= 'number' or netId < 1 then return nil end
    local carrier = NetworkGetEntityFromNetworkId(netId)
    if carrier == 0 or not DoesEntityExist(carrier) then return nil end

    local callout = getCalloutForCarrier(GetEntityModel(carrier))
    if not callout then return nil end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(carrier)) > callout.maxDistance then
        return nil
    end

    if not exports.qbx_vehiclekeys:HasKeys(source, carrier) then return nil end
    return carrier, callout
end

local function broadcastState(carrierNetId, blazerNetId)
    TriggerClientEvent('ptech_mediora_vehicles:client:calloutState', -1, carrierNetId, blazerNetId)
end

local function registerWithAdvancedGarages(vehicle, netId)
    if GetResourceState('jg-advancedgarages') ~= 'started' then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    if type(plate) ~= 'string' or plate:gsub('%s+', '') == '' then return end

    pcall(function()
        exports['jg-advancedgarages']:registerVehicleOutside(plate, netId)
    end)
end

local function unregisterWithAdvancedGarages(vehicle)
    if GetResourceState('jg-advancedgarages') ~= 'started' then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    if type(plate) ~= 'string' or plate:gsub('%s+', '') == '' then return end

    pcall(function()
        exports['jg-advancedgarages']:deleteOutsideVehicle(plate)
    end)
end

local function getRearSpawnCoords(vehicle, offset)
    local coords = GetEntityCoords(vehicle)
    local heading = math.rad(GetEntityHeading(vehicle))
    local cosine, sine = math.cos(heading), math.sin(heading)

    return {
        x = coords.x + offset.x * cosine - offset.y * sine,
        y = coords.y + offset.x * sine + offset.y * cosine,
        z = coords.z + offset.z,
    }
end

RegisterNetEvent('ptech_mediora_vehicles:server:requestCalloutState', function()
    local source = source
    for carrierNetId, deployed in pairs(deployedByCarrier) do
        if DoesEntityExist(deployed.entity) then
            TriggerClientEvent('ptech_mediora_vehicles:client:calloutState', source, carrierNetId, deployed.netId)
        else
            deployedByCarrier[carrierNetId] = nil
            broadcastState(carrierNetId, nil)
        end
    end
end)

RegisterNetEvent('ptech_mediora_vehicles:server:callout', function(action, carrierNetId)
    local source = source
    if not isMedicalEmployee(source) then
        notify(source, false, 'EMS勤務者のみ利用できます。')
        return
    end

    local carrier, callout = getCarrier(source, carrierNetId)
    if not carrier then
        notify(source, false, '対象車両の後部で、車両キーを持っていることを確認してください。')
        return
    end

    if action == 'deploy' then
        if deployedByCarrier[carrierNetId] then
            notify(source, false, 'この車両からはすでにブレイザーが出ています。')
            return
        end

        local model = joaat(callout.spawnedModel)
        local offset = callout.rearOffset
        local spawn = getRearSpawnCoords(carrier, offset)
        local vehicle = CreateVehicleServerSetter(
            model,
            callout.vehicleType,
            spawn.x,
            spawn.y,
            spawn.z,
            GetEntityHeading(carrier)
        )

        if vehicle == 0 or not DoesEntityExist(vehicle) then
            notify(source, false, 'ブレイザーを出せませんでした。')
            return
        end

        SetEntityRoutingBucket(vehicle, GetPlayerRoutingBucket(source))
        local blazerNetId = NetworkGetNetworkIdFromEntity(vehicle)
        if not blazerNetId or blazerNetId < 1 then
            DeleteEntity(vehicle)
            notify(source, false, '車両ネットワークIDを取得できませんでした。')
            return
        end

        registerWithAdvancedGarages(vehicle, blazerNetId)
        Entity(vehicle).state:set('ptech_mediora_vehicles:carrierNetId', carrierNetId, true)
        deployedByCarrier[carrierNetId] = { entity = vehicle, netId = blazerNetId }
        local keysOk = pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
        end)
        if not keysOk or not exports.qbx_vehiclekeys:HasKeys(source, vehicle) then
            unregisterWithAdvancedGarages(vehicle)
            DeleteEntity(vehicle)
            deployedByCarrier[carrierNetId] = nil
            notify(source, false, 'ブレイザーのキーを渡せなかったため、呼び出しを取り消しました。')
            return
        end
        broadcastState(carrierNetId, blazerNetId)
        notify(source, true, 'ブレイザーを呼び出しました。')
        return
    end

    if action == 'store' then
        local deployed = deployedByCarrier[carrierNetId]
        if not deployed or not DoesEntityExist(deployed.entity) then
            deployedByCarrier[carrierNetId] = nil
            broadcastState(carrierNetId, nil)
            notify(source, false, '格納できるブレイザーがありません。')
            return
        end

        unregisterWithAdvancedGarages(deployed.entity)
        DeleteEntity(deployed.entity)
        deployedByCarrier[carrierNetId] = nil
        broadcastState(carrierNetId, nil)
        notify(source, true, 'ブレイザーを格納しました。')
        return
    end

    notify(source, false, '操作を認識できませんでした。')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for carrierNetId, deployed in pairs(deployedByCarrier) do
        if DoesEntityExist(deployed.entity) then
            unregisterWithAdvancedGarages(deployed.entity)
            DeleteEntity(deployed.entity)
        end
        deployedByCarrier[carrierNetId] = nil
    end
end)
