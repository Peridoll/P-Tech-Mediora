fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'P-Tech'
description 'Mediora EMSManager tablet home and temporary chart viewer'
version '0.1.0'

ui_page 'main/ui/index.html'

files {
    'main/ui/index.html',
    'main/ui/style.css',
    'main/ui/app.js',
    'main/ui/assets/mediora-wallpaper.svg',
}

shared_scripts { '@ox_lib/init.lua', 'config/config.lua' }
client_scripts { 'main/client/patient_view.lua', 'main/client/client.lua' }
server_scripts { 'main/server/server.lua' }

dependencies { 'ox_lib', 'ox_inventory', 'qbx_core', 'ptech_mediora_medical' }
