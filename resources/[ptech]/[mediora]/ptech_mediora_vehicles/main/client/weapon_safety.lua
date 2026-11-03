local vehicleConfigs = {}
local weapon = joaat('VEHICLE_WEAPON_CANNON_BLAZER')
local disabled

for modelName, vehicleConfig in pairs(Config.Vehicles) do
    vehicleConfigs[joaat(modelName)] = vehicleConfig
    AddTextEntry(vehicleConfig.gameName or ('PTECH_' .. modelName:upper()), vehicleConfig.label or modelName)
end

local function releaseWeapon()
    if disabled and DoesEntityExist(disabled.vehicle) and DoesEntityExist(disabled.ped) then
        DisableVehicleWeapon(false, weapon, disabled.vehicle, disabled.ped)
    end
    disabled = nil
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleConfig = vehicle ~= 0 and vehicleConfigs[GetEntityModel(vehicle)] or nil
        local active = vehicleConfig and vehicleConfig.disableVehicleWeapon
            and GetPedInVehicleSeat(vehicle, -1) == ped

        if disabled and (not active or disabled.vehicle ~= vehicle or disabled.ped ~= ped) then
            releaseWeapon()
        end

        if active then
            -- pemsblazer の運転席だけに適用する。標準 blazer5 や他車両には触れない。
            DisableVehicleWeapon(true, weapon, vehicle, ped)
            disabled = { vehicle = vehicle, ped = ped }
            DisableControlAction(0, 69, true) -- INPUT_VEH_ATTACK
            DisableControlAction(0, 70, true) -- INPUT_VEH_ATTACK2
        end

        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        releaseWeapon()
    end
end)
