Config = {
    Jobs = { ambulance = 0 },
    Hospital = vec3(309.15, -585.3, 42.28), -- 指定された受注・納品地点
    StashCoords = vec3(309.15, -585.3, 42.28),
    Stash = { id = 'ptech_hospital_pharma', label = '病院製薬素材倉庫', slots = 60, weight = 200000 },
    Suppliers = {
        { label = '港湾物流拠点', coords = vec3(1200.0, -3115.0, 5.54) },
    }, -- 追加時は受注ごとにランダムに一か所を選択
    MaxOrders = 1,
    CargoItem = 'ptech_medical_cargo',
    ReceiptItem = 'ptech_medical_receipt',
    Material = 'ptech_pharma_base',
    MaterialCount = 10,
    ReceiptAmount = 200000, -- 精算予定額。ここでは支払わない
    Duration = 5000,
    Radius = 3.0,
    Bucket = 0,
    -- 旧Reward / Progressionはarchive/config.luaのコメント内に保存。
}

