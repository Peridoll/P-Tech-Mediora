-- サーバー専用の導入先設定。必要になった場合のみ差し替える。
MarineServer = {}

-- 独自water.xml等の信頼できる水域データを持つ導入先用。
-- function(coords, bucket) -> surfaceZ または nil（水域でない）。
-- 未設定時は患者クライアントの水面観測を座標・深さと照合する。
-- この既定方式では改造クライアントの水域偽装を完全には排除できない。
MarineServer.WaterHeight = nil
