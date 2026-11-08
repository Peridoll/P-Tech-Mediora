-- Canonical item data. Treatment effects are descriptive until integration is added.
Config.Items = {
    ['pmediora_firstaidkit'] = {
        label = '救急キット', englishLabel = 'First Aid Kit', description = '体力を大幅に回復させる',
        weight = 1000, stack = true, buyPrice = 300000, sellPrice = 60000,
        rarity = 'UR',
        effect = { type = 'heal', percent = 100 },
    },
    ['pmediora_bandage'] = {
        label = '包帯', englishLabel = 'Bandage', description = '出血を止め、体力を少量回復させる',
        weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
        rarity = 'C',
        effect = { type = 'heal', percent = 15, clearBleeding = true },
    },
    ['pmediora_splint'] = {
        label = '副木', englishLabel = 'Splint', description = '骨折した箇所を補強する。治療後15分間は再発しやすくなる',
        weight = 500, stack = true, buyPrice = 150000, sellPrice = 30000,
        rarity = 'R',
        effect = { type = 'treat_injury', injury = 'fracture', applyState = 'splint', stateDuration = 900 },
    },
    ['pmediora_icepack'] = {
        label = '冷却パック', englishLabel = 'Ice Pack', description = '患部を冷やし、打撲の症状を抑える',
        weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
        rarity = 'R',
        effect = { type = 'treat_injury', injury = 'beat' },
    },
    ['pmediora_bulletextractionkit'] = {
        label = '摘出キット', englishLabel = 'Bullet Extraction Kit', description = '患部から弾丸を安全に摘出する',
        weight = 500, stack = true, buyPrice = 100000, sellPrice = 20000,
        rarity = 'SR',
        effect = { type = 'treat_injury', injury = 'shot', clearBleeding = true, healPercent = 15 },
    },
    ['pmediora_surgicalforceps'] = {
        label = 'ピンセット', englishLabel = 'Surgical Forceps', description = '患部から弾丸を取り除くが、たまに出血してしまう',
        weight = 150, stack = true, buyPrice = 50000, sellPrice = 10000,
        rarity = 'UC',
        effect = { type = 'treat_injury', injury = 'shot', bleedingChance = 0.30 },
    },
    ['pmediora_suturekit'] = {
        label = '縫合キット', englishLabel = 'Suture Kit', description = '患部を安全に縫合する',
        weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
        rarity = 'SR',
        effect = { type = 'treat_injury', injury = 'stabbed', clearBleeding = true, healPercent = 15 },
    },
    ['pmediora_needleandthread'] = {
        label = '針と糸', englishLabel = 'Needle and Thread', description = '患部を縫い付けるが、たまに出血してしまう',
        weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
        rarity = 'UC',
        effect = { type = 'treat_injury', injury = 'stabbed', bleedingChance = 0.30 },
    },
    ['pmediora_burncream'] = {
        label = '火傷クリーム', englishLabel = 'Burn Cream', description = '火傷の炎症を抑える薬',
        weight = 150, stack = true, buyPrice = 100000, sellPrice = 20000,
        rarity = 'C',
        effect = { type = 'treat_injury', injury = 'burned' },
    },
    ['pmediora_herb'] = {
        label = '薬草', englishLabel = 'EMS Herb', description = '摘んできた薬草。雑草ではない',
        weight = 50, stack = true, usable = false,
    },
    ['pmediora_water'] = {
        label = '水', englishLabel = 'EMS Water', description = '汲んだ水。飲むのはちょっと',
        weight = 500, stack = true, usable = false,
    },
    ['pmediora_purifiedwater'] = {
        label = '精製水', englishLabel = 'EMS Purified Water', description = '精製された水。医療に使用できる',
        weight = 500, stack = true, usable = false,
    },
}
