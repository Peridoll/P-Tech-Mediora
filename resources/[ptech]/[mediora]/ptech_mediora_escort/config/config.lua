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
        escorter       = { dict = 'amnilka@photopose@couple@couplefirst', anim = 'amnilka_couple_mal_002', flag = 51 },
        target         = { dict = 'amnilka@photopose@couple@couplefirst', anim = 'amnilka_couple_fem_002', flag = 33 },
        pos            = {0.0, 0.0, 0.0},
        rot            = {0.0, 0.0, 0.0},
        bone           = 0,
        vehicleAllowed = 'bike',
      },
      {
        id             = 'piggyback',
        label          = 'おんぶ',
        escorter       = { dict = 'mx@piggypack_a', anim = 'mxclip_a', flag = 51 },
        target         = { dict = 'mx@piggypack_b', anim = 'mxanim_b', flag = 1 },
        pos            = {0.0200, -0.4399, 0.4200},
        rot            = {0.0, 0.0, 0.0},
        bone           = 0,
        vehicleAllowed = false,
      },
      {
        id             = 'hostage',
        label          = '人質',
        escorter       = { dict = 'anim@gangops@hostage@', anim = 'perp_idle', flag = 51 },
        target         = { dict = 'anim@gangops@hostage@', anim = 'victim_idle', flag = 1 },
        pos            = {-0.3, 0.1, 0.0},
        rot            = {0.0, 0.0, 0.0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'lionking',
        label          = 'サボテン',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 51 },
        target         = { dict = 'missfam5_yoga', anim = 'a2_pose', flag = 51 },
        pos            = {0.0, 0.48, 0.70},
        rot            = {0.0, 0.0, 0.0},
        bone           = -1,
        vehicleAllowed = false,
      },
      {
        id             = 'baby',
        label          = '赤ちゃん',
        escorter       = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 51 },
        target         = { dict = 'amb@code_human_in_car_idles@generic@ps@base', anim = 'base', flag = 1 },
        pos            = {0.350, 0.15, -0.15},
        rot            = {-42.50, -22.50, 22.50},
        bone           = 28252,
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
