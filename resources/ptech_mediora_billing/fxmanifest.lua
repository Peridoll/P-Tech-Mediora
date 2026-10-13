fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Billing standalone medical invoice drafting'
version '0.1.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'oxmysql' }
