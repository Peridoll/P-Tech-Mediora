Config = {}

Config.Fins = {
    Enabled = true,
    Item = 'ptech_rescue_fins',
    Jobs = { 'ambulance' }, -- 空配列は全員拒否。勤務中のみ。
    SwimMultiplier = 1.35, -- 1.0～1.49。走行速度・酸素には触れない。
    -- 専用フィンモデル未同梱。使用する衣装の靴(component 6)を設定する。
    -- モデル名をキーに { drawable = 実際の番号, texture = 実際の番号, palette = 0 }。
    -- 対応モデルが未設定なら外観は変えず、速度のみ適用する。
    Appearance = {},
}

-- 所持品ではない、全プレイヤー共通の水難用浮上装置。
-- 死亡／laststandをサーバーが確認した時点から Countdown 秒後、
-- その瞬間に水中または水面にいる本人だけが長押しで起動できる。
Config.Flotation = {
    Enabled = true,
    Countdown = 180, -- 秒。水中にいた時間ではなく、死亡後の経過時間。
    Control = 23, -- INPUT_ENTER（F）
    ControlLabel = 'F',
    HoldDuration = 1.0, -- 秒。誤操作を防ぐための長押し時間。
    RiseSpeed = 0.65, -- m/秒。海底からの瞬間移動は行わない。
    SurfaceOffset = -0.2,
    MaxDepth = 500.0, -- 異常な水面観測値を拒否する上限。効果時間ではない。
    ObservationTolerance = 3.0,
    SurfaceTolerance = 0.5,
    -- GTA標準の救命浮輪。各クライアントがローカル表示するため専用stream assetは不要。
    -- 位置・向きは導入サーバーで一度確認し、必要ならここだけを調整する。
    Visual = {
        Enabled = true,
        Model = 'prop_life_ring_01',
        Bone = 24818, -- SKEL_Spine3
        Offset = { x = 0.0, y = 0.0, z = 0.15 },
        Rotation = { x = 90.0, y = 0.0, z = 0.0 },
        Distance = 120.0,
    },
    -- 浮輪が見えにくい距離でも患者位置を判別できる補助リング。
    Marker = true,
}
