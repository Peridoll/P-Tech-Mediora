MedicalWoundServer = {}
local S, W = MedicalWoundServer, MedicalWounds
local patients, sessions, pending, locks = {}, {}, {}, {}
local sequence = 0
local starvationCause = '餓死（空腹値からの推定）'
local drowningCause = '溺死'

local function patient(src)
    local player = exports.qbx_core:GetPlayer(src)
    local id = player and player.PlayerData.citizenid
    if type(id) ~= 'string' or id == '' then return end
    patients[id] = patients[id] or W.new()
    local state = patients[id]
    local expired = W.expireBlunt(state, os.time())
    return state, id, player.PlayerData, expired
end

function S.get(src)
    local state, id = patient(src)
    if not state then return { error = '患者情報を取得できません' } end
    return { citizenId = id, revision = state.revision, state = W.copy(state) }
end

local function sync(src)
    TriggerClientEvent('ptech_mediora_medical:wounds', src, S.get(src))
end

function S.report(src)
    local state = patient(src)
    return { rows = state and W.rows(state) or {}, status = 'Medical受傷記録',
        cause = state and state.deathCause, revision = state and state.revision }
end

local function release(src)
    local task = pending[src]
    if task and locks[task.patientId] == task then locks[task.patientId] = nil end
    pending[src] = nil
end

lib.callback.register('ptech_mediora_medical:wounds:get', function(src, citizenId)
    local state, id = patient(src)
    if not state or id ~= citizenId then return { error = 'キャラクターが変わりました' } end
    local old = sessions[src]
    if not old or old.id ~= id then
        sequence = sequence + 1
        old = { id = id, token = tostring(sequence) .. ':' .. GetGameTimer() .. ':' .. math.random(100000, 999999), seq = 0 }
        sessions[src] = old
    end
    local result = S.get(src)
    result.token, result.sequence = old.token, old.seq
    return result
end)

-- 他患者の指定は受け付けない。抽選・症状・蓄積値の書き換えはサーバーだけが行う。
RegisterNetEvent('ptech_mediora_medical:damage', function(data)
    local src = source
    local state, id = patient(src)
    local session = sessions[src]
    if not state or not session or session.id ~= id or type(data) ~= 'table' or data.citizenId ~= id
        or data.token ~= session.token or not W.finite(data.sequence) or data.sequence % 1 ~= 0
        or data.sequence <= session.seq or data.sequence > session.seq + 100 then return end
    local now = GetGameTimer()
    if not session.window or now - session.window >= 1000 then session.window, session.count = now, 0 end
    session.count = session.count + 1
    if session.count > 50 then return end
    if not W.validPart(data.part) or not W.finite(data.percent) or data.percent < 0 or data.percent > 100 then return end
    session.seq = data.sequence
    local _, _, player = patient(src)
    local death = Medical.death(Player(src).state.dead, player.metadata)
    local fatal = death == '死亡' or death == '瀕死（laststand）' or GetEntityHealth(GetPlayerPed(src)) <= Config.Wounds.HealthBase
    if data.kind == 'drowning' then
        state.lastCause, state.lastCauseAt = 'drowning', now
        if fatal and not state.wasDead then state.deathCause = drowningCause end
        S.updateDeath(src)
        if state.wasDead and state.deathCause == '不明' then
            state.deathCause, state.ivCondition = drowningCause, 'drowning'
        end
        state.revision = state.revision + 1
        sync(src)
        return
    end
    local notices = W.damage(state, data.part, data.kind, data.percent, fatal)
    if not notices then return end
    state.lastCause, state.lastCauseAt, state.lastPart, state.lastFatal = data.kind, now, data.part, fatal
    if fatal then state.deathCause = W.labels[data.kind] .. 'によるダウン' end
    sync(src)
    for _, notice in ipairs(notices) do TriggerClientEvent('ptech_mediora_medical:symptom', src, notice) end
end)

