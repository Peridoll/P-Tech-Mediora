Config = {

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 基本操作設定 】
  Key : 担ぐ／おろす共通キー（FiveMのキー設定で変更可能）
  UseTarget : ox_targetからの操作を使用するか

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Key       = '',
  UseTarget = true,

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 EMS専用設定 】
  EMSJobs : 運転席からPDを回収できるEMSジョブ
  RequireDuty : EMSの勤務状態を要求するか
  VehiclePickup : PD一括回収の有効・無効、半径、対象ジョブ
  通常搬送は職業を問わず全員が利用可能

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  EMSJobs = {
    'ambulance',
  },
  RequireDuty = true,
  VehiclePickup = {
    Enabled   = true,
    Range     = 8.0, -- 車両中心からの検索半径(m)
    PDJobs    = { 'police', 'sheriff' },
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 距離・同期設定 】
  Distances : 通常搬送と車両周辺の操作距離(m)
  BreakDistance : 既存の同期・車両処理でも使う距離(m)
  Sync : 搬送中の監視周期と復旧待機時間(ms)

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Distances = {
    normalCarry  = 3.0,
    vehicleCarry = 8.0,
  },
  BreakDistance = 12.0,
  Sync = { Interval = 500, Timeout = 3000 },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 対象・NPC設定 】
  ExternalBusyKeys : 外部リソースが搬送中であることを示すState Bagキー
  NPCResources : NPC登録を許可するサーバーリソース
  NPCOwnerKey / NPCStatusKey : 専用NPCの状態・登録判定
  Targets : プレイヤー／NPCのダウン・死亡判定設定

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  ExternalBusyKeys = {},
  NPCResources = { 'ptech_mediora_patients' },
  NPCOwnerKey = 'ptech_mediora_owner',
  NPCStatusKey = 'ptech_mediora_status',
  -- 信頼できるサーバー側リソースが設定するState Bagキーのみ登録する。
  -- いずれかがtrueなら、ダウン・死亡していないプレイヤーも搬送可能。
  -- 全タグがfalse/nilで、ダウン・死亡でもなければ搬送解除。空配列なら無効。
  CarryableTags = {
    'medioraRagdoll',
  },
  Targets = {
    players = {
      -- Wasabiのdead State Bag / Qboxの死亡メタデータを扱う。
      down = {
        state = {
          { key = 'dead', values = { 'laststand', 1 } },
        },
        metadata = { 'inlaststand' },
      },
      dead = {
        state = {
          { key = 'dead', values = { 'dead', 2, true } },
        },
        metadata = { 'isdead' },
        healthAtOrBelow = 0,
      },
    },
    npcs = {
      down = {
        state = {
          { key = 'emsDownDummy', values = { true } },
        },
        healthAtOrBelow = false,
      },
    },
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 搬送アニメーション設定 】
  CarryModes : walk / bike / swim / actionのスタイル一覧（未登録分類は徒歩を使用）
  同じIDのfiremanを登録すると内蔵肩担ぎより優先
  escorter / target : 担ぐ側・担がれる側のアニメーション
  pos / rot : 患者の接続座標・角度
  ※ walkに標準の肩担ぎを登録。各分類にスタイルを追加可能

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  CarryModes = {
    walk = {
      {
        id          = 'fireman',
        label       = '肩に担ぐ',
        icon        = 'person-carry-box',
        description = '肩に担いで運ぶ',
        escorter    = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        target      = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        pos         = { 0.27, 0.15, 0.63 },
        rot         = { 0.5, 0.5, 180.0 },
      },
    },
    bike   = {},
    swim   = {},
    action = {},
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 通知・表示文言 】
  Text : ox_lib通知およびox_targetの表示文言
  現在のスクリプトが参照する文言のみを保持

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Text = {
    cannotNow        = '今はエスコートできません',
    tooMany          = 'これ以上は運べません',
    tooFar           = '相手から離れすぎています',
    noTarget         = '近くに設定条件を満たす相手がいません',
    noSeat           = '空いている座席がありません',
    keybind          = 'EMSキャリー',
    targetEscort     = 'エスコートする',
    targetRelease    = 'この人を離す',
    targetPutIn      = 'エスコート中の人を乗せる',
    targetTakeOut    = '乗っている人を連れ出す',
    alreadyTaken     = 'その人はすでに誰かにエスコートされています',
    putInVehicle     = '%d人を車に乗せました',
  },
}
