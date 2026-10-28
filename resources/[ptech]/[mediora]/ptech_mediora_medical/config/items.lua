-- Mediora の治療画面で使う専用物資。
--
-- Wasabi Ambulance v1 の既存アイテムは変更しない。以下は同じ傷分類を
-- Mediora の画面から処置するための別アイテムである。
--
-- Ox Inventory へ登録するコードは、このリソースの実行コードに混ぜない。
-- assets/install/ox_inventory/items.lua を導入先の ox_inventory/data/items.lua へ
-- 手動で追加する。consume は 0 を維持し、治療成功時の消費は Medical
-- サーバー側だけが行う。
--
-- image は指定していない。画像を用意するまで、Mediora のUIは uiLabel を
-- 文字の仮アイコンとして表示する。

MedioraItems = {
  ['ptech_mediora_tweezers'] = {
    label = '医療キット：銃創処置',
    uiLabel = '医療キット\n銃創',
    description = '銃創の処置に使用する医療キット。',
    treatment = 'shot',
  },
  ['ptech_mediora_suturekit'] = {
    label = '医療キット：刺創処置',
    uiLabel = '医療キット\n刺創',
    description = '刺創の処置に使用する医療キット。',
    treatment = 'stabbed',
  },
  ['ptech_mediora_icepack'] = {
    label = '医療キット：打撲処置',
    uiLabel = '医療キット\n打撲',
    description = '打撲の処置に使用する医療キット。',
    treatment = 'beat',
  },
  ['ptech_mediora_burncream'] = {
    label = '医療キット：熱傷処置',
    uiLabel = '医療キット\n熱傷',
    description = '熱傷の処置に使用する医療キット。',
    treatment = 'burned',
  },
}

