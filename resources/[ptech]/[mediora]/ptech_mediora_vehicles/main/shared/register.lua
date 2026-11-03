Config.CalloutCarriers = {}
Config.ShopVehicles = {}
Config.ShopVehiclesByHash = {}
Config.VehicleModelsByHash = {}

for assetId, asset in pairs(VehicleAssets) do
    for modelName, modelConfig in pairs(asset.models or {}) do
        Config.Vehicles[modelName] = modelConfig
        Config.VehicleModelsByHash[joaat(modelName)] = modelConfig
    end

    local callout = asset.callout
    if callout and callout.spawnedModel then
        for _, carrierModel in ipairs(callout.carrierModels or {}) do
            local carrierHash = joaat(carrierModel)
            Config.CalloutCarriers[carrierHash] = Config.CalloutCarriers[carrierHash] or {}
            Config.CalloutCarriers[carrierHash][#Config.CalloutCarriers[carrierHash] + 1] = {
                assetId = assetId,
                spawnedModel = callout.spawnedModel,
                vehicleType = callout.vehicleType or 'automobile',
                rearOffset = callout.rearOffset or { x = 0.0, y = -5.0, z = 0.25 },
                maxDistance = callout.maxDistance or 4.0,
            }
        end
    end

    local shop = asset.trunkShop
    if shop and shop.enabled and type(shop.inventory) == 'table' and #shop.inventory > 0 then
        for modelName in pairs(asset.models or {}) do
            Config.ShopVehicles[modelName] = shop
            Config.ShopVehiclesByHash[joaat(modelName)] = shop
        end
    end
end
