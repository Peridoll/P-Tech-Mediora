local carriers = {}
local deployedByCarrier = {}

for assetId, vehicleConfig in pairs(VehicleAssets) do
    local callout = vehicleConfig.Callout
    if callout then
        for _, modelName in ipairs(callout.CarrierModels or {}) do
            carriers[joaat(modelName)] = { assetId = assetId, config = callout }
        end
    end
end

if next(carriers) then
    RegisterNetEvent('ptech_mediora_vehicles:client:setCalloutState', function(carrierNetId, deployedNetId)
        deployedByCarrier[carrierNetId] = deployedNetId
    end)

    CreateThread(function()
        Wait(1000)
        TriggerServerEvent('ptech_mediora_vehicles:server:requestCalloutState')
    end)

    local options = {}
    for modelHash, info in pairs(carriers) do
        local targetModelHash = modelHash
        local targetInfo = info
        options[#options + 1] = {
            name = ('ptech_mediora_vehicles:callout:%s'):format(targetInfo.assetId),
            icon = 'fa-solid fa-truck-medical',
            label = targetInfo.config.TargetLabel or '車両を出す / 格納する',
            bones = { 'boot' },
            distance = MedioraVehicles.Callout.TargetDistance,
            canInteract = function(entity)
                if GetEntityModel(entity) ~= targetModelHash then return false end
                local playerPed = PlayerPedId()
                if IsPedInAnyVehicle(playerPed, false) then return false end
                return exports.qbx_vehiclekeys:HasKeys(entity)
            end,
            onSelect = function(data)
                local carrier = data.entity
                local carrierNetId = NetworkGetNetworkIdFromEntity(carrier)
                local deployedNetId = deployedByCarrier[carrierNetId]
                if deployedNetId and NetworkDoesNetworkIdExist(deployedNetId) then
                    TriggerServerEvent('ptech_mediora_vehicles:server:storeCallout', carrierNetId, deployedNetId)
                else
                    TriggerServerEvent('ptech_mediora_vehicles:server:deployCallout', carrierNetId)
                end
            end,
        }
    end
    exports.ox_target:addGlobalVehicle(options)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            for _, option in ipairs(options) do
                exports.ox_target:removeGlobalVehicle(option.name)
            end
        end
    end)
end
