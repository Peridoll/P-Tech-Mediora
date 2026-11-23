fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'P-Tech'
description 'Mediora Rescue - Local helicopter transport test'
version '0.5.2'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'main/client/client.lua' }
server_scripts { 'main/server/pickup_test.lua' }
dependencies { 'ox_lib', 'ptech_mediora_core', 'qbx_core', '/onesync' }

-- 一時封印: 従来の搭乗検証・病院搬送・サーバー処理・管理コマンド。
-- shared_scripts { 'main/shared/boarding.lua', 'main/shared/rules.lua' }
-- client_script 'main/client/boarding.lua'
-- 旧搬送クライアントは dev/legacy/full_flow_client.lua に保存（起動しない）。
-- client_script 'main/client/pickup.lua' -- 0.5.1の切り分け実装を保管。
-- server_scripts { 'main/server/boarding.lua', 'main/server/server.lua' }
-- client_script 'main/client/teleport.lua' -- 成功確認済みの単純な上空移動を保管。
