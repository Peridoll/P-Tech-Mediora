VehicleAssets.ptech_ems_shinobi = {
    Models = { 'pems_shinobi' },
    DisplayName = 'NOVILL EMS Shinobi',
    GameName = 'PEMS_SHINOBI',
    DisableVehicleWeapon = false,
    KeyAccess = { Job = 'ambulance', RequireDuty = true },
    GPS = {
        Blip = { sprite = 226, color = 1, scale = 0.70, label = 'NOVILL EMS Shinobi' },
    },
    Activity = { TrackDistance = true, TrackFuel = true },
}
