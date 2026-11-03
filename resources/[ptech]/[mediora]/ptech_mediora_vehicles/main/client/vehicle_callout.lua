local deployedByCarrier = {}

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('ptech_mediora_vehicles:server:requestCalloutState')
end)

local function hasMedicalJob()
    local playerData = exports.qbx_core:GetPlayerData()
    return playerData and playerData.job and playerData.job.name == Config.Job
end

RegisterNetEvent('ptech_mediora_vehicles:client:calloutState', function(carrierNetId, blazerNetId)
    carrierNetId = tonumber(carrierNetId)
    if not carrierNetId then return end

    if blazerNetId then
        deployedByCarrier[carrierNetId] = tonumber(blazerNetId)
    else
        deployedByCarrier[carrierNetId] = nil
    end
end)

RegisterNetEvent('ptech_mediora_vehicles:client:calloutResult', function(success, message)
    lib.notify({
        description = message or (success and '車両を呼び出しました。' or '車両を呼び出せませんでした。'),
        type = success and 'success' or 'error',
    })
end)

if next(Config.CalloutCarriers) then
    exports.ox_target:addGlobalVehicle({
        {
            name = 'ptech_mediora_vehicles_callout_deploy',
            bones = { 'boot' },
            icon = 'fa-solid fa-truck-medical',
            label = 'ブレイザーを呼び出す',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                if not hasMedicalJob() then return false end
                local netId = NetworkGetNetworkIdFromEntity(entity)
                return Config.CalloutCarriers[GetEntityModel(entity)] ~= nil and not deployedByCarrier[netId]
            end,
            onSelect = function(data)
                TriggerServerEvent(
                    'ptech_mediora_vehicles:server:callout',
                    'deploy',
                    NetworkGetNetworkIdFromEntity(data.entity)
                )
            end,
        },
        {
            name = 'ptech_mediora_vehicles_callout_store',
            bones = { 'boot' },
            icon = 'fa-solid fa-warehouse',
            label = 'ブレイザーを格納する',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                if not hasMedicalJob() then return false end
                local netId = NetworkGetNetworkIdFromEntity(entity)
                return Config.CalloutCarriers[GetEntityModel(entity)] ~= nil and deployedByCarrier[netId] ~= nil
            end,
            onSelect = function(data)
                TriggerServerEvent(
                    'ptech_mediora_vehicles:server:callout',
                    'store',
                    NetworkGetNetworkIdFromEntity(data.entity)
                )
            end,
        },
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        exports.ox_target:removeGlobalVehicle({
            'ptech_mediora_vehicles_callout_deploy',
            'ptech_mediora_vehicles_callout_store',
        })
    end
end)