-- 空腹値はQboxのサーバーメタデータから読む。外傷不明を餓死と決めつけない。
function S.updateDeath(src)
    local state, _, data = patient(src)
    if not state then return end
    local death = Medical.death(Player(src).state.dead, data.metadata)
    local dead = death == '死亡' or death == '瀕死（laststand）'
    local previousCondition = state.ivCondition
    if dead and not state.wasDead then
        local metadata = data.metadata or {}
        local test = state.starvationTestUntil and GetGameTimer() <= state.starvationTestUntil
        state.starvationTestUntil = nil
        if test and type(metadata.hunger) == 'number' and metadata.hunger <= 0 then
            state.deathCause = starvationCause
        elseif state.lastCauseAt and GetGameTimer() - state.lastCauseAt <= 5000 then
            state.deathCause = state.lastCause == 'drowning' and drowningCause or (W.labels[state.lastCause] or '不明') .. 'によるダウン'
            if not state.lastFatal and state.lastPart and (state.lastCause == 'blunt' or state.lastCause == 'cut') then
                W.damage(state, state.lastPart, state.lastCause, 0, true)
                state.lastFatal = true
                sync(src)
            end
        elseif type(metadata.hunger) == 'number' and metadata.hunger <= 0 then
            state.deathCause = starvationCause
        else state.deathCause = '不明' end
        if state.deathCause == starvationCause then state.ivCondition = 'starvation'
        elseif state.deathCause == drowningCause then state.ivCondition = 'drowning'
        else state.ivCondition = nil end
    elseif not dead then
        state.ivCondition = nil
    end
    state.wasDead = dead
    if previousCondition ~= state.ivCondition then
        state.revision = state.revision + 1
        sync(src)
    end
end

function S.canReceiveIV(src)
    local state = patient(src)
    if not state then return false end
    S.updateDeath(src)
    return state.ivCondition ~= nil
end

local function testReply(src, message, kind)
    if src == 0 then print('[ptech_mediora_medical] ' .. message); return end
    TriggerClientEvent('ox_lib:notify', src, { title = 'Medical テスト', description = message, type = kind })
end

local function testInjury(src, args)
    local target = tonumber(args[1])
    if #args < 3 or #args > 4 or not Medical.validId(target) then
        testReply(src, '使い方: /medinjury <患者ID> <部位> <傷> [重さ・状態]', 'error')
        return
    end
    local state = patient(target)
    if not state or GetPlayerPed(target) == 0 then
        testReply(src, '接続中の患者を確認してください', 'error')
        return
    end
    local part, kind, level = args[2]:lower(), args[3]:lower(), args[4]
    local ok, reason = W.addTestInjury(state, part, kind, level and level:lower())
    if not ok then testReply(src, reason, 'error'); return end
    sync(target)
    testReply(src, ('患者ID %d の %s に%sを付けました'):format(target, part, W.labels[kind]), 'success')
end

local function testDamage(src, args)
    local target, amount = tonumber(args[1]), math.tointeger(tonumber(args[2]) or 0)
    if #args ~= 2 or not Medical.validId(target) or not Medical.validId(amount) then
        testReply(src, '使い方: /meddamage <患者ID> <減らすHPの整数>', 'error')
        return
    end
    local _, id = patient(target)
    local ped = id and GetPlayerPed(target)
    if not ped or ped == 0 then
        testReply(src, '接続中の患者を確認してください', 'error')
        return
    end
    TriggerClientEvent('ptech_mediora_medical:damageTest', target, id, amount)
    testReply(src, ('患者ID %d に%d HPのダメージを指定しました'):format(target, amount), 'success')
end

RegisterCommand('medhealall', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command.medhealall') then return end
    if #args > 0 then
        testReply(src, '使い方: /medhealall', 'error')
        return
    end
    local count = 0
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local state = target and patient(target)
        if state then
            S.updateDeath(target)
            state.parts = W.new().parts
            state.ivCondition = nil
            state.lastCause, state.lastCauseAt, state.lastPart, state.lastFatal = nil, nil, nil, nil
            state.revision = state.revision + 1
            sync(target)
            count = count + 1
        end
    end
    testReply(src, ('接続中の%d人の負傷を解除しました'):format(count), 'success')
end, true)

local testCommands = { medinjury = testInjury, meddamage = testDamage }

-- ゲーム内の引数なし実行だけ画面を開く。コンソールと引数付き実行は従来どおり。
for name, apply in pairs(testCommands) do
    RegisterCommand(name, function(src, args)
        if src > 0 and #args == 0 then
            TriggerClientEvent('ptech_mediora_medical:openTestSettings', src, name)
            return
        end
        apply(src, args)
    end, true)
end

RegisterNetEvent('ptech_mediora_medical:applyTestSettings', function(name, args)
    local src = source
    local apply = type(name) == 'string' and testCommands[name]
    if not apply or not Medical.validId(src) or not IsPlayerAceAllowed(src, 'command.' .. name)
        or type(args) ~= 'table' or #args > 4 then return end
    for i = 1, #args do
        if type(args[i]) ~= 'string' or #args[i] > 24 then return end
    end
    apply(src, args)
end)

