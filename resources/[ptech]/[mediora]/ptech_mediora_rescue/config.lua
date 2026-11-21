Config = {}
Config.AllowedJobs = { 'police' } -- 緊急離脱できる職業。勤務中のみ。空なら使用禁止。
Config.EMSJob = 'ambulance' -- 搬送開始・到着を通知する医療職名。
Config.Countdown = 480 -- ダウン確認から使用可能になるまで（秒）。
Config.Control = 45 -- INPUT_RELOAD = Rキー。
Config.ControlLabel = 'R' -- 表示するキー名。
Config.HoldDuration = 3.0 -- 長押し秒数。暫定値。
Config.SyncInterval = 1000 -- サーバーから状態を取得する間隔（ミリ秒）。
Config.Helicopter = {
    Model = 'buzzard2', -- 非武装バザード（暫定）。
    Pilot = 's_m_m_pilot_02', -- NPCパイロットのモデル。
    Transparency = 155, -- 回収直後の不透明度（0〜255）。
    HoverOffset = 20.0, -- 回収地点より上に出す高さ（m）。屋根高度は別途探索する。
    RoofProbeHeight = 180.0, -- 真上からの衝突探索の開始高さ（m）。
    PickupSeconds = 1.0, -- ロープ回収演出時間（秒）。
    CruiseHeight = 120.0, -- 飛行先へ移動するときの目標高さ（海抜ではなく出発側補正m）。
    Speed = 35.0, -- NPC操縦による巡航指示速度。
    MaxFlightSeconds = 150, -- 到達できない場合の安全停止まで（秒）。
    LandingTimeout = 35, -- 着陸完了を待つ最大時間（秒）。
    StallSeconds = 12, -- ヘリが動かない場合に飛行指示を再発行する間隔。
    PublishAfter = 20, -- 将来の他プレイヤー表示切替時間。現段階ではローカルのみ。
}
Config.Hospital = {
    -- 以下はPillboxの仮座標。導入先の本院MLOに合わせて必ず調整する。
    Helipad = vector4(351.0, -588.0, 74.0, 160.0), -- 着陸地点。
    Entrance = vector4(298.0, -584.0, 43.0, 70.0), -- ダウン状態で配置する入口。
}
