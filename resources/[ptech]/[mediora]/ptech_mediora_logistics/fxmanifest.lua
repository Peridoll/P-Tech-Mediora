fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ptech_mediora_logistics'
author 'P-Tech'
description 'Mediora Logistics'
version '0.3.2'

dependencies {
  'ptech_mediora_core',
  'qbx_core',
  'ox_lib',
  'ox_inventory',
  'oxmysql',
  '/onesync',
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'install/ox_inventory/items.lua',
  'recipes.lua',
}

files { 'main/ui/progress/*.svg' }

client_script 'main/client/client.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'main/server/server.lua',
  'main/server/orders.lua',
}
