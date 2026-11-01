-- 導入先: ox_inventory/data/items.lua
-- 手順: 以下の return { ... } に含まれる15アイテムを、導入先の既存 return { ... } の中へ追加する。
-- 注意: このファイルで既存 items.lua 全体を上書きしない。同じIDを既に使用している場合は統合して重複を避ける。
-- 段ボールの開封には ptech_mediora_logistics の起動が必要。その他の医療効果はMedical連携まで説明のみ。
-- 画像は必要に応じて ox_inventory/web/images に各アイテムID.png を配置する。
return {
    ['ptech_mediora_supply_box'] = {
        label = '医療物資段ボール',
        weight = 500,
        stack = true,
        close = true,
        consume = 0,
        description = '納品先が指定された医療物資の段ボール',
        server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
    },
    ['ptech_mediora_special_box'] = {
        label = '特注医療物資段ボール',
        weight = 500,
        stack = true,
        close = true,
        consume = 0,
        description = '日替わりレシピで作る特注医療物資段ボール',
        server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
    },
    ['ptech_medical_first_aid_kit'] = {
        label = '救急キット', weight = 1000, stack = true, close = true,
        description = '体力を大幅に回復させる',
    },
    ['ptech_medical_bandage'] = {
        label = '包帯', weight = 100, stack = true, close = true,
        description = '出血を止め、体力を少量回復させる',
    },
    ['ptech_medical_splint'] = {
        label = '副木', weight = 500, stack = true, close = true,
        description = '骨折した箇所を補強する。治療後15分間は再発しやすくなる',
    },
    ['ptech_medical_ice_pack'] = {
        label = '冷却パック', weight = 300, stack = true, close = true,
        description = '患部を冷やし、打撲の症状を抑える',
    },
    ['ptech_medical_bullet_extraction_kit'] = {
        label = '摘出キット', weight = 500, stack = true, close = true,
        description = '患部から弾丸を安全に摘出する',
    },
    ['ptech_medical_surgical_forceps'] = {
        label = 'ピンセット', weight = 150, stack = true, close = true,
        description = '患部から弾丸を取り除く。処置時に出血させることがある',
    },
    ['ptech_medical_suture_kit'] = {
        label = '縫合キット', weight = 300, stack = true, close = true,
        description = '患部を安全に縫合する',
    },
    ['ptech_medical_needle_and_thread'] = {
        label = '針と糸', weight = 100, stack = true, close = true,
        description = '患部を縫い付ける。処置時に出血させることがある',
    },
    ['ptech_medical_burn_cream'] = {
        label = '火傷クリーム', weight = 150, stack = true, close = true,
        description = '火傷の炎症を抑える薬',
    },
    ['ptech_medical_defibrillator'] = {
        label = 'AED', weight = 1500, stack = false, close = true,
        description = '患者の蘇生に使用する',
    },
    ['ptech_medical_herb'] = {
        label = 'EMS Herb', weight = 50, stack = true, close = true,
        description = '摘んできた薬草。雑草ではない',
    },
    ['ptech_medical_water'] = {
        label = 'EMS Water', weight = 500, stack = true, close = true,
        description = '汲んできた水。飲むのはちょっと',
    },
    ['ptech_medical_purified_water'] = {
        label = 'EMS Purified Water', weight = 500, stack = true, close = true,
        description = '精製された水。医療に使用できる',
    },
}
