local last = {}
local examinations, chartsById, chartsByPatient = {}, {}, {}
local chartSequence = 0

local function updatePatientStatus(target, patientId)
    local patient = exports.qbx_core:GetPlayer(target)
    -- 同じサーバーIDを別の患者が再利用した場合は通知しない。
    if not patient or patient.PlayerData.citizenid ~= patientId then return end
    local active = false
    for _, exam in pairs(examinations) do
        if exam.target == target and exam.patientId == patientId and exam.startedAt then
            active = true
            break
        end
    end
    TriggerClientEvent('ptech_mediora_medical:examinationStatus', target, active)
end

local function endExamination(src)
    local exam = examinations[src]
    examinations[src] = nil
    if exam and exam.startedAt then updatePatientStatus(exam.target, exam.patientId) end
end

local function identity(data)
    local info = data and data.charinfo or {}
    local name = (tostring(info.firstname or '') .. ' ' .. tostring(info.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    return name ~= '' and name:sub(1, 60) or '氏名未登録'
end

local function allowedMedic(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not Medical.allowed(player.PlayerData) then return nil, '勤務中の医療職のみ利用できます' end
    return player
end

local supplyPrices = {
    pmediora_firstaidkit = 300000,
    pmediora_bandage = 50000,
    pmediora_icepack = 100000,
    pmediora_surgicalforceps = 50000,
    pmediora_bulletextractionkit = 100000,
    pmediora_suturekit = 100000,
    pmediora_needleandthread = 50000,
    pmediora_burncream = 100000,
    pmediora_splint = 150000,
}

local reviveRates = {
    field = { label = '現場蘇生', fee = 800000 },
    hospital = { label = '院内蘇生', fee = 400000 },
    police = { label = '警察蘇生', fee = 300000 },
    jail = { label = '牢屋蘇生', fee = 200000 },
}

local function chartSummary(chart)
    local charges, total = {}, 0
    for item, quantity in pairs(chart.suppliesUsed or {}) do
        local unit = supplyPrices[item]
        if unit then
            charges[#charges + 1] = { item = item, quantity = quantity, unit = unit }
            total = total + quantity * unit
        end
    end
    table.sort(charges, function(a, b) return a.item < b.item end)
    local treatmentFee = #charges > 0 and 100000 or 0
    local reviveRate = reviveRates[chart.reviveCategory]
    local reviveFee = reviveRate and reviveRate.fee or 0
    return {
        chartId = chart.chartId,
        patientName = chart.patientName,
        examinerName = chart.examinerName,
        issuedAt = chart.issuedAt,
        death = chart.death,
        injuries = chart.injuries,
        treated = chart.treated,
        charges = charges,
        treatmentFee = treatmentFee,
        reviveFee = reviveFee,
        reviveLabel = reviveRate and reviveRate.label,
        totalCharge = total + treatmentFee + reviveFee,
        bleeding = chart.bleeding,
        revived = chart.revived,
        invoiceId = chart.invoiceId,
        observationStatus = chart.observationStatus,
    }
end

local function inspect(src, target)
    if type(target) ~= 'number' or target ~= target or target % 1 ~= 0 or target <= 0 or target == src then
        return { error = '対象が無効です' }
    end
    if GetResourceState('wasabi_ambulance') ~= 'started' then return { error = 'Wasabiが起動していません' } end
    local player = exports.qbx_core:GetPlayer(src)
    local patient = exports.qbx_core:GetPlayer(target)
    if not player or not Medical.allowed(player.PlayerData) then return { error = '勤務中の医療職のみ利用できます' } end
    if not patient then return { error = '対象が退出しました' } end
    local own = Medical.death(Player(src).state.dead, player.PlayerData.metadata)
    if own == '死亡' or own == '瀕死（laststand）' then return { error = '行動不能中は診察できません' } end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 or GetEntityHealth(a) <= 0 then return { error = '対象または診察者を取得できません' } end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target)
        or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.Distance then
        return { error = '対象が診察範囲外です' }
    end
    return { target = target, death = Medical.death(Player(target).state.dead, patient.PlayerData.metadata) }
end

lib.callback.register('ptech_mediora_medical:inspect', function(src, target)
    local now = GetGameTimer()
    if last[src] and now - last[src] < Config.Cooldown then return { error = '少し待ってから再診察してください' } end
    last[src] = now
    endExamination(src)
    local result = inspect(src, target)
    if not result.error then
        local exam = { target = target, time = now,
            patientId = exports.qbx_core:GetPlayer(target).PlayerData.citizenid,
            medicId = exports.qbx_core:GetPlayer(src).PlayerData.citizenid }
        examinations[src] = exam
        SetTimeout(30000, function()
            if examinations[src] == exam and not exam.startedAt then endExamination(src) end
        end)
    end
    return result
end)

-- Wasabiの取得後に再確認し、観察内容を保持してから診察演出を開始する。
-- Wasabi sends full live snapshots, then a separate cause when the patient goes down.
local injurySnapshots = {}

RegisterNetEvent('wasabi_ambulance:injurySync', function(injuries)
    local src = source
    if type(src) ~= 'number' or src <= 0 then return end
    local patient = exports.qbx_core:GetPlayer(src)
    if not patient then return end

    local patientId = patient.PlayerData.citizenid
    local death = Medical.death(Player(src).state.dead, patient.PlayerData.metadata)
    local down = death == '死亡' or death == '瀕死（laststand）'
    local snapshot = injurySnapshots[src]
    if not snapshot or snapshot.patientId ~= patientId then
        snapshot = { patientId = patientId }
        injurySnapshots[src] = snapshot
    end

    if injuries == false or (type(injuries) == 'table' and next(injuries) == nil) then
        if down then
            snapshot.down = true
        else
            injurySnapshots[src] = nil
        end
        return
    end
    if type(injuries) ~= 'table' then return end

    local observation = Medical.report(injuries, true)
    if #observation.rows == 0 then return end
    if type(injuries.injury) == 'string' then
        snapshot.cause = observation.rows[1]
    else
        snapshot.live = observation.rows
        snapshot.cause = nil
    end
    snapshot.down = down
end)

AddStateBagChangeHandler('dead', nil, function(bag, _, value)
    local src = tonumber(bag:match('^player:(%d+)$'))
    local snapshot = src and injurySnapshots[src]
    if not snapshot then return end
    local death = Medical.death(value)
    if death == '死亡' or death == '瀕死（laststand）' then
        snapshot.down = true
    elseif death == '死亡・瀕死フラグなし' and snapshot.down then
        injurySnapshots[src] = nil
        if not snapshot.restore then return end
        local injuries = {}
        for _, row in ipairs(snapshot.restore) do
            if row.part then
                injuries[row.part] = { type = row.kind, data = { level = row.woundTreated and 0 or row.severity or 1, bleed = row.bleed or 0 } }
            end
        end
        if next(injuries) == nil then return end
        SetTimeout(1250, function()
            local patient = exports.qbx_core:GetPlayer(src)
            if not patient or patient.PlayerData.citizenid ~= snapshot.patientId or injurySnapshots[src] then return end
            if Medical.death(Player(src).state.dead, patient.PlayerData.metadata) ~= '死亡・瀕死フラグなし' then return end
            injurySnapshots[src] = { patientId = snapshot.patientId, live = Medical.report(injuries, true).rows }
            TriggerClientEvent('wasabi_ambulance:syncInjury', src, injuries, false)
        end)
    end
end)

lib.callback.register('ptech_mediora_medical:confirm', function(src, target, injuries, success)
    local exam = examinations[src]
    if not exam or exam.target ~= target or exam.startedAt or GetGameTimer() - exam.time > 30000 then
        return { error = '診察記録が期限切れです。もう一度診察してください' }
    end
    local result = inspect(src, target)
    local patient = exports.qbx_core:GetPlayer(target)
    local medic = exports.qbx_core:GetPlayer(src)
    if result.error or not patient or not medic or medic.PlayerData.citizenid ~= exam.medicId
        or patient.PlayerData.citizenid ~= exam.patientId then
        endExamination(src)
        return { error = result.error or '診察者または対象患者が変わりました' }
    end
    if success == true and (injuries == false or injuries == nil) then injuries = {} end
    local observation = Medical.report(injuries, success)
    local snapshot = injurySnapshots[target]
    local down = result.death == '死亡' or result.death == '瀕死（laststand）'
    if snapshot and snapshot.patientId == exam.patientId and (down or not snapshot.down) then
        if snapshot.live then
            local rows = {}
            for _, row in ipairs(snapshot.live) do rows[#rows + 1] = row end
            observation = { rows = rows, status = 'Wasabiの負傷同期記録' }
        end
        if down and snapshot.cause then
            local cause = snapshot.cause
            local duplicate = false
            for _, row in ipairs(observation.rows) do
                if row.part == cause.part and row.kind == cause.kind then
                    duplicate = true
                    break
                end
            end
            if not duplicate then observation.rows[#observation.rows + 1] = cause end
            observation.unsupported = false
            observation.status = 'Wasabiの負傷同期記録'
        end
    end
    if #observation.rows == 0 and (success ~= true or type(injuries) ~= 'table') then
        endExamination(src)
        return { error = '負傷情報を取得できませんでした。もう一度診察してください' }
    end
    local settings = Config.Examination
    exam.duration = math.min(settings.BaseDuration + #observation.rows * settings.PerPartDuration, settings.MaxDuration)
    exam.startedAt, exam.observation = GetGameTimer(), observation
    updatePatientStatus(target, exam.patientId)
    -- 演出終了の通信が来ない場合も表示を残さない。古いタイマーで次の診察を消さない。
    SetTimeout(exam.duration + 2000, function()
        if examinations[src] == exam then endExamination(src) end
    end)
    return { duration = exam.duration, death = result.death, injuries = observation.rows }
end)

-- Cancellation only discards this medic's temporary authorization. It never
-- mutates patient state and cannot affect another player's examination.
lib.callback.register('ptech_mediora_medical:cancel', function(src, target)
    local exam = examinations[src]
    if exam and exam.target == target then endExamination(src) end
    return true
end)

-- ログアウト・リソース停止時は、応答待ちをせず自分の診察だけを取り消す。
RegisterNetEvent('ptech_mediora_medical:cancelExamination', function(target)
    local src = source
    local exam = examinations[src]
    if exam and exam.target == target then endExamination(src) end
end)

AddEventHandler('playerDropped', function()
    injurySnapshots[source] = nil
    local dropped = source
    last[dropped] = nil
    endExamination(dropped)
    local affected = {}
    for medic, exam in pairs(examinations) do
        if exam.target == dropped then affected[#affected + 1] = medic end
    end
    for _, medic in ipairs(affected) do endExamination(medic) end
end)

-- The chart store is intentionally process-local. It is shared by permitted
-- on-duty medics during this server run and is cleared when the resource stops.
lib.callback.register('ptech_mediora_medical:createChart', function(src, target)
    local exam = examinations[src]
    if not exam or exam.target ~= target or not exam.startedAt
        or GetGameTimer() - exam.startedAt > exam.duration + 2000 then
        return { error = '診察記録が期限切れです。もう一度診察してください' }
    end
    endExamination(src) -- 成功・失敗ともに1回限り。患者の診察中表示も解除する。
    if GetGameTimer() - exam.startedAt < exam.duration then return { error = '診察が完了していません' } end
    local result = inspect(src, target)
    if result.error then return result end
    local medic, patient = exports.qbx_core:GetPlayer(src), exports.qbx_core:GetPlayer(target)
    if not medic or not patient then return { error = '患者情報を取得できません' } end
    if medic.PlayerData.citizenid ~= exam.medicId or patient.PlayerData.citizenid ~= exam.patientId then
        return { error = '診察者または対象患者が変わりました' }
    end
    local observation = exam.observation
    local down = result.death == '死亡' or result.death == '瀕死（laststand）'
    if down and observation.unsupported then return { error = '負傷状態を確認できません。再診察してください' } end
    if not down and #observation.rows == 0 and not observation.unsupported then
        return { noChart = true, message = '診察が完了しました。確認できる傷はないようです。' }
    end
    local snapshot = injurySnapshots[target]
    if down then
        if not snapshot or snapshot.patientId ~= exam.patientId then
            snapshot = { patientId = exam.patientId }
            injurySnapshots[target] = snapshot
        end
        snapshot.down = true
        if not snapshot.restore then
            snapshot.restore = {}
            for _, row in ipairs(observation.rows) do
                if row.part then snapshot.restore[#snapshot.restore + 1] = row end
            end
        end
    end
    local patientCharts = chartsByPatient[exam.patientId] or {}
    local latest = chartsById[patientCharts[1]]
    if latest and (not latest.treated or (snapshot and snapshot.treatedChart == latest.chartId))
        and #observation.rows > 0 and latest.death == result.death
        and latest.observationStatus == observation.status and #latest.injuries == #observation.rows then
        local same = true
        for index, row in ipairs(observation.rows) do
            local previous = latest.injuries[index]
            if row.part ~= previous.part or row.body ~= previous.body or row.kind ~= previous.kind
                or row.severity ~= previous.severity or row.bleed ~= previous.bleed then
                same = false
                break
            end
        end
        if same then return { chart = chartSummary(latest) } end
    end
    chartSequence = chartSequence + 1
    local id = ('%s-%s-%s'):format(os.time(), src, chartSequence)
    local chart = {
        chartId = id, patientId = patient.PlayerData.citizenid,
        patientName = identity(patient.PlayerData), examinerId = medic.PlayerData.citizenid,
        examinerName = identity(medic.PlayerData), issuedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        death = result.death, injuries = observation.rows, observationStatus = observation.status,
        dataSource = 'Wasabi client observation (not server-verified injuries)',
    }
    chartsById[id] = chart
    chartsByPatient[chart.patientId] = patientCharts
    table.insert(patientCharts, 1, id)
    return { chart = chartSummary(chart) }
end)

-- EMSManager uses these read-only callbacks. The server remains the authority for
-- job and duty checks; the client only supplies the online target server ID.
lib.callback.register('ptech_mediora_medical:managerAccess', function(src)
    local player, error = allowedMedic(src)
    if not player then return { error = error } end
    return { name = identity(player.PlayerData) }
end)

lib.callback.register('ptech_mediora_medical:getPatientCharts', function(src, target)
    local _, error = allowedMedic(src)
    if error then return { error = error } end
    target = tonumber(target)
    if not target or target % 1 ~= 0 or target <= 0 then return { error = '患者IDには数字を入力してください' } end
    local patient = exports.qbx_core:GetPlayer(target)
    if not patient then return { error = 'そのIDのプレイヤーは現在接続していません' } end
    local patientId = patient.PlayerData.citizenid
    local records, ids = {}, chartsByPatient[patientId] or {}
    for _, chartId in ipairs(ids) do
        local chart = chartsById[chartId]
        if chart then records[#records + 1] = chartSummary(chart) end
    end
    return {
        patient = { serverId = target, citizenId = patientId, name = identity(patient.PlayerData) },
        charts = records,
        vitals = (function()
            local ped = GetPlayerPed(target)
            local metadata = patient.PlayerData.metadata or {}
            local death = Medical.death(Player(target).state.dead, metadata)
            local down = death == '死亡' or death == '瀕死（laststand）'
            local health = down and 100 or (ped ~= 0 and GetEntityHealth(ped))
            return { health = health and math.max(0, math.min(100, health - 100)) or nil,
                hunger = metadata.hunger, thirst = metadata.thirst, stress = metadata.stress, down = down }
        end)(),
    }
end)

-- Temporary debug command. Keep this list aligned with Logistics BoxContents.
local debugTreatmentItems = {
    'pmediora_firstaidkit',
    'pmediora_bandage',
    'pmediora_splint',
    'pmediora_icepack',
    'pmediora_bulletextractionkit',
    'pmediora_surgicalforceps',
    'pmediora_suturekit',
    'pmediora_needleandthread',
    'pmediora_burncream',
}

RegisterCommand('medkit30', function(src)
    if src <= 0 then return end

    local function reply(message, kind)
        TriggerClientEvent('ox_lib:notify', src, { title = '治療道具の補充', description = message, type = kind })
    end
    if GetResourceState('ox_inventory') ~= 'started' then
        reply('インベントリが起動していません。', 'error')
        return
    end

    local inventory = exports.ox_inventory
    if not inventory:GetInventory(src) then
        reply('インベントリを取得できませんでした。', 'error')
        return
    end
    local added, failed = 0, {}
    for _, item in ipairs(debugTreatmentItems) do
        local missing = 30 - (inventory:GetItemCount(src, item) or 0)
        if missing > 0 then
            if inventory:CanCarryItem(src, item, missing) and inventory:AddItem(src, item, missing) then
                added = added + missing
            else
                failed[#failed + 1] = item
            end
        end
    end
    if #failed > 0 then
        reply(('合計 %d 個補充しました。補充できなかった道具: %s'):format(added, table.concat(failed, ', ')), 'error')
    elseif added > 0 then
        reply(('不足分を合計 %d 個補充しました。'):format(added), 'success')
    else
        reply('すべての治療道具を30個以上所持しています。', 'inform')
    end
end, true)

-- The chart is historical. Only the current episode's pending restoration can be treated.
local treatmentTools = {
    beat = 'pmediora_icepack',
    shot = 'pmediora_bulletextractionkit',
    stabbed = 'pmediora_suturekit',
    burned = 'pmediora_burncream',
}

local treatmentDuration = 2200
local pendingTreatments = {}

lib.callback.register('ptech_mediora_medical:treat', function(src, target, chartId, index, phase, method)
    local pending = pendingTreatments[src]
    if phase == 'finish' or phase == 'cancel' then
        pendingTreatments[src] = nil
        if phase == 'cancel' then return { ok = true } end
        if not pending or pending.target ~= target or pending.chartId ~= chartId or pending.index ~= index or pending.method ~= method
            or GetGameTimer() - pending.startedAt < treatmentDuration
            or GetGameTimer() - pending.startedAt > treatmentDuration + 3000 then
            return { error = '治療を最初からやり直してください' }
        end
    elseif phase ~= 'start' then
        return { error = '治療を開始してください' }
    elseif pending then
        return { error = 'すでに治療中です' }
    end
    local result = inspect(src, target)
    if result.error then return result end
    local down = result.death == '死亡' or result.death == '瀕死（laststand）'
    local patient = exports.qbx_core:GetPlayer(target)
    local patientId = patient.PlayerData.citizenid
    local snapshot = injurySnapshots[target]
    local history = chartsByPatient[patientId]
    if type(chartId) ~= 'string' or not history or history[1] ~= chartId then
        return { error = '最新のカルテを開いてください' }
    end
    local chart = chartsById[chartId]
    local healthKit = index == 0
    if healthKit and (down or GetEntityHealth(GetPlayerPed(target)) >= 200) then
        return { error = '医療キットは体力が減っている生存患者に使用できます' }
    end
    local wounds = snapshot and snapshot.patientId == patientId
        and ((down and snapshot.restore) or (not down and not snapshot.down and snapshot.live))
    if not healthKit and not wounds then return { error = '対象を再診察してください' } end
    local selected = Medical.validId(index) and chart.injuries[index]
    if method ~= 'bandage' and selected and chart.treated and chart.treated[tostring(index)] then
        return { error = 'この傷は処置済みです' }
    end
    local tool = healthKit and 'pmediora_firstaidkit'
    if selected and selected.part then
        if method == 'bandage' then
            tool = 'pmediora_bandage'
        elseif method == 'forceps' and selected.kind == 'shot' then
            tool = 'pmediora_surgicalforceps'
        elseif method == 'needle' and selected.kind == 'stabbed' then
            tool = 'pmediora_needleandthread'
        elseif method == selected.kind then
            tool = treatmentTools[selected.kind]
        end
    end
    if not tool then return { error = 'この傷に使える治療道具がありません' } end
    if snapshot and snapshot.treating then return { error = 'この患者は処置中です' } end

    for pendingIndex, row in ipairs(healthKit and { true } or wounds) do
        if healthKit or (row.part == selected.part and row.kind == selected.kind
            and (method == 'bandage' and (row.bleed or 0) > 0 or method ~= 'bandage' and not row.woundTreated)) then
            if GetResourceState('ox_inventory') ~= 'started' then
                return { error = 'インベントリを利用できません' }
            end
            if phase == 'start' then
                if (exports.ox_inventory:GetItemCount(src, tool) or 0) < 1 then
                    return { error = '必要な治療道具を持っていません' }
                end
                pending = { target = target, chartId = chartId, index = index, method = method, snapshot = snapshot,
                    row = row, patientId = patientId, startedAt = GetGameTimer() }
                pendingTreatments[src] = pending
                SetTimeout(treatmentDuration + 3000, function()
                    if pendingTreatments[src] == pending then pendingTreatments[src] = nil end
                end)
                return { duration = treatmentDuration }
            end
            if pending.patientId ~= patientId or (not healthKit and (pending.snapshot ~= snapshot or pending.row ~= row)) then
                return { error = '患者の状態が変わりました。再診察してください' }
            end
            if snapshot then snapshot.treating = true end
            local ok, removed = pcall(function()
                return exports.ox_inventory:RemoveItem(src, tool, 1)
            end)
            if snapshot then snapshot.treating = nil end
            if not ok or not removed then return { error = '必要な道具を使用できませんでした' } end
            chart.suppliesUsed = chart.suppliesUsed or {}
            chart.suppliesUsed[tool] = (chart.suppliesUsed[tool] or 0) + 1
            if healthKit then
                TriggerClientEvent('ptech_mediora_medical:restoreHealth', target)
                return { ok = true }
            end
            -- Replace the pending row so the original examination remains intact.
            local updated = {}
            for key, value in pairs(row) do updated[key] = value end
            local safeKit = method == 'shot' or method == 'stabbed'
            if method ~= 'bandage' then updated.woundTreated = true end
            if method == 'bandage' or safeKit then
                updated.bleed = 0
            elseif (method == 'forceps' or method == 'needle') and math.random(100) <= 30 then
                updated.bleed = math.max(1, updated.bleed or 0)
            end
            if updated.woundTreated and (updated.bleed or 0) == 0 then
                table.remove(wounds, pendingIndex)
            else
                wounds[pendingIndex] = updated
            end
            if not down and (method == 'bandage' or safeKit) then
                TriggerClientEvent('ptech_mediora_medical:restoreHealth', target, 0.15)
            end
            chart.bleeding = chart.bleeding or {}
            chart.bleeding[tostring(index)] = updated.bleed
            if not down then
                local remaining = {}
                for _, injury in ipairs(wounds) do
                    remaining[injury.part] = { type = injury.kind,
                        data = { level = injury.woundTreated and 0 or injury.severity or 1, bleed = injury.bleed or 0 } }
                end
                TriggerClientEvent('wasabi_ambulance:syncInjury', target, remaining, false)
            end
            chart.treated = chart.treated or {}
            if updated.woundTreated then chart.treated[tostring(index)] = true end
            snapshot.treatedChart = chartId
            return { ok = true }
        end
    end
    return { error = 'この傷は処置済みです' }
end)
lib.callback.register('ptech_mediora_medical:reviveChart', function(src, target, chartId)
    local result = inspect(src, target)
    if result.error then return result end
    if result.death ~= '死亡' and result.death ~= '瀕死（laststand）' then
        return { error = '患者は蘇生が必要な状態ではありません' }
    end
    local patient = exports.qbx_core:GetPlayer(target)
    local snapshot = injurySnapshots[target]
    local patientId = patient.PlayerData.citizenid
    local history = chartsByPatient[patientId]
    if not snapshot or snapshot.patientId ~= patientId or not snapshot.down or not snapshot.restore
        or not history or history[1] ~= chartId then
        return { error = '最新のカルテで患者の状態を確認してください' }
    end
    if #snapshot.restore ~= 0 then return { error = '先にすべての傷を治療してください' } end
    if snapshot.reviving then return { error = 'すでに蘇生中です' } end

    snapshot.reviving = true
    local chart = chartsById[chartId]
    local ok = pcall(function() exports.wasabi_ambulance:RevivePlayer(target) end)
    if ok then
        for _ = 1, 20 do
            Wait(150)
            local current = exports.qbx_core:GetPlayer(target)
            if not current or current.PlayerData.citizenid ~= patientId then break end
            if Medical.death(Player(target).state.dead, current.PlayerData.metadata) == '死亡・瀕死フラグなし' then
                chart.revived = true
                return { ok = true }
            end
        end
    end
    snapshot.reviving = nil
    return { error = '蘇生の完了を確認できませんでした' }
end)
lib.callback.register('ptech_mediora_medical:billChart', function(src, target, chartId, category)
    local medic, error = allowedMedic(src)
    if not medic then return { error = error } end
    if not Medical.validId(target) or target == src or type(chartId) ~= 'string' then
        return { error = '請求先が無効です' }
    end
    local patient = exports.qbx_core:GetPlayer(target)
    local chart = chartsById[chartId]
    if not patient or not chart or chart.patientId ~= patient.PlayerData.citizenid then
        return { error = '患者とカルテを確認してください' }
    end
    if chart.invoiceId then return { ok = true } end
    if chart.billing then return { error = '請求を送信中です' } end
    for index, row in ipairs(chart.injuries) do
        local key = tostring(index)
        local bleed = chart.bleeding and chart.bleeding[key]
        if row.part and (not (chart.treated and chart.treated[key]) or (bleed or row.bleed or 0) > 0) then
            return { error = 'すべての傷と出血を処置してから請求してください' }
        end
    end
    if (chart.death == '死亡' or chart.death == '瀕死（laststand）') and not chart.revived then
        return { error = '蘇生が完了してから請求してください' }
    end
    local rate = type(category) == 'string' and reviveRates[category]
    if chart.revived and not rate then return { error = '蘇生区分を選んでください' } end
    if not chart.revived then rate = nil end
    local total = chartSummary(chart).totalCharge + (rate and rate.fee or 0)
    if total <= 0 then return { error = '請求する費用がありません' } end
    if GetResourceState('okokBilling') ~= 'started' or GetResourceState('oxmysql') ~= 'started' then
        return { error = '請求システムを利用できません' }
    end

    local job = medic.PlayerData.job
    chart.billing = true
    local ok, invoiceId = pcall(function()
        return exports.oxmysql:insert_async([[
            INSERT INTO okokbilling
              (ref_id, fees_amount, receiver_identifier, receiver_name, author_identifier, author_name,
               society, society_name, item, invoice_value, status, notes, sent_date, limit_pay_date)
            SELECT CONCAT('OK', UPPER(LEFT(UUID(), 8))), 0, ?, ?, ?, ?, society, ?, ?, ?, 'unpaid', ?,
                   CURRENT_TIMESTAMP(), DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY)
            FROM okokbanking_societies WHERE society = ? LIMIT 1
        ]], {
            chart.patientId, chart.patientName, medic.PlayerData.citizenid, identity(medic.PlayerData),
            job.label, '医療費', total, '診療記録 ' .. chartId, job.name,
        })
    end)
    chart.billing = nil
    if not ok or not invoiceId or invoiceId <= 0 then
        return { error = '請求を作成できませんでした。医療職の入金口座を確認してください' }
    end
    chart.invoiceId = invoiceId
    chart.reviveCategory = rate and category or nil
    local current = exports.qbx_core:GetPlayer(target)
    if current and current.PlayerData.citizenid == chart.patientId then
        TriggerClientEvent('ox_lib:notify', target, {
            title = '医療費の請求', description = ('医療費の請求が届きました（%d円）'):format(total), type = 'inform',
        })
    end
    return { ok = true }
end)