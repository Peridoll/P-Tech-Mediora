VehicleAssets.ptech_ems_blazer = {
    Models = { 'pemsblazer' },
    DisplayName = 'EMS Blazer Aqua',
    GameName = 'PTECH_EMSAQUA',
    DisableVehicleWeapon = true,
    KeyAccess = { Job = 'ambulance', RequireDuty = true },
    Mooring = {
        Enabled = true,
        OnlyWhenInWater = true,
        ArmDelayMs = 1200,
        ScanIntervalMs = 100,
        PassiveDriftSpeedMps = 0.45,
        PassiveVelocityMultiplier = 0.05,
        ReleaseSpeedMps = 1.50,
        ReleaseDistanceM = 0.12,
        ReleaseCooldownMs = 2500,
        DismountDampingMs = 1600,
        DismountVelocityMultiplier = 0.12,
        StopEngineWhenMooring = true,
    },
    Callout = {
        CarrierModels = { 'ambulance' },
        TargetLabel = 'EMSブレイザーを出し入れ',
        -- 車両ローカル座標。値は実車で調整する。
        SpawnOffset = vector3(0.0, -4.8, 0.2),
        SpawnHeadingOffset = 180.0,
        ModelType = 'bike',
    },
    GPS = {
        Blip = { sprite = 501, color = 3, scale = 0.75, label = 'EMSブレイザー' },
    },
}

-- Calloutの登録数が0なら、共通の後部呼び出し機能は何も登録しない。
