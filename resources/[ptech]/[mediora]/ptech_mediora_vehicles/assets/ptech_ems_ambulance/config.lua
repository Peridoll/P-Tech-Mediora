VehicleAssets.ptech_ems_ambulance = {
    label = 'EMS Ambulance',
    models = {
        ambulance = {
            label = 'EMS Ambulance',
            gps = true,
            autoKeys = true,
            trackMaintenance = true,
        },
    },
    trunkShop = {
        enabled = false,
        id = 'ptech_mediora_ems_vehicle_shop',
        name = 'EMS車両備品',
        groups = { ambulance = 0 },
        inventory = {},
    },
}
