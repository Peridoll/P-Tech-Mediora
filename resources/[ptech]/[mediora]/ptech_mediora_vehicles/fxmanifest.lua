fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'P-Tech'
description 'Shared vehicle systems and vehicle-specific assets for Mediora'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'assets/**/config.lua',
}

client_scripts {
    'assets/ptech_ems_shinobi/client/vehiclenames.lua',
    'assets/ptech_ems_shinobi/client/livery.lua',
    'main/client/weapon_safety.lua',
    'main/client/mooring.lua',
    'main/client/vehicle_callout.lua',
    'main/client/gps.lua',
    'main/client/keys.lua',
}

server_scripts {
    'main/server/vehicle_callout.lua',
    'main/server/gps.lua',
    'main/server/keys.lua',
}

files {
    'assets/**/data/*.meta',
    'assets/**/stream/*',
}

data_file 'VEHICLE_LAYOUTS_FILE' 'assets/ptech_ems_blazer/data/vehiclelayouts.meta'
data_file 'HANDLING_FILE' 'assets/ptech_ems_blazer/data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'assets/ptech_ems_blazer/data/vehicles.meta'
data_file 'CARCOLS_FILE' 'assets/ptech_ems_blazer/data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'assets/ptech_ems_blazer/data/carvariations.meta'

data_file 'HANDLING_FILE' 'assets/ptech_ems_shinobi/data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'assets/ptech_ems_shinobi/data/vehicles.meta'
data_file 'CARCOLS_FILE' 'assets/ptech_ems_shinobi/data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'assets/ptech_ems_shinobi/data/carvariations.meta'

dependencies {
    '/assetpacks',
    'ox_lib',
    'ox_target',
    'qbx_vehiclekeys',
    'qbx_core',
}

escrow_ignore {
    '**/*.lua',
    '**/*.meta',
    '**/*.ytd',
    'stream/mods/liveries/*.yft',
}
