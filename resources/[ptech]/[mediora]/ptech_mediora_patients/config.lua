Config = {
    Jobs = { ambulance = true },
    RequireDuty = true,
    Debug = false,
    InteractionDistance = 3.0,
    Hospital = vec3(309.15, -585.30, 43.28),
    Patients = {
        { label = '体調不良の患者', model = 'a_m_m_business_01',
          coords = vec4(335.15, -571.50, 43.28, 185.0), case = 'minor' },
        { label = '腕を負傷した患者', model = 'a_m_y_business_02',
          coords = vec4(298.15, -598.20, 43.28, 65.0), case = 'injury' },
    },
    Cases = {
        minor = { label = '体調不良', description = '問診と経過観察', duration = 5000 },
        injury = { label = '上肢の負傷', description = '患部の観察と応急処置', duration = 6500 },
    },
    JobCooldownMs = 10000,
    Test = {
        Command = 'mpatienttest',
        Model = 'a_m_m_business_01',
        SpawnDistance = 2.0,
        Presets = {
            { id = 'healthy', label = '無傷', death = false, injuries = {} },
            { id = 'injured', label = '負傷：銃創・打撲', death = false, injuries = {
                left_arm = { type = 'shot', data = { level = 2, bleed = 1 } },
                upper_body = { type = 'beat', data = { level = 1, bleed = 0 } },
            } },
            { id = 'laststand', label = '瀕死', death = 'laststand', injuries = {
                upper_body = { type = 'stabbed', data = { level = 3, bleed = 3 } },
            } },
            { id = 'dead', label = '死亡', death = 'dead', injuries = {
                head = { type = 'shot', data = { level = 4, bleed = 4 } },
            } },
            { id = 'unknown', label = 'データ未取得', death = 'unknown' },
        },
    },
}
