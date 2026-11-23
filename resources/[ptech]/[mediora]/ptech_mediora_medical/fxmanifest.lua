fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Medical - examination and persistent patient charts'
version '0.1.0'
ui_page 'main/ui/index.html'
files { 'main/ui/index.html', 'main/ui/style.css', 'main/ui/examination.css', 'main/ui/charts.css', 'main/ui/app.js', 'main/ui/private-billing.js', 'main/ui/private-billing.css', 'main/ui/progress/*.svg', 'install/ox_inventory/images/pmediora_bag*.png' }
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'main/shared/shared.lua', 'main/shared/wounds.lua', 'main/shared/private_medic.lua', 'main/shared/private_billing.lua' }
client_scripts { 'main/client/inventory.lua', 'main/client/nui.lua', 'main/client/ui.lua', 'main/client/wounds.lua', 'main/client/crutch.lua', 'main/client/treatment.lua', 'main/client/client.lua', 'main/client/private_medic.lua', 'main/client/private_billing.lua' }
server_scripts { 'main/server/inventory.lua', '@oxmysql/lib/MySQL.lua', 'main/server/containers.lua', 'main/server/wounds.lua', 'main/server/crutch.lua', 'main/server/fractures.lua', 'main/server/server.lua', 'main/server/private_medic.lua', 'main/server/private_billing.lua' }
dependencies { 'ox_lib', 'ox_target', 'qbx_core', 'ox_inventory', 'oxmysql', 'wasabi_ambulance', '/onesync' }
