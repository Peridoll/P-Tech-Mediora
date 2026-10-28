Config = {}

Config.Framework = 'qbx_core'
Config.Inventory = 'ox_inventory'

-- The EMS job name and point coordinates are server-specific settings.
Config.AllowedJobs = { ambulance = true }
Config.RequireOnDuty = true

Config.Procurement = {
    cooldownSeconds = 15 * 60,
    minItems = 5,
    maxItems = 10,
    maxDeliveries = 300,
    boxItem = 'ptech_mediora_supply_box',
    specialBoxItem = 'ptech_mediora_special_box',
    interactDistance = 2.0,
    markerDistance = 20.0,
    markerType = 2,
    markerScale = vector3(0.35, 0.35, 0.35),
}

-- Initial balancing values are provisional and can be tuned without code changes.
Config.Economy = {
    moneyType = 'cash',
    maxTransactionItems = 100,
    unopenedBoxSellMultiplier = 1.20,
    specialBoxSellMultiplier = 1.50,
}

-- Add the chosen city renovation / supply pickup locations here.
-- Example: { id = 'construction_01', label = '工事現場 1', coords = vector3(x, y, z) }
Config.CollectionPoints = {}

-- GTA default hospitals. Add, remove, or adjust locations to match the server map.
Config.Hospitals = {
    { id = 'pillbox', label = 'Pillbox Hill Medical Center', coords = vector3(307.2, -595.3, 43.3) },
    { id = 'mount_zonah', label = 'Mount Zonah Medical Center', coords = vector3(-449.7, -340.8, 34.5) },
    { id = 'central_ls', label = 'Central Los Santos Medical Center', coords = vector3(356.8, -590.1, 28.8) },
    { id = 'sandy_shores', label = 'Sandy Shores Medical Center', coords = vector3(1839.6, 3672.9, 34.3) },
    { id = 'paleto_bay', label = 'Paleto Bay Medical Center', coords = vector3(-247.4, 6331.2, 32.4) },
}

-- Eligible medical tools that may be packed into each box.
-- Weights are relative probabilities; they do not change the agreed price list.
Config.BoxContents = {
    { item = 'ptech_medical_first_aid_kit', weight = 1 },
    { item = 'ptech_medical_bandage', weight = 4 },
    { item = 'ptech_medical_splint', weight = 2 },
    { item = 'ptech_medical_ice_pack', weight = 3 },
    { item = 'ptech_medical_bullet_extraction_kit', weight = 2 },
    { item = 'ptech_medical_surgical_forceps', weight = 3 },
    { item = 'ptech_medical_suture_kit', weight = 2 },
    { item = 'ptech_medical_needle_and_thread', weight = 3 },
    { item = 'ptech_medical_burn_cream', weight = 5 },
}

Config.Text = {
    collect = '[E] 医療物資を調達',
    deliver = '[E] この病院向けの箱を納品',
    cooldown = 'この調達地点はクールタイム中です。',
    inventoryFull = 'インベントリに空きがありません。',
    noDestinationBoxes = 'この病院に納品できる箱を持っていません。',
    deliveryCountLabel = '納品する段ボール数',
    deliveryCountDescription = 'この病院が納品先の段ボールだけを納品します。',
    deliveryCountInvalid = '納品数が所持数を超えているか、指定が正しくありません。',
    delivered = '医療物資を病院へ納品しました。',
    boxOpened = '段ボール #%s を開封しました。',
    noItemsToSell = '売却できる医療道具を持っていません。',
    noItemsForSale = '現在購入できる医療道具はありません。',
    specialUnavailable = '本日の特注レシピが設定されていません。',
    tradeInvalid = '取引内容が正しくありません。',
    purchaseDone = '医療道具を購入しました。',
    saleDone = '医療道具を売却しました。',
    specialCrafted = '本日の特注段ボールを作成しました。',
    specialExpired = '本日の特注納品先ではないため、通常価格で精算します。',
    specialPremiumPaid = '本日限定の特注納品ボーナスが適用されました。',
    insufficientFunds = '所持金が足りません。',
    missingRecipeItems = '本日のレシピに必要な医療道具が足りません。',
    hospitalMenu = '病院の物資窓口',
    menuDeliver = '段ボールを納品',
    menuSell = '医療道具を売却',
    menuBuy = '医療道具を購入',
    menuCraftSpecial = '本日の特注段ボールを作成',
    menuCraftTools = '医療道具をクラフト',
}
