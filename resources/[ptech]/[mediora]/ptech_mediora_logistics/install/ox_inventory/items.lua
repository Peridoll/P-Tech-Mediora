-- 【用途と導入先】
-- このファイルはLogisticsが直接読み込む Config.Items（物資ストア等の商品データ）。
-- ファイル全体を ox_inventory/data/items.lua へ貼り付けない。
-- インベントリ定義へ統合する際は各 ['アイテムID'] の中身を既存項目に統合する。
-- 医療道具の使用設定（consume / client.export）はMedicalのinstallを基準にする。
-- client.image はインベントリ用、直下の image は商品表示用の画像設定。
-- 医療道具はMedical、物流箱はLogisticsの公開GitHub画像URLを使用する。
-- 物流箱のインベントリ定義はToolsのinstall内の pmediora_supplybox / pmediora_specialbox を参照。
-- 商品定義の反映にはLogisticsの再起動が必要。
-- インベントリ定義の反映はサーバー再起動とクライアント再接続で確認する。
-- Canonical item data. Treatment effects are descriptive until integration is added.
Config.Items = {
  ['pmediora_supplybox'] = {
    label = '医療物資',
    description = '',
    weight = 500, stack = true, close = true, consume = 0,
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
  },
  ['pmediora_specialbox'] = {
    label = '特注医療物資',
    description = '',
    weight = 500, stack = true, close = true, consume = 0,
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
  },
}
