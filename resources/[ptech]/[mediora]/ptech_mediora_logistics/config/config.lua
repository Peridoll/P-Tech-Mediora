Config = {}

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
  boxItem          = 'ptech_mediora_supply_box',      -- 通常段ボールのアイテム名
  specialBoxItem   = 'ptech_mediora_special_box',     -- 特注段ボールのアイテム名
  interactDistance = 2.0,                             -- インタラクト可能距離
  markerDistance   = 20.0,                            -- マーカーの描画距離
  markerType       = 2,                               -- マーカーの種類
  markerScale      = vector3(0.35, 0.35, 0.35),       -- マーカーの大きさ
  scanIntervalMs   = 750,                             -- 収集地点・病院の再探索間隔（ミリ秒）。マーカーは毎フレーム描画
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
Config.CollectPoints = {
  { id = 'collect_point_01', coords = vector3(100.0, 200.0, 30.0), label = '物資回収地点 1' }, -- 仮１：本番使用前に変更
  { id = 'collect_point_02', coords = vector3(150.0, 250.0, 35.0), label = '物資回収地点 2' }, -- 仮２：本番使用前に変更
  { id = 'collect_point_03', coords = vector3(200.0, 300.0, 40.0), label = '物資回収地点 3' }, -- 仮３：本番使用前に変更
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 病院の設定 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 病院の設定。座標はゲーム内で入口・高さを確認すること。
Config.Hospitals = {
  { id = 'pillbox',         coords = vector3(307.2,   -595.3,   43.3 ), label = 'ピルボックスヒル医療センター' },
  { id = 'eclipse',         coords = vector3(-676.98, 310.68,   83.08), label = 'エクリプス医療センター' },
  { id = 'mount_zonah',     coords = vector3(-449.7,  -340.8,   34.5 ), label = 'マウント・ゾナ医療センター' },
  { id = 'central_ls',      coords = vector3(295.83,  -1446.94, 29.97), label = 'セントラル医療センター' },
  { id = 'st_fiacre',       coords = vector3(1151.21, -1529.62, 35.37), label = 'セント・フィアクレ病院' },
  { id = 'portola_trinity', coords = vector3(-874.64, -307.71,  39.58), label = 'ポートラ・トリニティ医療センター' },
  { id = 'sandy_shores',    coords = vector3(1839.6,  3672.9,   34.3 ), label = 'サンディ・ショアーズ医療センター' },
  { id = 'paleto_bay',      coords = vector3(-247.4,  6331.2,   32.4 ), label = 'パレト・ベイ医療センター' },
}


--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 段ボールに封入される道具 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 各段ボールに封入される可能性のある医療道具の設定
-- weight: 封入される確率（数値が大きいほど出現しやすい）
Config.BoxContents = {
  { item = 'ptech_medical_first_aid_kit',         weight = 2 }, -- 救急キット
  { item = 'ptech_medical_bandage',               weight = 4 }, -- 包帯
  { item = 'ptech_medical_splint',                weight = 1 }, -- 副木
  { item = 'ptech_medical_ice_pack',              weight = 3 }, -- 冷却パック
  { item = 'ptech_medical_bullet_extraction_kit', weight = 1 }, -- 弾丸除去キット
  { item = 'ptech_medical_surgical_forceps',      weight = 3 }, -- ピンセット
  { item = 'ptech_medical_suture_kit',            weight = 1 }, -- 縫合キット
  { item = 'ptech_medical_needle_and_thread',     weight = 3 }, -- 針と糸
  { item = 'ptech_medical_burn_cream',            weight = 2 }, -- 火傷用クリーム
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
