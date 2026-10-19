
--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  EMSエスコートの設定ファイル

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config = {}



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  キー設定

  Key       ：EMSキャリー（拾う / 落とす）
  KeyOptions：オプションを開く

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.Key        = ''
Config.KeyOptions = ''



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  対応可能ジョブ指定

  EMSJobs    ：許可する医療職のジョブ名を引用符付きで列挙（空なら全ジョブ拒否）
  RequireDuty：勤務中であることを要求するかどうか（true = 勤務中のみ）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.EMSJobs = {
  'ambulance',
}
Config.RequireDuty = true



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  対象重複回避

  ExternalBusyKeys：他のリソースが使用中であることを示すキーのリスト（これらのキーが設定されている場合、エスコートは拒否される）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.ExternalBusyKeys = {}



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  エスコート可能範囲

  normalCarry  ：歩行時のピックアップ距離
  vehicleCarry ：車両時のピックアップ距離
  BreakDistance：自動解除距離（m）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.Distances = {
  normalCarry  = 3.0,
  vehicleCarry = 8.0,
}
Config.BreakDistance = 12.0

-- Foot: living/down players and living NPCs. Vehicle: down players or registered living dummies; never NPC corpses.
Config.VehiclePickup = {
  PDJobs = { 'police', 'sheriff' },
  PDJobTypes = { 'leo' },
  CarryType = 'fireman', -- All bikes and exiting with a down patient use this carry.
}



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  エスコート人数制限

  MaxPerEscorter：一人が同時に運べる人数（0 = 無制限）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.MaxPerEscorter = 1



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  運べる相手と判定キー

  Targets         ：運べる対象の種類（players = プレイヤー、npcs = NPC）

  allowNormal     ：手錠・ダウン・死亡ではない人を運べるか（歩行／待機を含む）
  allow           ：その状態の相手を運べるか
  state           ：状態キーと、有効とみなす値の組み合わせ
  metadata        ：Qboxのmetadataでtrueになっているキー（プレイヤーのみ）
  healthAtOrBelow ：体力がこの値以下なら該当。falseで体力判定を無効にする
                  ：NPCには共通のダウンキーがないため、使用中のNPCリソースに合わせてstateを追加
                  ：NPCの死体は搬送不可。専用NPCはemsDownDummyでダウン扱い。enabledがfalseならすべて拒否

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

Config.Targets = {
  players = {
    allowNormal = false,
    cuffed = {
      allow = false,
      state = {
        { key = 'cuffed',   values = { true } },
        { key = 'isCuffed', values = { true } },
      },
      metadata = {
        'ishandcuffed'
      },
    },
    down = {
      allow = true,
      state = {
        { key = 'dead',        values = { 'laststand', 1 } },
        { key = 'isDead',      values = { 'laststand', 1 } },
        { key = 'laststand',   values = { true, 1, 'laststand' } },
        { key = 'inLaststand', values = { true } },
      },
      metadata = {
        'inlaststand'
      },
    },
    dead = {
      allow = true,
      state = {
        { key = 'dead',   values = { true, 2, 'dead' } },
        { key = 'isDead', values = { true, 2, 'dead' } },
      },
      metadata = {
        'isdead'
      },
      healthAtOrBelow = 0,
    },
  },
  npcs = {
    enabled = true,
    allowNormal = false,
    down = {
      allow = true,
      state = {
        { key = 'emsDownDummy', values = { true } },
      },
      healthAtOrBelow = false,
    },
  },
}
















-- Medical placement only: defer when an on-duty PD is near the vehicle.
-- >> 医療車両の配置は、勤務中の警察官が車両の近くにいる場合に延期される。
-- PD operates through its own resource. 'disabled' explicitly opts out.
-- >> 警察官が近くにいる場合、医療車両の配置を拒否する設定
-- Config.PDPriority = {
--   mode = 'deny_medical_when_pd_near_vehicle',
--   jobs = { police = true },
--   requireDuty = true,
--   radius = 5.0,
-- }













