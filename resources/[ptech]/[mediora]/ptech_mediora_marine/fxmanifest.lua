fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Marine - emergency flotation for downed players in water'
version '0.1.0'

shared_scripts { '@ox_lib/init.lua', 'config/config.lua', 'main/shared/rules.lua' }
client_scripts { 'main/client/flotation.lua' }
server_scripts { 'config/server.lua', 'main/server/flotation.lua', 'main/server/integrations.lua' }
ui_page 'main/ui/index.html'
files { 'main/ui/index.html', 'main/ui/app.js', 'main/ui/style.css' }
dependencies { 'ox_lib', 'qbx_core', 'wasabi_ambulance', '/onesync' }
