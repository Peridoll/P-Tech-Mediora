fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ptech_mediora_logistics'
author 'P-Tech'
description 'Mediora Logistics'
version '0.2.0'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    '/onesync',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/items.lua',
    'config/recipes.lua',
}
client_script 'main/client/client.lua'
server_script 'main/server/server.lua'