-- ダウン体（死亡中・ダウン中）の位置
-- 必ず運ぶ人の左側。体には何もアニメをかけず、死んでいる姿勢のまま真横に並べる
-- 2人目以降も左側に少しずつずらして重ねる
Config.Dead = {
    x = -0.9,          -- 1人目の左右位置（マイナス = 左）
    y = 0.0,           -- 1人目の前後位置
    stepX = -0.25,     -- 2人目以降、1人ごとに左へずらす量
    stepY = -0.3,      -- 2人目以降、1人ごとに後ろへずらす量
    z = 0.0,           -- 高さの調整（体が浮く/沈むときに調整）
    heading = 0.0,     -- 体の向き（向きが合わないときは 90 / 180 / 270 を試す）
}




-- All carry types use walkCarry. Normal mode uses walkNormal.
-- A second carry falls back to normal and is checked with walkNormal.
-- 医者のオプションで選べるキャリーの種類（上から順にオプションに並ぶ）
-- escorter = 運ぶ側のアニメ（上半身のみ・歩ける）/ target = 運ばれる側のアニメ
-- pos = 運ばれる人の位置（x 左右 / y 前後 / z 上下）, rot = 体の向き
-- 体が浮く・沈む・ずれるときは pos / rot を調整する
-- キャリーできるのは同時に1人まで
Config.CarryTypes = {
  {
    id          = 'fireman', label = '肩に担ぐ', icon = 'person-carry-box',
    description = '肩に担いで運ぶ',
    escorter    = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
    target      = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
    pos         = { 0.27, 0.15, 0.63 }, rot = { 0.5, 0.5, 180.0 },
  },
  {
    id          = 'piggyback', label = 'おんぶ', icon = 'person',
    description = '背中におぶって運ぶ',
    escorter    = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
    target      = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_b', flag = 33 },
    pos         = { 0.0, -0.07, 0.45 }, rot = { 0.5, 0.5, 0.0 },
  },
  {
    id          = 'piggyback_close', label = 'おんぶ：密着（比較用）', icon = 'person',
    description = '従来のおんぶアニメで背中への取り付け位置を近づけた候補',
    escorter    = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
    target      = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_b', flag = 33 },
    pos         = { 0.0, -0.15, 0.35 }, rot = { 0.5, 0.5, 0.0 },
  },
  {
    id          = 'piggyback_limp', label = 'おんぶ：ぐったり（比較用）', icon = 'person',
    description = '座り姿勢のアニメを背中に配置する試作。体の重なりを実機で確認',
    escorter    = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
    target      = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 33 },
    pos         = { 0.0, -0.25, 0.45 }, rot = { 15.0, 0.0, 0.0 },
  },
  {
    -- rubbertoe98/FiveM-Scripts/PiggyBack の取り付け位置・向きを参考にした候補。
    id          = 'piggyback_reference', label = 'おんぶ：参考設定（比較用）', icon = 'person',
    description = '公開PiggyBackスクリプトと同じ位置・180度の向きを試す候補',
    escorter    = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
    target      = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_b', flag = 33 },
    pos         = { 0.0, -0.07, 0.45 }, rot = { 0.5, 0.5, 180.0 },
  },
  {
    id          = 'bridal', label = 'お姫様抱っこ', icon = 'hand-holding-heart',
    description = '両腕で抱きかかえて運ぶ',
    escorter    = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
    target      = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 33 },
    pos         = { 0.1, 0.45, 0.1 }, rot = { 0.0, 0.0, 90.0 },
  },
  {
    id          = 'drag', label = '引きずる', icon = 'people-pulling',
    description = '床に寝かせたまま引きずって運ぶ',
    escorter    = { dict = 'combat@drag_ped@', anim = 'injured_drag_plyr', flag = 49 },
    target      = { dict = 'combat@drag_ped@', anim = 'injured_drag_ped', flag = 1 },
    pos         = { 0.0, 0.5, 0.0 }, rot = { 0.0, 0.0, 0.0 },
  },
  -- 比較用の運搬候補：専用アニメではなく既存アニメの配置バリエーション。
  {
    id = 'fireman_left', label = '肩に担ぐ：左肩（比較用）', icon = 'person-carry-box',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
    target = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
    pos = { -0.27, 0.15, 0.63 }, rot = { 0.5, 0.5, 180 },
  },
  {
    id = 'fireman_low', label = '肩に担ぐ：低め（比較用）', icon = 'person-carry-box',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
    target = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
    pos = { 0.27, 0.1, 0.48 }, rot = { 0.5, 0.5, 180 },
  },
  {
    id = 'back_horizontal', label = '背中に横抱え（比較用）', icon = 'person-carry-box',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
    target = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
    pos = { 0, -0.25, 0.55 }, rot = { 0, 0, 90 },
  },
  {
    id = 'front_sitting', label = '正面で抱える（比較用）', icon = 'hand-holding-heart',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
    target = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 33 },
    pos = { 0, 0.4, 0.15 }, rot = { 0, 0, 180 },
  },
  {
    id = 'bridal_close', label = 'お姫様抱っこ：密着（比較用）', icon = 'hand-holding-heart',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
    target = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 33 },
    pos = { 0, 0.3, 0.1 }, rot = { 0, 0, 90 },
  },
  {
    id = 'side_sitting', label = '腰の横で抱える（比較用）', icon = 'hand-holding-heart',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
    target = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 33 },
    pos = { 0.4, 0.1, 0.1 }, rot = { 0, 0, 0 },
  },
  {
    id = 'piggyback_high', label = 'おんぶ：高め（比較用）', icon = 'person',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
    target = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_b', flag = 33 },
    pos = { 0, -0.12, 0.6 }, rot = { 0.5, 0.5, 0 },
  },
  {
    id = 'drag_side', label = '引きずる：横位置（比較用）', icon = 'people-pulling',
    description = '既存アニメの位置・向きを変えた試作。実機で姿勢と重なりを確認',
    escorter = { dict = 'combat@drag_ped@', anim = 'injured_drag_plyr', flag = 49 },
    target = { dict = 'combat@drag_ped@', anim = 'injured_drag_ped', flag = 1 },
    pos = { -0.45, 0.3, 0 }, rot = { 0, 0, 25 },
  },

}