RegisterCommand('medstarve', function(src, args)
    local function reply(message, kind) testReply(src, message, kind) end

    local target = #args == 1 and tonumber(args[1])
    if not Medical.validId(target) then reply('使い方: /medstarve <患者ID>', 'error'); return end
    local state, id, data = patient(target)
    local ped = state and GetPlayerPed(target)
    if not ped or ped == 0 then reply('接続中の患者を確認してください', 'error'); return end
    local death = Medical.death(Player(target).state.dead, data.metadata)
    if death == '死亡' or death == '瀕死（laststand）' or GetEntityHealth(ped) <= Config.Wounds.HealthBase then
        reply('対象はすでにダウンしています', 'error')
        return
    end

    exports.qbx_core:SetMetadata(target, 'hunger', 0)
    state.wasDead = false
    state.starvationTestUntil = GetGameTimer() + 10000
    TriggerClientEvent('ptech_mediora_medical:starvationTest', target, id)
    reply(('患者ID %d に餓死テストを実行しました'):format(target), 'success')
end, true)

local function inventoryCount(src, item)
    if GetResourceState('ox_inventory') ~= 'started' then return 0 end
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
    return ok and type(count) == 'number' and count or 0
end

function S.busy(src)
    local _, id = patient(src)
    return id and locks[id] ~= nil
end

function S.items(src)
    local items = {}
    for name, item in pairs(Config.Wounds.Items) do
        local count = inventoryCount(src, name)
        if count > 0 then items[#items + 1] = { name = name, label = item.label, count = count } end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    return items
end

local function validate(src, target, selfUse)
    if not Medical.validId(target) or (selfUse and target ~= src) then
        return nil, '対象が無効です'
    end
    local state, id, data = patient(target)
    local _, medicId, medic = patient(src)
    if not state or not medic then return nil, '対象が退出しました' end
    if target ~= src and not Medical.allowed(medic) then return nil, '勤務中の医療職のみ利用できます' end
    local death = Medical.death(Player(src).state.dead, medic.metadata)
    if death == '死亡' or death == '瀕死（laststand）' then return nil, '行動不能中は処置できません' end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 or GetEntityHealth(a) <= Config.Wounds.HealthBase then return nil, '患者または処置者を取得できません' end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target)
        or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.Distance then return nil, '対象が処置範囲外です' end
    return { state = state, patientId = id, medicId = medicId, data = data }
end

local function usablePlan(valid, target, part, item)
    local spec = Config.Wounds.Items[item]
    if spec and spec.ivRecovery and not S.canReceiveIV(target) then
        return nil, '点滴は餓死または溺死でダウン中の患者にのみ使用できます'
    end
    local plan, err = W.plan(valid.state, part, item)
    if not plan then return nil, err end
    local death = Medical.death(Player(target).state.dead, valid.data.metadata)
    local ped = GetPlayerPed(target)
    if plan.actions.heal and (GetEntityHealth(ped) >= GetEntityMaxHealth(ped)
        or GetEntityHealth(ped) <= Config.Wounds.HealthBase or death == '死亡' or death == '瀕死（laststand）') then
        plan.actions.heal = nil
        if next(plan.actions) == nil then return nil, '体力回復が不要、または蘇生が必要な状態です' end
    end
    if plan.actions.iv then
        local changes = {}
        for key, delta in pairs(spec.ivRecovery[plan.actions.iv]) do
            local value = (valid.data.metadata or {})[key]
            if W.finite(value) then
                local updated = math.max(0, math.min(100, value + delta))
                if updated ~= value then changes[key] = updated end
            end
        end
        plan.needs = changes
    end
    return plan
end

lib.callback.register('ptech_mediora_medical:treatment:start', function(src, target, part, itemName, chartId, selfUse)
    if pending[src] then return { error = '別の処置が進行中です' } end
    local valid, err = validate(src, target, selfUse == true)
    if not valid then return { error = err } end
    local item = Config.Wounds.Items[itemName]
    if not item then return { error = '道具が無効です' } end
    -- 自己使用は薬と回復薬・止血用包帯だけ。ギプスや他部位の処置は医療職の診察から。
    if selfUse == true and not (item.heal or item.suppressFracture or item.suppressBleeding) then return { error = 'この道具は医療職の治療で使用してください' } end
    if selfUse ~= true and (not MedicalChartAccess or not MedicalChartAccess(valid.patientId, chartId)) then
        return { error = '治療できる最新のカルテを選択してください' }
    end
    if locks[valid.patientId] then return { error = '別の処置が進行中です' } end
    local plan, reason = usablePlan(valid, target, part, itemName)
    if not plan then return { error = reason } end
    if inventoryCount(src, itemName) < plan.count then return { error = ('%sが%d個必要です'):format(item.label, plan.count) } end
    sequence = sequence + 1
    local task = { token = tostring(sequence) .. ':' .. math.random(100000, 999999), target = target, patientId = valid.patientId,
        medicId = valid.medicId, plan = plan, started = GetGameTimer(), selfUse = selfUse == true,
        revision = valid.state.revision, chartId = chartId }
    pending[src], locks[valid.patientId] = task, task
    SetTimeout(plan.duration + 10000, function() if pending[src] == task then release(src) end end)
    return { token = task.token, count = plan.count, duration = plan.duration, label = plan.label,
        motion = W.treatmentMotion(plan) }
end)

