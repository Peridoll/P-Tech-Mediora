-- Canonical item data. Treatment effects are descriptive until integration is added.
Config.Items = {
    ['ptech_medical_defibrillator'] = {
        label = 'AED', englishLabel = 'AED', description = '患者の蘇生に使用する',
        weight = 1500, stack = false, buyPrice = nil, sellPrice = nil,
        effect = { type = 'revive' },
    },
    ['ptech_medical_first_aid_kit'] = {
        label = '救急キット', englishLabel = 'First Aid Kit', description = '体力を大幅に回復させる',
        weight = 1000, stack = true, buyPrice = 300000, sellPrice = 60000,
        effect = { type = 'heal', percent = 100 },
    },
    ['ptech_medical_bandage'] = {
        label = '包帯', englishLabel = 'Bandage', description = '出血を止め、体力を少量回復させる',
        weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
        effect = { type = 'heal', percent = 15, clearBleeding = true },
    },
    ['ptech_medical_splint'] = {
        label = '副木', englishLabel = 'Splint', description = '骨折した箇所を補強する。治療後15分間は再発しやすくなる',
        weight = 500, stack = true, buyPrice = 150000, sellPrice = 30000,
        effect = { type = 'treat_injury', injury = 'fracture', applyState = 'splint', stateDuration = 900 },
    },
    ['ptech_medical_ice_pack'] = {
        label = '冷却パック', englishLabel = 'Ice Pack', description = '患部を冷やし、打撲の症状を抑える',
        weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
        effect = { type = 'treat_injury', injury = 'beat' },
    },
    ['ptech_medical_bullet_extraction_kit'] = {
        label = '摘出キット', englishLabel = 'Bullet Extraction Kit', description = '患部から弾丸を安全に摘出する',
        weight = 500, stack = true, buyPrice = 100000, sellPrice = 20000,
        effect = { type = 'treat_injury', injury = 'shot', clearBleeding = true, healPercent = 15 },
    },
    ['ptech_medical_surgical_forceps'] = {
        label = 'ピンセット', englishLabel = 'Surgical Forceps', description = '患部から弾丸を取り除くが、たまに出血してしまう',
        weight = 150, stack = true, buyPrice = 50000, sellPrice = 10000,
        effect = { type = 'treat_injury', injury = 'shot', bleedingChance = 0.30 },
    },
    ['ptech_medical_suture_kit'] = {
        label = '縫合キット', englishLabel = 'Suture Kit', description = '患部を安全に縫合する',
        weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
        effect = { type = 'treat_injury', injury = 'stabbed', clearBleeding = true, healPercent = 15 },
    },
    ['ptech_medical_needle_and_thread'] = {
        label = '針と糸', englishLabel = 'Needle and Thread', description = '患部を縫い付けるが、たまに出血してしまう',
        weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
        effect = { type = 'treat_injury', injury = 'stabbed', bleedingChance = 0.30 },
    },
    ['ptech_medical_burn_cream'] = {
        label = '火傷クリーム', englishLabel = 'Burn Cream', description = '火傷の炎症を抑える薬',
        weight = 150, stack = true, buyPrice = 100000, sellPrice = 20000,
        effect = { type = 'treat_injury', injury = 'burned' },
    },
    ['ptech_medical_herb'] = {
        label = 'EMS Herb', englishLabel = 'EMS Herb', description = '摘んできた薬草。雑草ではない',
        weight = 50, stack = true, usable = false,
    },
    ['ptech_medical_water'] = {
        label = 'EMS Water', englishLabel = 'EMS Water', description = '汲んだ水。飲むのはちょっと',
        weight = 500, stack = true, usable = false,
    },
    ['ptech_medical_purified_water'] = {
        label = 'EMS Purified Water', englishLabel = 'EMS Purified Water', description = '精製された水。医療に使用できる',
        weight = 500, stack = true, usable = false,
    },
}
