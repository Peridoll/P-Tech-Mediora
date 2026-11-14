Hospital = {
    jobs = { ambulance = true },
    drawInterval = 5 * 60,
    cooldownStart = 'spawn', -- 'spawn' または 'complete'
    interactionDistance = 2.0,
    hospitals = {
        pillbox = {
            limit = 10,
            spots = {
                -- hane_pillbox用。現在はMedicalの受付座標を仮配置。ゲーム内で位置確認する。
                { coords = vec3(307.20, -595.36, 43.28), activity = 'floor' },
            },
        },
    },
    activities = {
        floor = { label = '床のモップ掛け', cooldown = { 5, 15 }, chance = 40, limit = 4, scenario = 'WORLD_HUMAN_JANITOR' },
        trash = { label = 'ゴミ回収', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'PROP_HUMAN_BUM_BIN' },
        bed = { label = 'ベッド清掃', cooldown = { 15, 30 }, chance = 30, limit = 3, scenario = 'WORLD_HUMAN_MAID_CLEAN' },
        equipment = { label = '医療機器点検', cooldown = { 20, 40 }, chance = 25, limit = 2, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        repair = { label = '設備修理', cooldown = { 30, 60 }, chance = 15, limit = 2, scenario = 'WORLD_HUMAN_HAMMERING' },
        window = { label = '窓拭き', cooldown = { 5, 15 }, chance = 40, limit = 4, scenario = 'WORLD_HUMAN_MAID_CLEAN' },
        lighting = { label = '照明修理', cooldown = { 30, 60 }, chance = 15, limit = 2, scenario = 'WORLD_HUMAN_HAMMERING' },
        ventilation = { label = '空調点検', cooldown = { 20, 40 }, chance = 25, limit = 2, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        resupply = { label = '医療道具の補充', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        storage = { label = '倉庫整理', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        linen = { label = 'リネン交換', cooldown = { 15, 30 }, chance = 30, limit = 3, scenario = 'WORLD_HUMAN_MAID_CLEAN' },
        paperwork = { label = '書類整理', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        charts = { label = 'カルテ整理', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        inventory = { label = '備品の棚卸し', cooldown = { 10, 20 }, chance = 35, limit = 3, scenario = 'WORLD_HUMAN_CLIPBOARD' },
    },
    duration = 8000,
    points = 1,
}
