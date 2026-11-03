local trips = {}
local lastMaintenanceActivity = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function isMedicalEmployee(source)
    local player = getPlayer(source)
    return player and player.PlayerData and player.PlayerData.job
        and player.PlayerData.job.name == Config.Job
end

local function validVehicle(source, netId)
    if type(netId) ~= 'number' or netId < 1 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local config = Config.VehicleModelsByHash[GetEntityModel(vehicle)]
    if not config or not config.trackMaintenance then return nil end
    if not exports.qbx_vehiclekeys:HasKeys(source, vehicle) then return nil end
    if GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(vehicle) then return nil end
    return vehicle
end

local function isClosestKeyholder(source, vehicle)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleBucket = GetEntityRoutingBucket(vehicle)
    local closestSource, closestDistance

    for _, playerId in ipairs(GetPlayers()) do
        local candidate = tonumber(playerId)
        local ped = GetPlayerPed(candidate)
        if ped and ped ~= 0 and isMedicalEmployee(candidate)
            and GetPlayerRoutingBucket(candidate) == vehicleBucket
            and exports.qbx_vehiclekeys:HasKeys(candidate, vehicle) then
            local distance = #(GetEntityCoords(ped) - vehicleCoords)
            if distance <= 7.5 and (not closestDistance or distance < closestDistance
                or (distance == closestDistance and candidate < closestSource)) then
                closestSource = candidate
                closestDistance = distance
            end
        end
    end

    return closestSource == source
end

local function emitActivity(source, activityType, amount, plate, unit)
    local player = getPlayer(source)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid
    if not citizenid then return end

    TriggerEvent('ptech_mediora_vehicles:server:activity', source, {
        type = activityType,
        citizenid = citizenid,
        plate = plate,
        amount = amount,
        unit = unit,
        timestamp = os.time(),
    })
end

RegisterNetEvent('ptech_mediora_vehicles:server:startTrip', function(netId)
    local source = source
    if not isMedicalEmployee(source) then return end
    local vehicle = validVehicle(source, netId)
    if not vehicle or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return end

    trips[source] = {
        netId = netId,
        entity = vehicle,
        plate = GetVehicleNumberPlateText(vehicle),
        startedAt = os.time(),
    }
end)

RegisterNetEvent('ptech_mediora_vehicles:server:stopTrip', function(netId, distance)
    local source = source
    local trip = trips[source]
    trips[source] = nil

    if not isMedicalEmployee(source) or not trip or trip.netId ~= netId
        or type(distance) ~= 'number' or distance < 0 or distance > 100000 then return end

    local elapsed = math.max(1, os.time() - trip.startedAt)
    if distance > elapsed * 100 then return end
    if not trip.entity or not DoesEntityExist(trip.entity)
        or not exports.qbx_vehiclekeys:HasKeys(source, trip.entity) then return end

    if distance >= 10 then
        emitActivity(source, 'vehicle_drive_meters', math.floor(distance), trip.plate, 'm')
    end
end)

RegisterNetEvent('ptech_mediora_vehicles:server:maintenanceActivity', function(netId, kind, amount)
    local source = source
    if not isMedicalEmployee(source) or (kind ~= 'fuel' and kind ~= 'repair')
        or type(amount) ~= 'number' or amount <= 0 or amount > 1000 then return end

    local vehicle = validVehicle(source, netId)
    if not vehicle then return end
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 7.5 then return end
    if not isClosestKeyholder(source, vehicle) then return end

    local key = ('%s:%s'):format(netId, kind)
    local now = GetGameTimer()
    if lastMaintenanceActivity[key] and now - lastMaintenanceActivity[key] < 5000 then return end
    lastMaintenanceActivity[key] = now

    local activityType = kind == 'fuel' and 'vehicle_fuel_added' or 'vehicle_repaired'
    local unit = kind == 'fuel' and 'percent' or 'health_points'
    emitActivity(source, activityType, math.floor(amount * 10) / 10, GetVehicleNumberPlateText(vehicle), unit)
end)

AddEventHandler('playerDropped', function()
    trips[source] = nil
end)
