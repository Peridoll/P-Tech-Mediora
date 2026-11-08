Config = {}

-- Coreのバー形状。standard / slim / segmented。
Config.ProgressBarStyle = 'segmented'

-- このリソース内のSVGを指定。省略するとCoreの汎用演出を使います。
Config.ProgressAnimations = {
  logistics = 'main/ui/progress/logistics.svg',
  boxOpening = 'main/ui/progress/logistics-open.svg',
}

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

【 既存リソースとの連携設定 】
｜その他大型リソースとの連携の際の設定

Framework：どのフレームワークを使用するか
  現行実装は qbx_core に対応（文字列の変更のみで qb_core に切り替わるわけではない）
Inventory：どのインベントリシステムを使用するか
  現行実装は ox_inventory に対応（文字列の変更のみで qb_inventory に切り替わるわけではない）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
Config.Framework = 'qbx_core'
Config.Inventory = 'ox_inventory'


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 EMSの利用権限 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 許可されたジョブの設定
Config.AllowedJobs = { ambulance = true }
Config.RequireOnDuty = true


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 調達関連の設定 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
Config.Procurement = {
  cooldownSeconds  = 15 * 60,                         -- 同じプレイヤー・同じ収集地点でのクールタイム（秒）
  minItems         = 5,                               -- 1回の調達で入手できる最小アイテム数
  maxItems         = 10,                              -- 1回の調達で入手できる最大アイテム数
  maxDeliveries    = 300,                             -- 最大配達回数
  collectDurationMs = 5000,                           -- 物資回収の所要時間（ミリ秒）
  boxOpenDurationMs = 5000,                           -- 段ボールの開封所要時間（ミリ秒）
  boxItem          = 'pmediora_supplybox',      -- 通常段ボールのアイテム名
  specialBoxItem   = 'pmediora_specialbox',     -- 特注段ボールのアイテム名
  interactDistance = 2.0,                             -- インタラクト可能距離
  markerDistance   = 20.0,                            -- マーカーの描画距離
  propDisplayDistance = 10.0,                         -- 回収オブジェクトが見える距離（m）
  markerType       = 2,                               -- マーカーの種類
  markerScale      = vector3(0.35, 0.35, 0.35),       -- マーカーの大きさ
  scanIntervalMs   = 750,                             -- 収集地点・病院の再探索間隔（ミリ秒）。マーカーは毎フレーム描画
  -- 出現率は％。倍率と確率は運用開始前の仮置きなので、運用しながら調整する。
  -- rarityChance は C / UC / R / SR / UR の合計を100にする。
  gradeProfiles = { -- 収集地点のグレードごとの抽選・報酬設定
    [1] = {
      itemCountMultiplier = 1.00, -- 基準の取得個数に掛ける倍率
      sellMultiplier      = 1.00, -- 箱・中身の売却額に掛ける倍率
      rarityChance        = { C = 75, UC = 20, R = 4,  SR = 1,  UR = 0 },
    },
    [2] = {
      itemCountMultiplier = 1.15,
      sellMultiplier      = 1.15,
      rarityChance        = { C = 65, UC = 24, R = 8,  SR = 2,  UR = 1 },
    },
    [3] = {
      itemCountMultiplier = 1.30,
      sellMultiplier      = 1.30,
      rarityChance        = { C = 50, UC = 28, R = 14, SR = 6,  UR = 2 },
    },
    [4] = {
      itemCountMultiplier = 1.50,
      sellMultiplier      = 1.50,
      rarityChance        = { C = 38, UC = 30, R = 20, SR = 9,  UR = 3 },
    },
    [5] = {
      itemCountMultiplier = 1.75,
      sellMultiplier      = 1.75,
      rarityChance        = { C = 25, UC = 30, R = 25, SR = 15, UR = 5 },
    },
  },
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 経済関連の設定 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
Config.Economy = {
  moneyType                 = 'cash', -- 使用する通貨の種類（'cash' または 'bank'）
  maxTransactionItems       = 100,    -- 1回の取引で扱える最大アイテム数
  unopenedBoxSellMultiplier = 1.20,   -- 未開封の段ボールの売却倍率
  specialBoxSellMultiplier  = 1.50,   -- 作成当日・指定納品先での特注ボーナス倍率（翌日は失効）
  tradeHospitalId           = 'pillbox', -- 医療道具を購入・売却できる病院のID（ピルボックス限定）
  fullServiceHospitalId     = 'pillbox', -- クラフトなど納品以外の機能を利用できる病院のID
  dailyHospitalMultiplier   = {      -- 病院別・日替わり納品倍率（通常・特注両方に適用）
    min  = 0.80,                     -- 倍率の最低値（仮の初期値。運営で変更可）
    max  = 1.60,                     -- 倍率の最高値（仮の初期値。運営で変更可）
    step = 0.05,                     -- 倍率の変化刻み幅
  },
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 物資回収地点 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 物資回収地点の設定。地図・GPS・発見履歴には公開しない。
-- 地点はいくつでも追加できる。各IDは重複させない。
-- 地点に prop を追加すると、マーカーの代わりにオブジェクトを表示します。
-- 例: prop = { model = 'prop_cardbordbox_04a', offset = vector3(0.0, 0.0, 0.0), heading = 90.0 },
-- offset は coords からの位置差、heading は向き（度）。どちらも省略できます。
Config.CollectPoints = {
  
-- ピルボックス
  { id = 'pillbox_01',                grade = 1, coords = vector3(  311.28,  -583.42, 42.27 ), label = 'ピルボックス 01' },

-- スーパーマーケット
  { id = 'devis_mega_mall_01',        grade = 1, coords = vector3(   63.4 ,  -1728.65,  28.64 ), label = 'Devis MEGA MALL 01' }, -- 9110
  { id = 'devis_mega_mall_02',        grade = 1, coords = vector3(   55.04,  -1739.15,  28.59 ), label = 'Devis MEGA MALL 02' },
  { id = 'devis_mega_mall_03',        grade = 1, coords = vector3(   46.02,  -1749.07,  28.63 ), label = 'Devis MEGA MALL 03' },
  { id = 'devis_mega_mall_04',        grade = 1, coords = vector3(   29.06,  -1770.15,  28.61 ), label = 'Devis MEGA MALL 04' },
  { id = 'conson_self_storage_01',    grade = 2, coords = vector3(  109.13,  -1797.95,  26.08 ), label = 'Conson Self Storage 01' },

-- グレイプシード
  { id = 'grape_seed_01',             grade = 3, coords = vector3( 1927.68,   4635.52,  39.42 ), label = 'グレイプシード 01' }, -- 2019
  { id = 'grape_seed_02',             grade = 3, coords = vector3( 1673.0 ,   4958.01,  41.34 ), label = 'グレイプシード 02' }, -- 2006

-- チリアド山
  { id = 'chiliad_mountain_01', label = 'チリアド山 01', grade = 5, -- 1087
    coords = vector3( 424.27, 5613.92, 765.62 ),
    prop = { model = 'prop_cardbordbox_04a', offset = vector3(0.0, 0.0, 0.0), heading = 90.0 }
  },

-- トングバ・バレー
  { id = 'tongva_valley_01',          grade = 4, coords = vector3( -1513.64,  1523.04, 110.63 ), label = 'トングバ・バレー 01' }, -- 5017

-- ロスサントス国際空港
  { id = 'los_santos_airport_01',     grade = 2, coords = vector3(  -677.15, -2240.14,   4.81 ), label = 'ロスサントス国際空港 01' }, --10003

-- パニング
  { id = 'panning_01',                grade = 2, coords = vector3(   167.73, -2222.39,   6.24 ), label = 'パニング 01' }, -- 9023

-- エル・ブロ・ハイツ
  { id = 'el_bro_heights_01',         grade = 3, coords = vector3(  1735.6 , -1614.28, 111.44 ), label = 'エル・ブロ・ハイツ 01' }, -- 9386

-- ムリエタ・ハイツ
  { id = 'murrieta_heights_01',       grade = 5, coords = vector3( 1235.47,  -1090.27,  30.16 ), label = 'ムリエタ・ハイツ 01' }, -- XXXX

-- バートン
  { id = 'burton_01',                 grade = 3, coords = vector3( -175.0 ,   -271.07,  80.64 ), label = 'バートン 01' }, -- 7245

-- ラ・メサ
  { id = 'la_mesa_01',                grade = 3, coords = vector3(  751.22, -1259.97, 25.33 ), label = 'ラ・メサ 01' }, -- 9245


  { id = 'los_santos_theater', label = 'ロスサントスシアター', grade = 2,
    coords = vector3( 308.87, -906.93, 28.29 ),
    prop = { model = 'prop_cardbordbox_04a', offset = vector3(0.0, 0.0, 0.0), heading = 90.0 }
  },

-- その他の回収地点
  { id = 'mamas_grocery',             grade = 2, coords = vector3(   388.35,  -732.18,  28.29 ), label = 'ママズグロサリー' },
  { id = 'puerto_del_sol_yacht_club', grade = 2, coords = vector3(  -867.49, -1275.09,   4.15 ), label = 'プエルト・デル・ソル・ヨットクラブ' }
}

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 病院の設定 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 病院の設定。座標はゲーム内で入口・高さを確認すること。
Config.Hospitals = {
  { id = 'pillbox',         coords = vector3(  308.62,  -586.9 , 42.27), label = 'ピルボックスヒル医療センター' },
  { id = 'eclipse',         coords = vector3( -676.98,   310.68, 83.08), label = 'エクリプス医療センター' },
  { id = 'mount_zonah',     coords = vector3( -449.7 ,  -340.8 , 34.5 ), label = 'マウント・ゾナ医療センター' },
  { id = 'central_ls',      coords = vector3(  295.83, -1446.94, 29.97), label = 'セントラル医療センター' },
  { id = 'st_fiacre',       coords = vector3( 1151.21, -1529.62, 35.37), label = 'セント・フィアクレ病院' },
  { id = 'portola_trinity', coords = vector3( -874.64,  -307.71, 39.58), label = 'ポートラ・トリニティ医療センター' },
  { id = 'sandy_shores',    coords = vector3( 1839.6 ,  3672.9 , 34.3 ), label = 'サンディ・ショアーズ医療センター' },
  { id = 'paleto_bay',      coords = vector3( -247.4 ,  6331.2 , 32.4 ), label = 'パレト・ベイ医療センター' },
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 段ボールに封入される道具 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 各段ボールに封入される可能性のある医療道具の設定
-- weight: 同一ランク内での出現比重（数値が大きいほど出現しやすい）
Config.BoxContents = {
  { item = 'pmediora_firstaidkit',         weight = 1 }, -- 救急キット
  { item = 'pmediora_bandage',               weight = 2 }, -- 包帯
  { item = 'pmediora_splint',                weight = 1 }, -- 副木
  { item = 'pmediora_icepack',              weight = 2 }, -- 冷却パック
  { item = 'pmediora_bulletextractionkit', weight = 1 }, -- 弾丸除去キット
  { item = 'pmediora_surgicalforceps',      weight = 2 }, -- ピンセット
  { item = 'pmediora_suturekit',            weight = 1 }, -- 縫合キット
  { item = 'pmediora_needleandthread',     weight = 2 }, -- 針と糸
  { item = 'pmediora_burncream',            weight = 3 }, -- 火傷用クリーム
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 表示文言 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- ゲーム内で表示する文言を設定
Config.Text = {
    collect = '物資を回収',

    deliver = 'この病院向けの箱を納品',
    cooldown = 'この調達地点はクールタイム中です。',
    inventoryFull = 'インベントリに空きがありません。',
    collectionFailed = '物資を回収できませんでした。インベントリの空き容量と、ox_inventory/data/items.lua に pmediora_supplybox が登録されているか確認してください。',
    noDestinationBoxes = 'この病院に納品できる箱を持っていません。',
    deliveryCountLabel = '納品する段ボール数',
    deliveryCountDescription = 'この病院が納品先の段ボールだけを納品します。',
    deliveryCountInvalid = '納品数が所持数を超えているか、指定が正しくありません。',
    delivered = '医療物資を病院へ納品しました。',
    boxOpened = '段ボール #%s を開封しました。',
    boxMenu = '医療物資段ボール',
    boxNavigate = '配送先をマップに表示',
    boxOpen = '箱を開封',
    boxOpening = '医療物資段ボールを開封中...',
    boxOpenCancelled = '開封を中止しました。',
    noItemsToSell = '売却できる医療道具を持っていません。',
    noItemsForSale = '現在購入できる医療道具はありません。',
    specialUnavailable = '本日の特注レシピが設定されていません。',
    tradeInvalid = '取引内容が正しくありません。',
    purchaseDone = '医療道具を購入しました。',
    saleDone = '医療道具を売却しました。',
    specialCrafted = '本日の特注段ボールを作成しました。',
    specialExpired = '特注ボーナスの有効日を過ぎたため、特注ボーナスなしで精算します。',
    specialPremiumPaid = '本日限定の特注納品ボーナスが適用されました。',
    insufficientFunds = '所持金が足りません。',
    missingRecipeItems = '本日のレシピに必要な医療道具が足りません。',

    noCatalogItems     = '作成できるアイテムがない',
    openHospitalMenu   = '病院物資メニューを開く',
    hospitalMenu       = '病院物資メニュー',
    menuDeliver        = '物資を納品',
    menuDeliverDesc    = 'この病院が宛先の物資を納品して報酬を受け取る',
    menuCraftSpBox     = '特注物資を作成',
    menuCraftSpBoxDesc = '日替わりレシピで特注物資を作成する',
    menuBuy            = '医療道具を購入',
    menuBuyDesc        = '病院価格で医療道具を購入する',
    menuSell           = '医療道具を売却',
    menuSellDesc       = '所持している医療道具を売却する',
    menuCraftTools     = '医療道具を作成',
    menuCraftToolsDesc = 'レシピに応じて医療道具を作成する',
}
