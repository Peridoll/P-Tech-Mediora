fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Rescue - PD emergency helicopter extraction'
version '0.2.0'
shared_scripts { '@ox_lib/init.lua', 'config/config.lua', 'main/shared/rules.lua' }
client_scripts { 'main/client/client.lua' }
server_scripts { 'main/server/server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'wasabi_ambulance', '/onesync' }
