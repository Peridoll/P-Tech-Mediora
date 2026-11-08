VehicleAssets = VehicleAssets or {}

MedioraVehicles = {
    KeyAccess = {
        ambulance = { Job = 'ambulance', RequireDuty = true },
    },
    Callout = {
        TargetDistance = 2.0,
        ServerDistance = 5.0,
        SpawnClearance = 1.5,
    },
    GPS = {
        UpdateIntervalMs = 1500,
        VisibleDistance = 1500.0,
        Blips = {
            ambulance = { sprite = 56, color = 1, scale = 0.8, label = '救急車' },
        },
    },
}
