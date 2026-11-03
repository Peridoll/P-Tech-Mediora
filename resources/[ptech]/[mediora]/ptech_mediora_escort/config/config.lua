Config = {

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 基本操作設定 】
  Key : 担ぐ／おろす共通キー（FiveMのキー設定で変更可能）
  UseTarget : ox_targetによる搬送操作を使用するか
  AcceptKey : 受け入れ中や搬送中の解除に使用するXキーのコントロールID

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  Key       = '',
  UseTarget = true,
  AcceptKey = 73, -- Xキー（FiveMコントロールID）

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 EMS専用設定 】
  EMSJobs : EMS専用機能を使用できるジョブ
  RequireDuty : EMS専用機能の使用に勤務状態を要求するか
  PDJobs : PD優先回収の対象ジョブ
  通常搬送は職業を問わず全員が利用可能

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  EMSJobs = {
    'ambulance',
  },
  RequireDuty = true,
  PDJobs = { 'police', 'sheriff' },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 距離・同期設定 】
  NormalRange : 通常搬送の操作距離(m)
  VehicleRange : EMS車内回収の検索範囲(m)
  TargetDistance : 車両に対するTargetの操作距離(m)
  BreakDistance : 搬送状態の同期異常時に使用する解除距離(m)
  SyncInterval : 搬送状態の同期監視間隔(ms)

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  NormalRange    = 3.0,
  VehicleRange   = 8.0,
  TargetDistance = 3.0,
  BreakDistance  = 12.0,
  SyncInterval   = 400,

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 車両乗降設定 】
  VehicleStopSpeed : 乗降を許可する最高速度(m/s)。走行中は操作不可
  VehicleTransferMs : ドア開閉を含めた乗降演出の合計時間(ms)
  乗降途中で車両が動いた場合は自動キャンセルする

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  VehicleStopSpeed  = 0.5,
  VehicleTransferMs = 1000,

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 対象・NPC設定 】
  ExternalBusyKeys : 外部リソースが搬送中であることを示すState Bagキー
  NPCResources : NPC搬送登録を許可するサーバーリソース
  NPCOwnerKey / NPCStatusKey : 専用NPCの状態・登録判定
  CarryableTags : 信頼できる外部リソースが設定する搬送可能State Bagキー

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  ExternalBusyKeys = {},
  NPCResources = { 'ptech_mediora_patients' },
  NPCOwnerKey = 'ptech_mediora_owner',
  NPCStatusKey = 'ptech_mediora_status',
  CarryableTags = {
    'medioraRagdoll', -- 外部リソースがtrueを設定した対象を搬送可能にする
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 搬送アニメーション設定 】
  DefaultStyle : 担ぎ方の初期値／患者側NG時のフォールバック
  CarryModes : walk / bike / swim / actionの搬送スタイル一覧
  escorter / target : 担ぐ側・担がれる側のアニメーション
  pos / rot / bone : 患者の接続座標・角度・接続ボーン
  vehicleAllowed : 車両上で使用できないスタイルは肩担ぎに切り替える
  登録順が設定メニューの表示順。アニメーションには実機未検証の試作値を含む

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  DefaultStyle = 'fireman',
  CarryModes = {
    walk = {
      {
        id             = 'fireman',
        label          = '肩担ぎ',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {-0.14, 0.15, 0.14},
        rot            = {0.0, -59.0, -4.5},
        bone           = 40269,
        vehicleAllowed = true,
      },
      {
        id             = 'princess',
        label          = 'お姫様抱っこ',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.12, 0.25, 0.47},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'piggyback',
        label          = 'おんぶ',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, -0.22, 0.55},
        rot            = {0, 0, 180},
        bone           = -1,
        vehicleAllowed = true,
      },
      {
        id             = 'underarm',
        label          = '小脇に抱える',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.4, 0, 0.22},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'rescue_drag',
        label          = '両脇から引きずる',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, -0.65, -0.35},
        rot            = {0, 0, 180},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'arm_drag',
        label          = '腕を引いて引きずる',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.33, -0.85, -0.48},
        rot            = {0, 0, 160},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'box_carry',
        label          = '荷物抱え',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, 0.41, 0.2},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'cute_cmg',
        label          = '別型お姫様抱っこ',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.2, 0.2, 0.35},
        rot            = {0, 10, 80},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'lift_me',
        label          = '抱き上げる',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, 0.35, 0.3},
        rot            = {0, 0, 70},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'overhead_lift',
        label          = '高く持ち上げる',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, 0.1, 1.2},
        rot            = {0, 0, 0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'front_lift',
        label          = '前方へ持ち上げる',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, 0.55, 0.6},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'side_hold',
        label          = '横抱き',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.45, 0.2, 0.38},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'backpack',
        label          = '背負い袋',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, -0.36, 0.77},
        rot            = {0, 0, 180},
        bone           = -1,
        vehicleAllowed = true,
      },
      {
        id             = 'assisted_walk',
        label          = '肩を貸して歩く',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.45, 0.05, -0.08},
        rot            = {0, 0, 0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'support',
        label          = '支え歩き',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {-0.45, 0.05, -0.08},
        rot            = {0, 0, 0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'rear_hold',
        label          = '後ろから抱える',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, -0.38, 0.16},
        rot            = {0, 0, 180},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'ankle_drag',
        label          = '足首を引いて運ぶ',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, -0.9, -0.65},
        rot            = {0, 0, 180},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'vertical_shoulder',
        label          = '肩に縦担ぎ',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.3, 0, 0.78},
        rot            = {0, 0, 0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'one_arm_lift',
        label          = '片腕で吊るす',
        escorter       = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0.54, 0, 0.17},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'baby_carry',
        label          = '赤ちゃん抱っこ',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
        target         = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos            = {0, 0.32, 0.42},
        rot            = {0, 0, 90},
        bone           = -1,
        vehicleAllowed = false,
      },
    },
    bike   = {},
    swim   = {},
    action = {},
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 通知・表示文言 】
  Text : ox_lib通知などに使用する表示文言
  既存処理から参照されるキー名は変更しない

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  Text = {
    noTarget  = '近くに搬送できる相手がいません',
    busy      = 'その相手は搬送できません',
    noSeat    = '運転席以外の空席がありません',
    moving    = '走行中は患者を乗降できません',
    cancelled = '乗降処理をキャンセルしました',
  },
}
