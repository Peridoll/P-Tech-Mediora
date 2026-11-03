local function hasMedicalJob()
    local playerData = exports.qbx_core:GetPlayerData()
    return playerData and playerData.job and playerData.job.name == Config.Job
end

if next(Config.ShopVehiclesByHash) then
    exports.ox_target:addGlobalVehicle({
        {
            name = 'ptech_mediora_vehicles_trunk_shop',
            bones = { 'boot' },
            icon = 'fa-solid fa-kit-medical',
            label = 'EMS車両備品を開く',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                return hasMedicalJob() and Config.ShopVehiclesByHash[GetEntityModel(entity)] ~= nil
            end,
            onSelect = function(data)
                TriggerServerEvent(
                    'ptech_mediora_vehicles:server:openTrunkShop',
                    NetworkGetNetworkIdFromEntity(data.entity)
                )
            end,
        },
    })
end

RegisterNetEvent('ptech_mediora_vehicles:client:openTrunkShop', function(shopId)
    if type(shopId) ~= 'string' then return end
    exports.ox_inventory:openInventory('shop', { type = shopId })
end)

RegisterNetEvent('ptech_mediora_vehicles:client:trunkShopResult', function(success, message)
    lib.notify({ description = message, type = success and 'success' or 'error' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        exports.ox_target:removeGlobalVehicle('ptech_mediora_vehicles_trunk_shop')
    end
end)
