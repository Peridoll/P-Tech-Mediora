Config = {}
Config.AllowedJobs = { 'police' } -- 緊急離脱できる職業。勤務中のみ。空なら使用禁止。
Config.EMSJob = 'ambulance' -- 搬送開始・到着を通知する医療職名。
Config.Countdown = 5 -- ダウン確認から使用可能になるまで（秒）。
Config.Key = 'R' -- Rescue専用キーバインドの初期値。FiveMのキー設定から変更可能。
Config.Control = 45 -- 長押し待機中に標準のリロード操作を抑止するためのID。
Config.ControlLabel = 'R' -- キー表示を取得できない場合の表示名。
Config.HoldDuration = 3.0 -- 長押し秒数。暫定値。
Config.SyncInterval = 1000 -- サーバーから状態を取得する間隔（ミリ秒）。
Config.SpawnTimeout = 5000 -- サーバーで機体・パイロットの生成を確認する期限（ミリ秒）。
Config.RequestTimeout = 15000 -- 長押し完了後に要請応答を待つ期限（ミリ秒）。
Config.PreparationTimeout = 30000 -- 要請受理から搭乗確認までの期限（ミリ秒）。
Config.Helicopter = {
    TestDuration = 60.0, -- ヘリ搬送演出の上限（秒）。
    ArrivalRadius = 45.0, -- ヘリポート上空の到着判定に使う水平半径（m）。
    PassengerSeat = 0, -- 操縦士は-1、プレイヤーは助手席0。
    Model = 'maverick', -- 搭乗テスト用の非武装ヘリ。
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
    PublishAfter = 20, -- 要請から他プレイヤーへ機体を公開するまで（秒）。
}
Config.Hospital = {
    -- 以下はPillboxの仮座標。導入先の本院MLOに合わせて必ず調整する。
    Helipad = vector4(351.0, -588.0, 74.0, 160.0), -- 着陸地点。
    Entrance = vector4(302.4, -585.78, 42.27, 70.0), -- 搬送後の出現地点と向き。
}

Config.TransportBucketBase = 20000 -- 搬送専用のルーティングバケット番号の起点。
