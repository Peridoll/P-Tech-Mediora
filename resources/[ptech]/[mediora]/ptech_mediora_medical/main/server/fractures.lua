MedicalFractureServer = {}
local patients, limits = {}, {}

local function patient(source)
    local player = exports.qbx_core:GetPlayer(source)
    local id = player and player.PlayerData.citizenid
    if type(id) ~= 'string' or id == '' then return end
    patients[id] = patients[id] or { parts = {}, heavy = {}, revision = 0 }
    return id, patients[id]
end

local function snapshot(id, record)
    local parts = {}
    for part, severity in pairs(record.parts) do parts[part] = severity end
    return { citizenId = id, parts = parts, revision = record.revision }
end

function MedicalFractureServer.get(source)
    if MedicalWoundServer then
        local snapshot = MedicalWoundServer.get(source)
        if snapshot.error then return snapshot end
        local parts = {}
        for _, part in ipairs(MedicalWounds.parts) do
            if snapshot.state.parts[part].fracture then parts[part] = 3 end
        end
        return { citizenId = snapshot.citizenId, parts = parts, revision = snapshot.revision }
    end
    local id, record = patient(source)
    if not id then return { error = '患者情報を取得できません' } end
    return snapshot(id, record)
end

function MedicalFractureServer.observe(source, injuries, success)
    if MedicalWoundServer then return MedicalFractureServer.get(source) end
    local id, record = patient(source)
    if not id then return { error = '患者情報を取得できません' } end
    local report = Medical.report(injuries, success)
    -- 取得失敗や未知の形式を「回復した」と判断しない。
    if success ~= true or type(injuries) ~= 'table' or (next(injuries) ~= nil and #report.rows == 0) then
        return snapshot(id, record)
    end
    local heavy = Medical.deriveFractures(report.rows)
    local changed = false
    for part, severity in pairs(heavy) do
        -- 同じ重度打撲を繰り返し観察しても、治療済み骨折を再発させない。
        if (not record.heavy[part] and not record.parts[part])
            or (record.parts[part] and severity > record.parts[part]) then
            record.parts[part], changed = severity, true
        end
    end
    record.heavy = heavy
    if changed then
        record.revision = record.revision + 1
        TriggerClientEvent('ptech_mediora_medical:fractures', source, snapshot(id, record))
    end
    return snapshot(id, record)
end

lib.callback.register('ptech_mediora_medical:fractures:get', function(source, citizenId)
    local id = patient(source)
    if id ~= citizenId then return { error = 'キャラクターが変わりました' } end
    return MedicalFractureServer.get(source)
end)

-- 自己観察は送信者本人だけに適用。患者IDの指定や骨折解除は受け付けない。
lib.callback.register('ptech_mediora_medical:fractures:observe', function(source, citizenId, injuries, success)
    local id = patient(source)
    if id ~= citizenId then return { error = 'キャラクターが変わりました' } end
    local now, previous = GetGameTimer(), limits[source]
    if previous and previous.id == id and now - previous.time < Config.Fracture.ObserveInterval / 2 then
        return MedicalFractureServer.get(source)
    end
    limits[source] = { id = id, time = now }
    return MedicalFractureServer.observe(source, injuries, success)
end)

-- 本番の治療処理から呼ぶサーバー専用口。クライアントへ解除イベントは公開しない。
-- 打撲の治療とは別に、骨折の治療が成功した段階でのみ利用する。
exports('clearFractures', function(source, part)
    if MedicalWoundServer then return MedicalWoundServer.clearFractures(source, part) end
    local id, record = patient(source)
    if not id then return false end
    if part ~= nil then
        local valid = false
        for _, allowed in ipairs(Medical.fractureParts) do if part == allowed then valid = true end end
        if not valid then return false end
        record.parts[part] = nil
    else
        record.parts = {}
    end
    record.revision = record.revision + 1
    TriggerClientEvent('ptech_mediora_medical:fractures', source, snapshot(id, record))
    return true
end)

exports('getFractures', MedicalFractureServer.get)
AddEventHandler('playerDropped', function() limits[source] = nil end)
