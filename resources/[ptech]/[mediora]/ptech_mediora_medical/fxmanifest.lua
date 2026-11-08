fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Medical - independent examination and temporary chart resource'
version '0.1.0'
ui_page 'main/ui/index.html'
files { 'main/ui/index.html', 'main/ui/style.css', 'main/ui/examination.css', 'main/ui/charts.css', 'main/ui/app.js', 'main/ui/progress/*.svg' }
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'main/shared/shared.lua', 'main/shared/wounds.lua' }
client_scripts { 'main/client/nui.lua', 'main/client/ui.lua', 'main/client/wounds.lua', 'main/client/treatment.lua', 'main/client/client.lua' }
server_scripts { 'main/server/wounds.lua', 'main/server/fractures.lua', 'main/server/server.lua' }
dependencies { 'ox_lib', 'ox_target', 'qbx_core', 'wasabi_ambulance', '/onesync' }
