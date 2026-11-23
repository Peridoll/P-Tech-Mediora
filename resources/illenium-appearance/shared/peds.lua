-- NOVILL: 選べるキャラクターモデルを男性・女性のフリーモードだけに制限（動物・NPCモデルは選べない）
-- gender を指定したモデルは、キャラ作成時に選んだ性別と同じキャラだけが使える
Config.Peds = {
    pedConfig = {
        {
            gender = "Male",
            peds = {
                "mp_m_freemode_01",
            }
        },
        {
            gender = "Female",
            peds = {
                "mp_f_freemode_01",
            }
        }
    }
}
