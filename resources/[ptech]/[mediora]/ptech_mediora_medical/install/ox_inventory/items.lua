-- 【画像の導入】
-- client.image はGitHubの公開画像URL。医療道具はMedical内の画像を参照する。
-- このファイルの各アイテムを ox_inventory/data/items.lua の既存項目へ統合する。
-- 既存の client.export・consume=0 を含めて統合し、同じIDを二重登録しない。
-- GitHub画像を使うこれらのアイテムは web/images への画像配置は不要。
-- 既存所持品の metadata.image / metadata.imageurl がある場合は個別画像が優先される。
-- 反映はサーバー再起動とクライアント再接続で確認する。
-- 【手動導入】ox_inventory/data/items.lua の return { ... } 内へ各項目を統合する。
-- このファイル全体で上書きしない。同じIDがTools等で定義済みなら既存項目へ統合する。
-- 重要：consume=0 と client.export をセットで指定する。
-- 消費はMedicalサーバーの成功処理が行うため、追加のuseItem・Wasabiイベントを重ねない。
-- 対象：救急キット・包帯・鎮痛剤・止血剤は自分へ使用できる。
-- 他の道具は勤務中の医療職がMedicalカルテから患者へ使用する（画像は任意）。
-- このファイルは既存の return { ... } に統合する項目の抜粋。

  ['pmediora_defibrillator'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_defibrillator.png' },
    label = '除細動器', englishLabel = 'AED', description = '患者の蘇生に使用する',
    weight = 1500, stack = false, buyPrice = nil, sellPrice = nil,
    effect = { type = 'revive' },
  },
  ['pmediora_firstaidkit'] = {
    close = true, consume = 0, client = {
      image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png', export = 'ptech_mediora_medical.useMedicalItem' },
    label = '救急キット', englishLabel = 'First Aid Kit', description = '体力を大幅に回復させる',
    weight = 1000, stack = true, buyPrice = 300000, sellPrice = 60000,
    effect = { type = 'heal', percent = 100 },
  },
  ['pmediora_bandage'] = {
    close = true, consume = 0, client = {
      image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bandage.png', export = 'ptech_mediora_medical.useMedicalItem' },
    label = '包帯', englishLabel = 'Bandage', description = '出血を止め、体力を少量回復させる',
    weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'heal', percent = 15, clearBleeding = true },
  },
  ['pmediora_icepack'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_icepack.png' },
    label = '冷却パック', englishLabel = 'Ice Pack', description = '患部を冷やし、打撲の症状を抑える',
    weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'beat' },
  },
  ['pmediora_bulletextractionkit'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bulletextractionkit.png' },
    label = '摘出キット', englishLabel = 'Bullet Extraction Kit', description = '患部から弾丸を安全に摘出する',
    weight = 500, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'shot', clearBleeding = true, healPercent = 15 },
  },
  ['pmediora_surgicalforceps'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_surgicalforceps.png' },
    label = 'ピンセット', englishLabel = 'Surgical Forceps', description = '患部から弾丸を取り除くが、たまに出血してしまう',
    weight = 150, stack = true, buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'treat_injury', injury = 'shot', bleedingChance = 0.30 },
  },
  ['pmediora_suturekit'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_suturekit.png' },
    label = '縫合キット', englishLabel = 'Suture Kit', description = '患部を安全に縫合する',
    weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'stabbed', clearBleeding = true, healPercent = 15 },
  },
  ['pmediora_needleandthread'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_needleandthread.png' },
    label = '針と糸', englishLabel = 'Needle and Thread', description = '患部を縫い付けるが、たまに出血してしまう',
    weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
    effect = { type = 'treat_injury', injury = 'stabbed', bleedingChance = 0.30 },
  },
  ['pmediora_burncream'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_burncream.png' },
    label = '火傷クリーム', englishLabel = 'Burn Cream', description = '火傷の炎症を抑える薬',
    weight = 150, stack = true, buyPrice = 100000, sellPrice = 20000,
    effect = { type = 'treat_injury', injury = 'burned' },
  },
  ['pmediora_coolingspray'] = {
    label = '冷却スプレー', weight = 150, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_icepack.png' },
  },
  ['pmediora_medicatedbandage'] = {
    label = '薬品包帯', weight = 100, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_bandage.png' },
  },
  ['pmediora_protectivecast'] = {
    label = '保護ギプス', description = '骨折した部位を補強して治療する', weight = 300, stack = true, close = true, consume = 0,
    buyPrice = 15000, sellPrice = 3000,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_splint.png' },
  },
  ['pmediora_painkiller'] = {
    label = '鎮痛剤', weight = 30, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png', export = 'ptech_mediora_medical.useMedicalItem' },
  },
  ['pmediora_hemostatic'] = {
    label = '止血剤', weight = 30, stack = true, close = true, consume = 0,
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_firstaidkit.png', export = 'ptech_mediora_medical.useMedicalItem' },
  },
  ['pmediora_ivdrip'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_ivdrip.png' },
    label = '点滴', description = '医療職が餓死・溺死の患者に使用する。餓死では空腹も回復する。',
    weight = 300, stack = true, close = true, consume = 0,
  },
  ['pmediora_herb'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_herb.png' },
    label = '薬草', englishLabel = 'EMS Herb', description = '摘んできた薬草。雑草ではない',
    weight = 50, stack = true, usable = false,
  },
  ['pmediora_water'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_water.png' },
    label = '水', englishLabel = 'EMS Water', description = '汲んだ水。飲むのはちょっと',
    weight = 500, stack = true, usable = false,
  },
  ['pmediora_purifiedwater'] = {
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_medical/install/ox_inventory/images/pmediora_purifiedwater.png' },
    label = '精製水', englishLabel = 'EMS Purified Water', description = '精製された水。医療に使用できる',
    weight = 500, stack = true, usable = false,
  },
