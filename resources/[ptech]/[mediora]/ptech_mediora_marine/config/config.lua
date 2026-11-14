Config = {}

-- 所持品ではない、全プレイヤー共通の水難用浮上装置。
-- 死亡／laststandをサーバーが確認した時点から Countdown 秒後、
-- その瞬間に水中または水面にいる本人だけが長押しで起動できる。
Config.Flotation = {
    Enabled = true,
    Countdown = 180, -- 秒。水中にいた時間ではなく、死亡後の経過時間。
    Control = 23, -- INPUT_ENTER（F）
    ControlLabel = 'F',
    HoldDuration = 1.0, -- 秒。誤操作を防ぐための長押し時間。
    RiseSpeed = 2.0, -- m/秒。海底からの瞬間移動は行わない。
    -- 死亡Pedの基準点を水面より上へ置き、胴体まで水没しないようにする。
    SurfaceOffset = 1.0,
    MaxDepth = 500.0, -- 異常な水面観測値を拒否する上限。効果時間ではない。
    ObservationTolerance = 3.0,
    SurfaceTolerance = 0.5,
    -- GTA標準のビーチ用浮輪。各クライアントがローカル表示するため専用stream assetは不要。
    -- prop_life_ring_01は据え置き用の大きなモデルなので使用しない。
    Visual = {
        Enabled = true,
        Model = 'prop_beach_ring_01',
        -- 腰へ通して、浮輪が上半身に載るのではなく胴回りを囲むようにする。
        Bone = 11816, -- SKEL_Pelvis
        Offset = { x = 0.0, y = 0.0, z = 0.05 },
        -- 回転なしでは正面に立ってしまう。90度倒して腰を水平に囲む。
        Rotation = { x = 0.0, y = 90.0, z = 0.0 },
        Distance = 120.0,
    },
}
