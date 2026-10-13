fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Escort - standalone patient transport and vehicle transfer'
version '0.1.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'shared/targets.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
dependencies { 'ox_lib', 'qbx_core', 'ox_target', '/onesync' }
