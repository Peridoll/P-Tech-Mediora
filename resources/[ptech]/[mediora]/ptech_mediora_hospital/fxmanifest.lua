fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'P-Tech'
description 'Mediora Hospital'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'qbx_core', 'ptech_mediora_core', 'hane_pillbox', '/onesync' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'main/shared/rules.lua',
}

server_script 'main/server/activities.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'main/client/activities.lua',
}
