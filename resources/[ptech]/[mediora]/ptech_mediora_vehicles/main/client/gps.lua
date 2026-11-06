local blips = {}
local keyedVehicles = {}

local function removeBlip(netId)
    local blip = blips[netId]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    blips[netId] = nil
end

RegisterNetEvent('ptech_mediora_vehicles:client:updateGps', function(vehicles)
    local nextVehicles = {}
    local currentVehicle = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
    local currentNetId = currentVehicle ~= 0 and NetworkGetNetworkIdFromEntity(currentVehicle) or 0

    for _, vehicle in ipairs(vehicles or {}) do
        local netId = tonumber(vehicle.netId)
        if netId and netId > 0 then
            nextVehicles[netId] = vehicle
            if netId == currentNetId then
                removeBlip(netId)
            else
                local blip = blips[netId]
                if not blip or not DoesBlipExist(blip) then
                    blip = AddBlipForCoord(vehicle.coords.x, vehicle.coords.y, vehicle.coords.z)
                    blips[netId] = blip
                    SetBlipSprite(blip, Config.GpsSprite)
                    SetBlipColour(blip, Config.GpsColour)
                    SetBlipScale(blip, Config.GpsScale)
                    SetBlipAsShortRange(blip, false)
                    SetBlipDisplay(blip, 4)
                else
                    SetBlipCoords(blip, vehicle.coords.x, vehicle.coords.y, vehicle.coords.z)
                end

                SetBlipRotation(blip, math.floor((vehicle.heading or 0.0) + 0.5))
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(vehicle.label or Config.GpsDisplayName)
                EndTextCommandSetBlipName(blip)
            end
        end
    end

    for netId in pairs(keyedVehicles) do
        if not nextVehicles[netId] then
            removeBlip(netId)
        end
    end

    keyedVehicles = nextVehicles
end)

CreateThread(function()
    while true do
        local currentVehicle = GetVehiclePedIsIn(cache.ped or PlayerPedId(), false)
        local currentNetId = currentVehicle ~= 0 and NetworkGetNetworkIdFromEntity(currentVehicle) or 0

        for netId, vehicle in pairs(keyedVehicles) do
            if netId == currentNetId then
                removeBlip(netId)
            elseif not blips[netId] or not DoesBlipExist(blips[netId]) then
                local blip = AddBlipForCoord(vehicle.coords.x, vehicle.coords.y, vehicle.coords.z)
                blips[netId] = blip
                SetBlipSprite(blip, Config.GpsSprite)
                SetBlipColour(blip, Config.GpsColour)
                SetBlipScale(blip, Config.GpsScale)
                SetBlipAsShortRange(blip, false)
                SetBlipDisplay(blip, 4)
            end
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for netId in pairs(blips) do
        removeBlip(netId)
    end
end)
