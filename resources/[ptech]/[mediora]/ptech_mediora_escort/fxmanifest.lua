fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Escort - standalone patient transport and vehicle transfer'
version '0.1.0'
shared_scripts { '@ox_lib/init.lua', 'config/config.lua', 'main/shared/targets.lua' }
client_scripts { 'main/client/client.lua' }
server_scripts { 'main/server/server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'ox_target', '/onesync' }
