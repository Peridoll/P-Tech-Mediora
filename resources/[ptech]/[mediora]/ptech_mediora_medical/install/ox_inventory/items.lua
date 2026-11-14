
-- ['pmediora_defibrillator'] = {
  --   label = '除細動器', englishLabel = 'AED',
  --   description = '患者の蘇生に使用する',
  --   weight = 1500, stack = false, buyPrice = nil, sellPrice = nil,
  --   effect = { type = 'revive' },
  --   client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_defibrillator.png' },
  -- },
  ['pmediora_firstaidkit'] = {
    label = '救急キット', englishLabel = 'First Aid Kit',
    description = '体力を大幅に回復させる',
    weight = 1000, stack = true, close = true, consume = 0,buyPrice = 300000, sellPrice = 60000,
    effect = { type = 'heal', percent = 100 },
    client = {
      export = 'ptech_mediora_medical.useMedicalItem',
      image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png'
    },
  },
  ['pmediora_bandage'] = {
    label = '包帯', englishLabel = 'Bandage',
    description = '出血を止め、体力を少量回復させる',
    weight = 100, stack = true, close = true, consume = 0,buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'heal', percent = 15, clearBleeding = true },
    client = {
      export = 'ptech_mediora_medical.useMedicalItem',
      image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bandage.png'
    },
  },
  ['pmediora_protectivecast'] = {
    label = '保護ギプス',
    description = '骨折した部位を補強して治療する',
    weight = 300, stack = true, close = true, consume = 0, buyPrice = 15000, sellPrice = 3000,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_splint.png' },
  },
  ['pmediora_coolingspray'] = {
    label = '冷却スプレー',
    description = '',
    weight = 150, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_icepack.png' },
  },
  ['pmediora_icepack'] = {
    label = '冷却パック', englishLabel = 'Ice Pack',
    description = '患部を冷やし、打撲の症状を抑える',
    weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'beat' },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_icepack.png' },
  },
  ['pmediora_bulletextractionkit'] = {
    label = '摘出キット', englishLabel = 'Bullet Extraction Kit',
    description = '患部から弾丸を安全に摘出する',
    weight = 500, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'shot', clearBleeding = true, healPercent = 15 },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bulletextractionkit.png' },
  },
  ['pmediora_surgicalforceps'] = {
    label = 'ピンセット', englishLabel = 'Surgical Forceps',
    description = '患部から弾丸を取り除くが、たまに出血してしまう',
    weight = 150, stack = true, buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'treat_injury', injury = 'shot', bleedingChance = 0.30 },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_surgicalforceps.png' },
  },
  ['pmediora_suturekit'] = {
    label = '縫合キット', englishLabel = 'Suture Kit',
    description = '患部を安全に縫合する',
    weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'stabbed', clearBleeding = true, healPercent = 15 },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_suturekit.png' },
  },
  ['pmediora_needleandthread'] = {
    label = '針と糸', englishLabel = 'Needle and Thread',
    description = '患部を縫い付けるが、たまに出血してしまう',
    weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'treat_injury', injury = 'stabbed', bleedingChance = 0.30 },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_needleandthread.png' },
  },
  ['pmediora_medicatedbandage'] = {
    label = '薬品包帯',
    description = '',
    weight = 100, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bandage.png' },
  },
  ['pmediora_burncream'] = {
    label = '火傷クリーム', englishLabel = 'Burn Cream',
    description = '火傷の炎症を抑える薬',
    weight = 150, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'burned' },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_burncream.png' },
  },
  ['pmediora_ivdrip'] = {
    label = '点滴',
    description = '医療職が餓死・溺死の患者に使用する。餓死では空腹も回復する。',
    weight = 300, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_ivdrip.png' },
  },
  -- ['pmediora_painkiller'] = {
  --   label = '鎮痛剤', weight = 30, stack = true, close = true, consume = 0,
  --   client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png', export = 'ptech_mediora_medical.useMedicalItem' },
  -- },
  -- ['pmediora_hemostatic'] = {
  --   label = '止血剤', weight = 30, stack = true, close = true, consume = 0,
  --   client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png', export = 'ptech_mediora_medical.useMedicalItem' },
  -- },
  ['pmediora_herb'] = {
    label = '薬草', englishLabel = 'EMS Herb',
    description = '摘んできた薬草。雑草ではない',
    weight = 50, stack = true, usable = false,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_herb.png' },
  },
  ['pmediora_water'] = {
    label = '水', englishLabel = 'EMS Water',
    description = '汲んだ水。飲むのはちょっと',
    weight = 500, stack = true, usable = false,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_water.png' },
  },
  ['pmediora_purifiedwater'] = {
    label = '精製水', englishLabel = 'EMS Purified Water',
    description = '精製された水。医療に使用できる',
    weight = 500, stack = true, usable = false,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_purifiedwater.png' },
  },

