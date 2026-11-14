-- 負傷モデル。FiveMのAPIに依存しない共通の負傷モデル。
MedicalWounds = {}
local W = MedicalWounds
W.parts = { 'head', 'upper_body', 'lower_body', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }
W.labels = { blunt = '打ち身', bruise = '打撲', cut = '切り傷', shot = '銃創', burn = '火傷',
    pin = '通電ピン', fracture = '骨折', bleeding = '出血', starvation = '餓死', drowning = '溺死' }

function W.copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = W.copy(child) end
    return result
end

function W.validPart(part)
    for _, key in ipairs(W.parts) do if key == part then return true end end
    return false
end

function W.finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

function W.new()
    local result = { parts = {}, revision = 0, history = {} }
    for _, part in ipairs(W.parts) do result.parts[part] = { blunt = 0, sharp = 0, wounds = {} } end
    return result
end

local function bound(value) return math.max(0, math.min(Config.Wounds.Maximum, value)) end
local function floor(p)
    p.blunt = math.max(p.wounds.bruise and Config.Wounds.BruiseFloor or 0, bound(p.blunt))
    p.sharp = bound(p.sharp)
end
local function roll(chance, random)
    return (random or function() return math.random() * 100 end)() < math.max(0, math.min(100, chance))
end

-- pct は「最大の行動可能HPに対して失った割合」。診察でこの関数は呼ばない。
function W.damage(state, part, kind, pct, fatal, random)
    if not W.validPart(part) or not W.finite(pct) or pct < 0 or pct > 100 then return nil end
    if kind ~= 'blunt' and kind ~= 'cut' and kind ~= 'shot' and kind ~= 'burn' and kind ~= 'pin' then return nil end
    local p, settings, notices = state.parts[part], Config.Wounds, {}
    if pct == 0 and kind ~= 'pin' and not fatal then return nil end
    local function announce(symptom) notices[#notices + 1] = { part = part, symptom = symptom } end
    if kind == 'blunt' then
        p.bluntRecoveryAt = nil
        if not p.wounds.bruise then p.wounds.blunt = true end
        p.blunt = bound(p.blunt + pct)
    elseif kind == 'cut' then
        p.wounds.cut = true
        p.sharp = bound(p.sharp + pct)
    elseif kind == 'shot' then
        p.wounds.shot = true
        p.blunt = bound(p.blunt + pct * settings.ShotBlunt)
        p.sharp = bound(p.sharp + pct * settings.ShotSharp)
    elseif kind == 'burn' then
        if not p.wounds.burn then p.sharp = bound(p.sharp + settings.BurnBonus) end
        p.wounds.burn = true
    else
        p.wounds.pin = true
    end
    if kind == 'blunt' or kind == 'shot' then
        if (fatal and kind == 'blunt') or roll(p.blunt - settings.BruiseOffset, random) then
            local first = not p.wounds.bruise
            p.wounds.bruise, p.wounds.blunt = true, nil
            p.bluntRecoveryAt = nil
            p.blunt = bound(p.blunt + settings.BruiseBonus) -- 再当選でも毎回＋5
            floor(p)
            if first and not fatal then announce('bruise') end
            if roll(p.blunt - settings.FractureOffset, random) then
                local changed = not p.fracture or p.fracture == 'suppressed'
                local suppressed = p.fracture == 'suppressed'
                p.fracture = 'active'
                if changed then announce(suppressed and 'fractureRelapse' or 'fracture') end
            end
        end
    end
    if kind == 'cut' or kind == 'shot' then
        -- 最終資料では鈍症値を指定。設定で明示し、鋭症へ勝手に読み替えない。
        local chance = p[settings.BleedingBasis] or 0
        if p.bleeding == 'suppressed' then chance = chance + settings.SuppressedBleedBonus end
        if (fatal and kind == 'cut') or roll(chance, random) then
            local changed = not p.bleeding or p.bleeding == 'suppressed'
            local suppressed = p.bleeding == 'suppressed'
            p.bleeding = 'active'
            p.sharp = bound(p.sharp + settings.BleedBonus)
            if changed and not fatal then announce(suppressed and 'bleedingRelapse' or 'bleeding') end
        end
    end
    floor(p)
    state.revision = state.revision + 1
    return notices
end

function W.decay(state, minutes)
    if not W.finite(minutes) or minutes <= 0 then return end
    for _, p in pairs(state.parts) do
        p.blunt, p.sharp = p.blunt - Config.Wounds.Decay * minutes, p.sharp - Config.Wounds.Decay * minutes
        floor(p)
    end
    state.revision = state.revision + 1
end

function W.expireBlunt(state, now)
    local changed = false
    for _, p in pairs(state.parts) do
        if p.bluntRecoveryAt and now >= p.bluntRecoveryAt then
            p.bluntRecoveryAt = nil
            if p.wounds.blunt then
                p.wounds.blunt = nil
                changed = true
            end
        end
    end
    if changed then state.revision = state.revision + 1 end
    return changed
end

function W.medication(state, full)
    local recoverAt = full and os.time() + Config.Wounds.BluntRecoverySeconds
    for _, p in pairs(state.parts) do
        p.blunt, p.sharp = p.blunt / 2, p.sharp / 2
        if full then
            p.wounds.cut = nil
            if p.wounds.blunt then p.bluntRecoveryAt = p.bluntRecoveryAt or recoverAt end
        end
        floor(p)
    end
    state.revision = state.revision + 1
end

function W.level(p, kind)
    if kind == 'blunt' then return p.blunt > Config.Wounds.BluntThreshold and 2 or 1 end
    if kind == 'bruise' then return p.blunt > Config.Wounds.BruiseThreshold and 4 or 3 end
    if kind == 'cut' then return p.sharp > Config.Wounds.CutThreshold and 2 or 1 end
    return 1 -- 資料に段階の指定がない銃創・火傷・通電ピンは1段階
end

local testWoundKinds = { blunt = true, bruise = true, cut = true, shot = true, burn = true, pin = true }

function W.addTestInjury(state, part, kind, level)
    if not W.validPart(part) then return false, '部位の指定が無効です' end
    local p, config = state.parts[part], Config.Wounds
    if kind == 'fracture' or kind == 'bleeding' then
        if level and level ~= 'active' and level ~= 'suppressed' then
            return false, '骨折・出血の状態は active または suppressed を指定してください'
        end
        p[kind] = level or 'active'
    elseif testWoundKinds[kind] then
        local threshold = ({ blunt = config.BluntThreshold, bruise = config.BruiseThreshold, cut = config.CutThreshold })[kind]
        if level and (not threshold or (level ~= 'light' and level ~= 'heavy')) then
            return false, '重さは打ち身・打撲・切り傷に light または heavy を指定できます'
        end
        if kind == 'blunt' and p.wounds.bruise then return false, '同じ部位に打撲があります' end
        if threshold then
            local accumulation = kind == 'cut' and 'sharp' or 'blunt'
            local current = p[accumulation]
            p[accumulation] = level == 'heavy' and math.max(current, threshold + 1)
                or math.max(1, math.min(current, threshold))
        end
        if kind == 'bruise' then p.wounds.blunt = nil end
        if kind == 'blunt' or kind == 'bruise' then p.bluntRecoveryAt = nil end
        p.wounds[kind] = true
    else
        return false, '傷の種類が無効です'
    end
    floor(p)
    state.revision = state.revision + 1
    return true
end

function W.rows(state)
    local rows = {}
    if state.ivCondition then
        rows[#rows + 1] = { part = 'upper_body', body = '-', kind = state.ivCondition,
            severity = 1, bleed = 0, model = 'medical' }
    end
    for _, part in ipairs(W.parts) do
        local p = state.parts[part]
        for _, kind in ipairs({ 'blunt', 'bruise', 'cut', 'shot', 'burn', 'pin' }) do
            if p.wounds[kind] then
                rows[#rows + 1] = { part = part, kind = kind, severity = W.level(p, kind),
                    bleed = p.bleeding and 1 or 0, blunt = p.blunt, sharp = p.sharp, model = 'medical' }
            end
        end
        for _, kind in ipairs({ 'fracture', 'bleeding' }) do
            if p[kind] then rows[#rows + 1] = { part = part, kind = kind, severity = 1,
                bleed = kind == 'bleeding' and 1 or 0, suppressed = p[kind] == 'suppressed', model = 'medical' } end
        end
    end
    return rows
end

-- 消費前の見積もり。単一部位・単一道具で、対応する複数症状を一度に処置する。
function W.plan(state, part, name)
    local item, p = Config.Wounds.Items[name], state.parts[part]
    if not W.validPart(part) or not item or not p then return nil, '部位と道具を確認してください' end
    local actions, units = {}, 0
    for _, kind in ipairs(item.kinds or {}) do
        if kind == 'blunt' then
            if p.wounds.bruise then actions.bruise, units = true, math.max(units, W.level(p, 'bruise'))
            elseif p.wounds.blunt then actions.blunt, units = true, math.max(units, W.level(p, 'blunt')) end
        elseif p.wounds[kind] then actions[kind], units = true, math.max(units, W.level(p, kind)) end
    end
    if item.fracture and p.fracture then actions.fracture, units = true, math.max(units, 1) end
    if item.bleeding and p.bleeding then actions.bleeding, units = true, math.max(units, 1) end
    local suppressionParts = {}
    for _, key in ipairs(W.parts) do
        local target = state.parts[key]
        if item.suppressFracture and target.fracture == 'active' then
            actions.suppressFracture, units = true, 1
            suppressionParts[#suppressionParts + 1] = key
        elseif item.suppressBleeding and target.bleeding == 'active' then
            actions.suppressBleeding, units = true, 1
            suppressionParts[#suppressionParts + 1] = key
        end
    end
    if item.heal then actions.heal, units = item.heal, math.max(units, 1) end
    if item.ivRecovery and part == 'upper_body' and item.ivRecovery[state.ivCondition] then
        actions.iv, units = state.ivCondition, math.max(units, 1)
    end
    if units == 0 then return nil, 'その道具で処置する症状がありません' end
    local count = math.ceil(units / (item.power or 1))
    return { part = part, item = name, label = item.label, actions = actions, count = count, suppressionParts = suppressionParts,
        duration = (item.duration or Config.Wounds.TreatmentDuration) * count }
end

-- 同時に止血する道具では、対象の傷に対応する演出を優先する。
function W.treatmentMotion(plan)
    local actions = plan.actions
    if actions.iv then return 'infusion' end
    if actions.shot or actions.pin then return 'extraction' end
    if actions.cut then return 'suture' end
    if actions.burn then return 'burnCare' end
    if actions.fracture or actions.suppressFracture then return 'splint' end
    if actions.blunt or actions.bruise then return 'cooling' end
    return 'treatment'
end

function W.treat(state, plan, full)
    local p, a = state.parts[plan.part], plan.actions
    for _, kind in ipairs({ 'blunt', 'bruise', 'cut', 'shot', 'burn', 'pin' }) do
        if a[kind] then p.wounds[kind] = nil end
    end
    if a.fracture then p.fracture = nil end
    if a.bleeding then p.bleeding = nil end
    for _, key in ipairs(plan.suppressionParts or { plan.part }) do
        local target = state.parts[key]
        if a.suppressFracture and target.fracture == 'active' then target.fracture = 'suppressed' end
        if a.suppressBleeding and target.bleeding == 'active' then target.bleeding = 'suppressed' end
    end
    if a.blunt then p.bluntRecoveryAt = nil end
    if a.blunt or a.bruise or a.fracture then p.blunt = math.min(p.blunt, Config.Wounds.TreatmentRiskMax) end
    if a.cut or a.shot or a.bleeding then p.sharp = math.min(p.sharp, Config.Wounds.TreatmentRiskMax) end
    if a.heal then W.medication(state, full) end
    if a.iv then state.ivCondition = nil end
    floor(p)
    state.revision = state.revision + 1
end

function W.active(state, symptom)
    for _, part in ipairs(W.parts) do if state.parts[part][symptom] == 'active' then return part end end
end
