fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Procurement - independent medical supply procurement job'
version '0.1.0'
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client.lua' }
server_scripts { 'server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'ox_inventory', 'ox_target', '/onesync' }
