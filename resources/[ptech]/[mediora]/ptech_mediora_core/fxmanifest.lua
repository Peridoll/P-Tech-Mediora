fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ptech_mediora_core'
author 'P-Tech'
description 'Mediora Core'
version '0.1.0'

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'main/server/server.lua',
}
