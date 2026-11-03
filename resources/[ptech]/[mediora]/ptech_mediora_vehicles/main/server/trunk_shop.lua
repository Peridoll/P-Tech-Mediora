local registeredShops = {}

local function isMedicalEmployee(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData and player.PlayerData.job
        and player.PlayerData.job.name == Config.Job
end

local function registerShops()
    for _, shop in pairs(Config.ShopVehicles) do
        if not registeredShops[shop.id] and type(shop.inventory) == 'table' and #shop.inventory > 0 then
            exports.ox_inventory:RegisterShop(shop.id, {
                name = shop.name,
                inventory = shop.inventory,
                groups = shop.groups,
            })
            registeredShops[shop.id] = true
        end
    end
end

AddEventHandler('onServerResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'ox_inventory' then
        registerShops()
    end
end)

RegisterNetEvent('ptech_mediora_vehicles:server:openTrunkShop', function(netId)
    local source = source
    if not isMedicalEmployee(source) then
        TriggerClientEvent('ptech_mediora_vehicles:client:trunkShopResult', source, false, 'EMS職員のみ利用できます。')
        return
    end

    if type(netId) ~= 'number' or netId < 1 then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local shop = Config.ShopVehiclesByHash[GetEntityModel(vehicle)]
    if not shop or not registeredShops[shop.id] then
        TriggerClientEvent('ptech_mediora_vehicles:client:trunkShopResult', source, false, 'この車両には利用できる備品ショップがありません。')
        return
    end

    if not exports.qbx_vehiclekeys:HasKeys(source, vehicle) then
        TriggerClientEvent('ptech_mediora_vehicles:client:trunkShopResult', source, false, '車両キーを持っていません。')
        return
    end

    if GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(vehicle) then return end

    local ped = GetPlayerPed(source)
    local rear = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
    if ped == 0 or #(GetEntityCoords(ped) - rear) > Config.TargetDistance + 1.0 then
        TriggerClientEvent('ptech_mediora_vehicles:client:trunkShopResult', source, false, '車両の後部に近づいてください。')
        return
    end

    TriggerClientEvent('ptech_mediora_vehicles:client:openTrunkShop', source, shop.id)
end)
