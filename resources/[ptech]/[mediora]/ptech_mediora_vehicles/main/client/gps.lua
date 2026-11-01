local blips = {}

RegisterNetEvent('ptech_mediora_vehicles:client:updateGps', function(vehicles)
    local current = {}
    local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local playerNetId = playerVehicle ~= 0 and NetworkGetNetworkIdFromEntity(playerVehicle) or nil

    for _, info in ipairs(vehicles or {}) do
        current[info.netId] = true
        if playerNetId ~= info.netId then
            local blip = blips[info.netId]
            if not blip or not DoesBlipExist(blip.handle) then
                local handle = AddBlipForCoord(info.x, info.y, info.z)
                SetBlipSprite(handle, info.sprite or 56)
                SetBlipColour(handle, info.color or 1)
                SetBlipScale(handle, info.scale or 0.8)
                SetBlipAsShortRange(handle, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(info.label or '緊急車両')
                EndTextCommandSetBlipName(handle)
                blips[info.netId] = { handle = handle, label = info.label }
                blip = blips[info.netId]
            end
            SetBlipCoords(blip.handle, info.x, info.y, info.z)
        elseif blips[info.netId] and DoesBlipExist(blips[info.netId].handle) then
            RemoveBlip(blips[info.netId].handle)
            blips[info.netId] = nil
        end
    end

    for netId, blip in pairs(blips) do
        if not current[netId] or not DoesBlipExist(blip.handle) then
            if DoesBlipExist(blip.handle) then RemoveBlip(blip.handle) end
            blips[netId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip.handle) then RemoveBlip(blip.handle) end
    end
end)
