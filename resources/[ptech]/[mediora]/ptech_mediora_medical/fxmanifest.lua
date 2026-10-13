fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Medical - independent examination and diagnosis report resource'
version '0.1.0'
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'treatment_config.lua', 'shared.lua' }
client_scripts { 'nui.lua', 'ui.lua', 'client.lua' }
server_scripts { 'server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'wasabi_ambulance', 'ox_inventory', '/onesync' }
