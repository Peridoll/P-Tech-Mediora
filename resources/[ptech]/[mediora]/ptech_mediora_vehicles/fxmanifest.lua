fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'P-Tech'
description 'Mediora emergency vehicle systems and vehicle assets'
version '0.3.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'assets/*/config.lua',
    'main/shared/register.lua',
}

client_scripts {
    'main/client/keys.lua',
    'main/client/gps.lua',
    'main/client/vehicle_callout.lua',
    'main/client/trunk_shop.lua',
    'main/client/activity.lua',
    'main/client/weapon_safety.lua',
    'main/client/mooring.lua',
}

server_scripts {
    'main/server/keys.lua',
    'main/server/gps.lua',
    'main/server/vehicle_callout.lua',
    'main/server/trunk_shop.lua',
    'main/server/activity.lua',
}

files {
    'assets/ptech_ems_blazer/data/vehicles.meta',
    'assets/ptech_ems_blazer/data/handling.meta',
    'assets/ptech_ems_blazer/data/carcols.meta',
    'assets/ptech_ems_blazer/data/carvariations.meta',
    'assets/ptech_ems_blazer/data/vehiclelayouts.meta',
    'assets/ptech_ems_blazer/data/mecanite_emergency_blazer_game.dat151.rel',
}

data_file 'VEHICLE_LAYOUTS_FILE' 'assets/ptech_ems_blazer/data/vehiclelayouts.meta'
data_file 'HANDLING_FILE' 'assets/ptech_ems_blazer/data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'assets/ptech_ems_blazer/data/vehicles.meta'
data_file 'CARCOLS_FILE' 'assets/ptech_ems_blazer/data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'assets/ptech_ems_blazer/data/carvariations.meta'
data_file 'AUDIO_GAMEDATA' 'assets/ptech_ems_blazer/data/mecanite_emergency_blazer_game.dat151.rel'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
    'qbx_vehiclekeys',
}
