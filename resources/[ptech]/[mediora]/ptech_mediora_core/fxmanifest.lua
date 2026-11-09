fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ptech_mediora_core'
author 'P-Tech'
description 'Mediora Core'
version '0.2.2'

dependencies {
    'ox_inventory',
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
    'config/tablet_home.lua',
    'main/server/server.lua',
    'main/server/tablet_admin.lua',
}

ui_page 'main/ui/progress.html'
files {
    'config/config.lua',
    'main/ui/progress.html',
    'main/ui/app.js',
    'main/ui/style.css',
    'main/ui/tablet.js',
    'main/ui/tablet.css',
}
client_scripts {
    'main/client/progress.lua',
    'main/client/action_panel.lua',
    'main/client/tablet.lua',
}
