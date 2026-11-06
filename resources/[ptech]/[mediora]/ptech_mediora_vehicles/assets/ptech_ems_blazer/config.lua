VehicleAssets.ptech_ems_blazer = {
    label = 'EMS Blazer Aqua',
    models = {
        pemsblazer = {
            label = 'EMS Blazer Aqua',
            gameName = 'PTECH_EMSAQUA',
            gps = true,
            autoKeys = true,
            trackMaintenance = true,
            mooring = {
                enabled = true,
                onlyWhenInWater = true,
                engineStopWhenMoored = true,
                armDelayMs = 1200,
                scanIntervalMs = 100,
                passiveDriftSpeedMps = 0.45,
                passiveVelocityMultiplier = 0.05,
                exitDampingMs = 1800,
                exitVelocityMultiplier = 0.15,
                collisionSpeedDeltaMps = 1.0,
                collisionImpulseMps = 2.0,
                releaseSpeedMps = 1.50,
                releaseDistanceM = 0.12,
                releaseCooldownMs = 2500,
            },
            disableVehicleWeapon = true,
        },
    },
    callout = {
        -- ブレイザーを呼び出せる車両は、ブレイザー側の設定に登録する。
        carrierModels = { 'ambulance' },
        spawnedModel = 'pemsblazer',
        vehicleType = 'bike',
        rearOffset = { x = 0.0, y = -5.5, z = 0.35 },
        maxDistance = 4.0,
    },
    trunkShop = {
        enabled = false,
        id = 'ptech_mediora_ems_vehicle_shop',
        name = 'EMS車両備品',
        groups = { ambulance = 0 },
        inventory = {},
    },
}