-- 手錠中の人の位置（運ぶ人の右横にまっすぐ立たせる）
Config.Side = {
    x = 0.6,           -- 1人目の左右位置（プラス = 右）
    y = 0.15,          -- 前後位置
    stepX = 0.6,       -- 2人目以降、1人ごとに右へずらす量
}




-- ox_target にも「エスコートする」「離す」「車に乗せる」「車から連れ出す」を出す
Config.UseTarget = true




Config.Text = {
    pdPriority     = '近くに勤務中のPDがいるため、医者ピックでの乗車はPDを優先します',
    keybind        = 'EMSキャリー',
    optionsKeybind = 'オプションメニューを開く',
    noTarget       = '近くに設定条件を満たす相手がいません',
    started        = 'エスコートを始めました（%d人）',
    stoppedAll     = 'エスコートをやめました',
    stoppedOne     = '1人を離しました（残り%d人）',
    beingEscorted  = 'エスコートされています',
    released       = '解放されました',
    cannotNow      = '今はエスコートできません',
    alreadyTaken   = 'その人はすでに誰かにエスコートされています',
    tooMany        = 'これ以上は運べません',
    tooFar         = '相手から離れすぎています',
    putInVehicle   = '%d人を車に乗せました',
    noSeat         = '空いている座席がありません',
    targetEscort   = 'エスコートする',
    targetRelease  = 'この人を離す',
    targetPutIn    = 'エスコート中の人を乗せる',
    targetTakeOut  = '乗っている人を連れ出す',
    optionsTitle   = 'エスコートオプション',
    carryLimit     = 'キャリーは1人までなので通常のエスコートにしました',
    optNormal      = '通常のエスコート',
    optNormalDesc  = 'ダウン体は左側、手錠中は右横に運ぶ',
    optSelected    = '【選択中】',
    modeChanged    = '次のエスコート：%s',
}

