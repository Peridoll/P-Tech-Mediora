fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Marine - rescue fins and emergency flotation'
version '0.1.0'

shared_scripts { '@ox_lib/init.lua', 'config/config.lua', 'main/shared/rules.lua' }
client_scripts { 'main/client/client.lua' }
server_scripts { 'config/server.lua', 'main/server/server.lua' }
dependencies { 'ox_lib', 'ox_inventory', 'qbx_core', 'wasabi_ambulance', '/onesync' }
