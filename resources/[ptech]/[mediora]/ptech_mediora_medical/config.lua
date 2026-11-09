Config = {

  -- Coreのバー形状。standard / slim / segmented。
  ProgressBarStyle = 'segmented',
  ProgressAnimations = {
    examination = 'main/ui/progress/examination.svg',
    treatment = 'main/ui/progress/treatment.svg',
    cooling = 'main/ui/progress/cooling.svg',
    suture = 'main/ui/progress/suture.svg',
    extraction = 'main/ui/progress/extraction.svg',
    burnCare = 'main/ui/progress/burn-care.svg',
    splint = 'main/ui/progress/splint.svg',
    infusion = 'main/ui/progress/infusion.svg',
    revive = 'main/ui/progress/revive.svg',
  },

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 基本設定 】

  Jobs     : 診察を許可する職業名。空の配列 {} にすると、職業制限なしで使える。
  Distance : 診察可能な距離
  Cooldown : 診察のクールダウン時間（ミリ秒）

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Jobs = {
    'ambulance'
  },
  Distance = 3.0,
  Cooldown = 1000,



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 コマンド設定 】
  ｜/pmedical diagnose [ID] を正式形とする。

  Commands
  ｜Name   : コマンド名
  ｜Action : 実行するアクション名

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Commands = {
    Name   = 'pmedical',
    Action = 'diagnose',
  },



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 ターゲット設定 】
  ｜プレイヤーを見て選ぶ入口。最終的な職業・勤務・距離・バケット判定はサーバーでも行う。

  Target
  ｜Enabled  : ターゲット診察を有効にするか
  ｜Label    : ターゲットに表示する名称
  ｜Icon     : ターゲットに表示するアイコン
  ｜Distance : ターゲットを選択できる距離

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Target = {
    Enabled  = true,
    Label    = '診察する',
    Icon     = 'fa-solid fa-stethoscope',
    Distance = 2.0,
  },



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 診察演出設定 】
  ｜診察の演出。タブレットの見た目とアニメーションは導入先で差し替えられる。

  Examination
  ｜BaseDuration     : 負傷情報が空の場合の基本時間（ミリ秒）
  ｜PerPartDuration  : 負傷1部位ごとの追加時間（ミリ秒）
  ｜MaxDuration      : 診察時間の上限（ミリ秒）
  ｜Label     : 診察中に表示する文言
  ｜Animation : 再生するアニメーション
  ｜Prop      : 手に持つ小物の設定

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Examination = {
    ChartPhoto = false, -- true: 写真・所見カード表示を使用（撮影には screenshot-basic が必要）
    BaseDuration = 1000,
    PerPartDuration = 1000,
    MaxDuration = 6000,
    Label    = '診察しています',

    Animation = {
      dict = 'amb@medic@standing@kneel@base',
      clip = 'base',
      flag = 1,
    },

    Prop = {
      model = 'prop_cs_tablet',
      pos   = { x = 0.03, y = 0.002, z = -0.02 },
      rot   = { x = 10.0, y = 160.0, z = 0.0 },
    },
  },



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 骨折設定 】
  ｜骨折は受傷時の蓄積値と抽選で発生する。診察だけでは発生しない。
  ｜転倒させる部位は下半身・左右脚。腕の照準ぶれは追加しない。

  Fracture
  ｜Severity        : 旧形式互換の重度打撲判定。新方式の抽選には使用しない
  ｜ObserveInterval : 本人識別・初回同期の再試行間隔（ミリ秒）
  ｜RagdollDuration : ジャンプ・乗り越え・登り動作で転倒する時間（ミリ秒）
  ｜RagdollCooldown : 連続転倒を抑える間隔（ミリ秒）

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Fracture = {
    Severity        = 3,
    ObserveInterval = 2000,
    RagdollDuration = 1500,
    RagdollCooldown = 3000,
  },



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 負傷・蓄積設定 】
  ｜2026-11-05最終設計。負傷はMedicalで保持し、Wasabiは死亡・蘇生を担当する。
  ｜蓄積値・抽選・治療はサーバー管理。ダメージ原因・被弾部位の検知は本人のクライアント。

  Wounds
  ｜HealthBase      : GTAの行動可能な体力の下限。通常100。割合の分母は最大HP－この値
  ｜Maximum         : 部位ごとの鈍症・鋭症蓄積値の上限
  ｜Decay           : 1分ごとに減らす蓄積値
  ｜BleedingBasis   : 出血抽選の基準。最終資料どおり blunt（鈍症）。sharpへ変更も可能
  ｜FallbackPart    : 被弾部位を取得できない場合の仮分類。正確な接触部位を保証しない
  ｜BurnBonus       : 火傷が新たに発生した時の鋭症加算。毎秒は加算しない
  ｜PinMultiplier   : 通電ピンを保持している患者の火傷ダメージ倍率
  ｜BleedDamage     : 毎秒の出血ダメージ（最大体力に対する％）。複数部位でも重複させない
  ｜TreatmentRiskMax: EMS処置後に残す蓄積値の上限。傷・骨折・出血の解除とは別
  ｜Items           : 既存Tools/Logisticsのアイテム名と効果。powerは必要個数の換算倍率
  ｜duration        : 1個分の処置時間（ミリ秒）。価格・請求はこの機能に含めない
  ｜WeaponKinds     : 武器名ごとの分類。custom武器は導入先で追記する
  ｜BoneParts       : GTAの骨IDをMedicalの7部位へまとめる対応表

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Wounds = {
    HealthBase = 100,
    Maximum = 90,
    Decay = 1,
    BluntRecoverySeconds = 15 * 60, -- 回復アイテムで全快してから打ち身が消えるまで
    BleedingBasis = 'blunt',
    FallbackPart = 'upper_body',
    BurnBonus = 10,
    PinMultiplier = 2,
    BleedDamage = 2,
    TreatmentRiskMax = 30,
    BruiseOffset = 5,
    BruiseBonus = 5,
    BruiseFloor = 30,
    FractureOffset = 30,
    BleedBonus = 5,
    SuppressedBleedBonus = 20,
    BluntThreshold = 30,
    BruiseThreshold = 60,
    CutThreshold = 20,
    ShotBlunt = 1.25,
    ShotSharp = 0.75,
    ActionDamage = 1,
    SampleInterval = 100,
    TreatmentDuration = 2000,

    Items = {
      pmediora_ivdrip              = { label = '点滴', ivRecovery = {
          starvation = { hunger = 20, thirst = 20, stress = -20 },
          drowning = {}, -- 点滴で所見のみ処置する。ステータス回復なし
      } },
      pmediora_firstaidkit        = { label = '救急キット', heal = 100 },
      pmediora_bandage              = { label = '医療用包帯', heal = 15, bleeding = true },
      pmediora_icepack             = { label = '冷却パック', kinds = { 'blunt' }, power = 1 },
      pmediora_coolingspray        = { label = '冷却スプレー', kinds = { 'blunt' }, power = 1, duration = 1000 },
      pmediora_suturekit           = { label = '縫合キット', kinds = { 'cut' }, bleeding = true, power = 1 },
      pmediora_needleandthread    = { label = '針と糸', kinds = { 'cut' }, power = 1 },
      pmediora_bulletextractionkit = { label = '弾丸摘出キット', kinds = { 'shot', 'pin' }, bleeding = true, power = 1 },
      pmediora_surgicalforceps     = { label = '医療用ピンセット', kinds = { 'shot', 'pin' }, power = 1 },
      pmediora_burncream           = { label = '火傷クリーム', kinds = { 'burn' }, power = 1 },
      pmediora_medicatedbandage    = { label = '薬品包帯', kinds = { 'burn' }, bleeding = true, power = 1 },
      pmediora_protectivecast      = { label = '保護ギプス', fracture = true },
      pmediora_painkiller           = { label = '鎮痛剤', suppressFracture = true },
      pmediora_hemostatic           = { label = '止血剤', suppressBleeding = true },
    },

    WeaponKinds = {
      WEAPON_UNARMED = 'blunt', WEAPON_NIGHTSTICK = 'blunt', WEAPON_HAMMER = 'blunt',
      WEAPON_BAT = 'blunt', WEAPON_GOLFCLUB = 'blunt', WEAPON_CROWBAR = 'blunt',
      WEAPON_KNUCKLE = 'blunt', WEAPON_FLASHLIGHT = 'blunt', WEAPON_WRENCH = 'blunt',
      WEAPON_KNIFE = 'cut', WEAPON_DAGGER = 'cut', WEAPON_BOTTLE = 'cut',
      WEAPON_HATCHET = 'cut', WEAPON_MACHETE = 'cut', WEAPON_SWITCHBLADE = 'cut',
      WEAPON_BATTLEAXE = 'cut', WEAPON_STONE_HATCHET = 'cut', WEAPON_BARBED_WIRE = 'cut',
      VEHICLE_WEAPON_ROTORS = 'cut', WEAPON_STUNGUN = 'pin', WEAPON_STUNGUN_MP = 'pin',
      WEAPON_FIRE = 'burn', WEAPON_MOLOTOV = 'burn', WEAPON_EXPLOSION = 'burn',
      WEAPON_FALL = 'blunt', WEAPON_RAMMED_BY_CAR = 'blunt', WEAPON_RUN_OVER_BY_CAR = 'blunt',
      WEAPON_HELI_CRASH = 'blunt', WEAPON_HIT_BY_WATER_CANNON = 'blunt',
      WEAPON_DROWNING = 'drowning', WEAPON_DROWNING_IN_VEHICLE = 'drowning',
    },

    BoneParts = {
      [31086] = 'head', [39317] = 'head',
      [24816] = 'upper_body', [24817] = 'upper_body', [24818] = 'upper_body',
      [0] = 'lower_body', [11816] = 'lower_body', [23553] = 'lower_body',
      [58271] = 'left_leg', [63931] = 'left_leg', [14201] = 'left_leg', [2108] = 'left_leg',
      [51826] = 'right_leg', [36864] = 'right_leg', [52301] = 'right_leg', [20781] = 'right_leg',
      [45509] = 'left_arm', [61163] = 'left_arm', [18905] = 'left_arm', [64729] = 'left_arm',
      [40269] = 'right_arm', [28252] = 'right_arm', [57005] = 'right_arm', [10706] = 'right_arm',
    },
  },



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 管理設定 】

  Debug : デバッグモードを有効にするかどうか
  UI    : 使用するUIの種類 ('nui' または 'context')

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
  Debug = false,
  UI    = 'nui',
}