lib.callback.register('ptech_mediora_medical:treatment:cancel', function(src, token)
    if pending[src] and pending[src].token == token then release(src) end
    return true
end)
RegisterNetEvent('ptech_mediora_medical:treatment:cancel', function(token)
    local src = source
    if pending[src] and pending[src].token == token then release(src) end
end)

lib.callback.register('ptech_mediora_medical:treatment:finish', function(src, token)
    local task = pending[src]
    if not task or task.token ~= token then return { error = '処置が期限切れです' } end
    local elapsed = GetGameTimer() - task.started
    local valid, err = validate(src, task.target, task.selfUse)
    if not valid or valid.medicId ~= task.medicId or valid.patientId ~= task.patientId
        or elapsed < task.plan.duration or elapsed > task.plan.duration + 10000 then
        release(src)
        return { error = err or '患者・処置者・処置時間を確認してください' }
    end
    if not task.selfUse and not MedicalChartAccess(valid.patientId, task.chartId) then
        release(src)
        return { error = 'このカルテは治療無効です' }
    end
    if valid.state.revision ~= task.revision then release(src); return { error = '患者の状態が変わりました。再確認してください' } end
    local plan = usablePlan(valid, task.target, task.plan.part, task.plan.item)
    if not plan or plan.count ~= task.plan.count then release(src); return { error = '必要な処置が変わりました' } end
    -- RemoveItemは成功時だけ。確認から状態更新までyieldを挟まず、患者ロックを保持する。
    local ok, removed = pcall(function() return exports.ox_inventory:RemoveItem(src, plan.item, plan.count) end)
    if not ok or not removed then release(src); return { error = '道具を消費できませんでした。処置は反映していません' } end
    local a = plan.actions
    local ped = GetPlayerPed(task.target)
    local max = GetEntityMaxHealth(ped)
    local before = GetEntityHealth(ped)
    local range = math.max(1, max - Config.Wounds.HealthBase)
    local full = a.heal and before + range * a.heal / 100 >= max or false
    local applied = W.copy(plan)
    if a.heal and before >= max then applied.actions.heal = nil end
    W.treat(valid.state, applied, full)
    valid.state.history[#valid.state.history + 1] = { part = plan.part, label = plan.label, item = plan.item,
        count = plan.count, examiner = task.medicId, issuedAt = os.date('!%Y-%m-%dT%H:%M:%SZ') }
    if MedicalRecordTreatment and task.chartId then
        local firstAction = next(applied.actions)
        local part = plan.part
        if applied.actions.iv or (firstAction == 'heal' and not next(applied.actions, firstAction)) then part = nil end
        MedicalRecordTreatment(task.target, task.chartId, plan.item, plan.count, part)
    end
    for key, value in pairs(plan.needs or {}) do
        exports.qbx_core:SetMetadata(task.target, key, value)
    end
    release(src)
    sync(task.target)
    if a.suppressFracture or a.suppressBleeding then
        TriggerClientEvent('ptech_mediora_medical:symptom', task.target, {part = plan.part,
            symptom = a.suppressFracture and 'fractureSuppressed' or 'bleedingSuppressed'})
    end
    if a.heal then TriggerClientEvent('ptech_mediora_medical:health', task.target, a.heal, valid.patientId) end
    return { ok = true }
end)

-- Tools等からの医薬品連携。公開ネットイベントで蓄積値を半減させる口は設けない。
exports('recordMedication', function(src, full)
    local state = patient(src)
    if not state then return false end
    W.medication(state, full == true)
    sync(src)
    return true
end)
exports('getWounds', S.get)

function S.clearFractures(src, part)
    local state = patient(src)
    if not state or (part ~= nil and not W.validPart(part)) then return false end
    for _, key in ipairs(W.parts) do if not part or part == key then state.parts[key].fracture = nil end end
    state.revision = state.revision + 1
    sync(src)
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src] = nil
    release(src)
    for medic, task in pairs(pending) do if task.target == src then release(medic) end end
end)

CreateThread(function()
    local lastMinute = GetGameTimer()
    while true do
        Wait(1000)
        local now, minute = GetGameTimer(), GetGameTimer() - lastMinute >= 60000
        if minute then lastMinute = now end
        for _, value in ipairs(GetPlayers()) do
            local src = tonumber(value)
            local state, _, _, expired = patient(src)
            if state then
                S.updateDeath(src)
                if minute then W.decay(state, 1) end
                if minute or expired then sync(src) end
            end
        end
    end
end)
