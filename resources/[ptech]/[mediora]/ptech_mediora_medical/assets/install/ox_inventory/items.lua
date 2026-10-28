-- Mediora Medical / ox_inventory 手動導入用アイテム定義
--
-- 【配置先】
--   resources/<ox_inventoryを配置しているグループ>/ox_inventory/data/items.lua
--
-- 【導入方法】
--   1. 上記の導入先ファイルを開く。
--   2. 既存の return { ... } の中へ、下の4件だけをコピーする。
--      このファイル全体で既存の items.lua を上書きしないこと。
--   3. ox_inventory を再起動する（サーバー再起動でも可）。
--
-- 【画像】
--   現時点では画像を使用しない。画像を追加する場合は、同じアイテム名の
--   PNGを assets/install/ox_inventory/images/ に置き、導入先の
--   resources/<ox_inventoryを配置しているグループ>/ox_inventory/web/images/ へ
--   コピーする。
--
-- 【消費】
--   consume = 0 は必ず維持する。単独使用では消費せず、Mediora Medicalが
--   処置成功を確認したときだけサーバー側で消費する（治療実装後）。

return {

['ptech_mediora_tweezers'] = {
    label = '医療キット：銃創処置',
    weight = 100,
    stack = true,
    close = true,
    consume = 0,
    description = '銃創の処置に使用する医療キット。',
},

['ptech_mediora_suturekit'] = {
    label = '医療キット：刺創処置',
    weight = 100,
    stack = true,
    close = true,
    consume = 0,
    description = '刺創の処置に使用する医療キット。',
},

['ptech_mediora_icepack'] = {
    label = '医療キット：打撲処置',
    weight = 100,
    stack = true,
    close = true,
    consume = 0,
    description = '打撲の処置に使用する医療キット。',
},

['ptech_mediora_burncream'] = {
    label = '医療キット：熱傷処置',
    weight = 100,
    stack = true,
    close = true,
    consume = 0,
    description = '熱傷の処置に使用する医療キット。',
},

}
