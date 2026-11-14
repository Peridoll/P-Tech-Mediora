local last = {}
local examinations, chartsById, chartsByPatient = {}, {}, {}
local chartSequence = 0
local chartRunId = ('%08x%08x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
local chartStoreReady = false
local pendingChartWrites, writingCharts = {}, {}
local chartPhotoBytes = 0
local chartReuseSeconds = 5 * 60

local function isLatestChart(chart)
    local ids = chartsByPatient[chart.patientId]
    return ids and ids[1] == chart.chartId
end

-- 治療側は患者のcitizenidとカルテの所有患者を照合する。ID再利用に追従しない。
function MedicalChartAccess(patientId, chartId)
    local chart = type(chartId) == 'string' and chartsById[chartId]
    return chart and chart.patientId == patientId and isLatestChart(chart)
        and not chart.invoiceId and not chart.billing and not chart.reviving
end

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

local function allowedMedic(source, target)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or (target ~= source and not Medical.allowed(player.PlayerData)) then return nil, '勤務中の医療職のみ利用できます' end
    return player
end

local supplyPrices = {
    pmediora_ivdrip = 0,
    pmediora_firstaidkit = 300000,
    pmediora_bandage = 50000,
    pmediora_icepack = 100000,
    pmediora_surgicalforceps = 50000,
    pmediora_bulletextractionkit = 100000,
    pmediora_suturekit = 100000,
    pmediora_needleandthread = 50000,
    pmediora_burncream = 100000,
    pmediora_splint = 150000, -- 過去カルテの明細用
    pmediora_protectivecast = 50000,
}

local treatmentNames = {
    pmediora_ivdrip = '点滴',
    pmediora_firstaidkit = '体力回復',
    pmediora_bandage = '包帯処置',
    pmediora_icepack = '冷却',
    pmediora_coolingspray = '冷却',
    pmediora_surgicalforceps = '摘出',
    pmediora_bulletextractionkit = '摘出',
    pmediora_suturekit = '縫合',
    pmediora_needleandthread = '縫合',
    pmediora_burncream = '火傷処置',
    pmediora_medicatedbandage = '火傷処置',
    pmediora_splint = '固定',
    pmediora_protectivecast = '固定',
    pmediora_painkiller = '鎮痛',
    pmediora_hemostatic = '止血',
}

local manualBillingLimit = 100000000
local reviveRates = {
    field = { label = '現場蘇生', fee = 800000 },
    hospital = { label = '院内蘇生', fee = 400000 },
    police = { label = '警察蘇生', fee = 300000 },
    jail = { label = '牢屋蘇生', fee = 200000 },
}

local function chartSummary(chart)
    local current = MedicalWoundServer and chart.targetId and MedicalWoundServer.get(chart.targetId) or {}
    local samePatient = current.citizenId == chart.patientId
    local state = samePatient and current.state
    local history = state and state.history or {}
    local used = chart.suppliesUsed or {}
    chart.suppliesUsed = used
    local archived = not isLatestChart(chart)
    local activeRows = archived and chart.closedRows or (state and MedicalWounds.rows(state) or {})
    local treated, bleeding = {}, {}
    for index, injury in ipairs(chart.injuries) do
        local exists = false
        for _, row in ipairs(activeRows) do
            if row.part == injury.part and row.kind == injury.kind then exists = true end
        end
        if not exists then treated[tostring(index)] = true end
    end

    local charges, byTreatment, total, unpriced = {}, {}, 0, false
    for item, quantity in pairs(chart.suppliesUsed or {}) do
        local unit = supplyPrices[item]
        local label = treatmentNames[item] or item
        local line = byTreatment[label] or { label = label, sites = {}, amount = 0 }
        byTreatment[label] = line
        for part in pairs((chart.treatmentSites or {})[item] or {}) do line.sites[part] = true end
        if unit then
            charges[#charges + 1] = { item = item, quantity = quantity, unit = unit }
            line.amount = line.amount + quantity * unit
            total = total + quantity * unit
        else
            charges[#charges + 1] = { item = item, quantity = quantity }
            line.unpriced = true
            unpriced = true
        end
    end
    local treatmentCharges = {}
    for _, line in pairs(byTreatment) do
        local count = 0
        for _ in pairs(line.sites) do count = count + 1 end
        treatmentCharges[#treatmentCharges + 1] = { label = line.label, siteCount = count,
            amount = not line.unpriced and line.amount or nil }
    end
    table.sort(treatmentCharges, function(a, b) return a.label < b.label end)
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
        treated = treated,
        charges = charges,
        treatmentCharges = treatmentCharges,
        unpriced = unpriced,
        treatmentFee = treatmentFee,
        reviveFee = reviveFee,
        reviveLabel = reviveRate and reviveRate.label,
        totalCharge = total + treatmentFee + reviveFee,
        bleeding = bleeding,
        currentInjuries = activeRows,
        archived = archived,
        hasPhoto = chart.photo ~= nil,
        canTreat = not archived and samePatient and not chart.invoiceId and not chart.billing,
        deathCause = chart.deathCause,
        revived = chart.revived,
        invoiceId = chart.invoiceId,
        invoiceTotal = chart.invoiceTotal,
        manualBillingLimit = manualBillingLimit,
        observationStatus = chart.observationStatus,
    }
end


local function flushChart(chartId)
    if not chartStoreReady or writingCharts[chartId] then return end
    writingCharts[chartId] = true
    while pendingChartWrites[chartId] do
        local row = pendingChartWrites[chartId]
        local ok, result = pcall(MySQL.update.await, [[
            INSERT INTO mediora_medical_charts (chart_id, patient_id, issued_at, record)
            VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE record = VALUES(record)
        ]], row)
        if not ok or result == nil then
            print('[ptech_mediora_medical] カルテのDB保存に失敗しました。再試行します。')
            SetTimeout(5000, function() flushChart(chartId) end)
            break
        end
        if pendingChartWrites[chartId] == row then pendingChartWrites[chartId] = nil end
    end
    writingCharts[chartId] = nil
end

if MySQL then
    local function initializeChartStore()
        local ok = pcall(MySQL.query.await, [[
            CREATE TABLE IF NOT EXISTS mediora_medical_charts (
                chart_id VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
                patient_id VARCHAR(64) NOT NULL,
                issued_at BIGINT UNSIGNED NOT NULL,
                record LONGTEXT NOT NULL,
                INDEX medical_patient_date (patient_id, issued_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        local readable, rows = pcall(MySQL.query.await, 'SELECT chart_id FROM mediora_medical_charts LIMIT 0')
        if not ok or not readable or type(rows) ~= 'table' then
            print('[ptech_mediora_medical] カルテDBの初期化を確認できません。再試行します。')
            SetTimeout(10000, initializeChartStore)
            return
        end
        chartStoreReady = true
        print('[ptech_mediora_medical] カルテDBを確認しました。')
        for chartId in pairs(pendingChartWrites) do flushChart(chartId) end
    end
    MySQL.ready(initializeChartStore)
end

local function saveChart(chart)
    if not MySQL then return end
    local record = chartSummary(chart)
    record.currentInjuries = chart.closedRows or chart.observedRows
    record.archived, record.canTreat, record.hasPhoto = true, false, false
    for index, injury in ipairs(record.injuries) do
        local treated = true
        for _, row in ipairs(record.currentInjuries) do
            if row.part == injury.part and row.kind == injury.kind then treated = false; break end
        end
        record.treated[tostring(index)] = treated or nil
    end
    pendingChartWrites[chart.chartId] = { chart.chartId, chart.patientId, chart.createdAt, json.encode(record) }
    flushChart(chart.chartId)
end

local function historicalCharts(patientId)
    if not MySQL then return {} end
    if not chartStoreReady then return nil end
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT chart_id, record FROM mediora_medical_charts
        WHERE patient_id = ? ORDER BY issued_at DESC, chart_id DESC
    ]], { patientId })
    if not ok or type(rows) ~= 'table' then return nil end
    local records = {}
    for _, row in ipairs(rows) do
        if not chartsById[row.chart_id] then
            local decoded, record = pcall(json.decode, row.record)
            if decoded and type(record) == 'table' and record.chartId == row.chart_id then
                records[#records + 1] = record
            end
        end
    end
    return records
end

local function inspect(src, target)
    if not Medical.validId(target) then
        return { error = '対象が無効です' }
    end
    if GetResourceState('wasabi_ambulance') ~= 'started' then return { error = 'Wasabiが起動していません' } end
    local player, error = allowedMedic(src, target)
    if not player then return { error = error } end
    local patient = exports.qbx_core:GetPlayer(target)
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

RegisterCommand('medself', function(src)
    if src > 0 then
        TriggerClientEvent('ptech_mediora_medical:diagnoseSelf', src)
    end
end, false)

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
    local native = MedicalWoundServer ~= nil
    if native then MedicalWoundServer.updateDeath(target) end
    local observation = native and MedicalWoundServer.report(target) or Medical.report(injuries, success)
    if result.death == '死亡・瀕死フラグなし' then observation.cause = nil end
    if not native and (success ~= true or type(injuries) ~= 'table') then
        endExamination(src)
        return { error = '負傷情報を取得できませんでした。もう一度診察してください' }
    end
    if not native and next(injuries) ~= nil and #observation.rows == 0 then
        endExamination(src)
        return { error = '負傷情報の形式に対応していません', code = 'unsupported_injuries' }
    end
    local settings = Config.Examination
    local fractures = native and { parts = {} } or MedicalFractureServer.observe(target, injuries, success)
    if not native then observation = Medical.withFractures(observation, fractures.parts) end
    exam.duration = math.min(settings.BaseDuration + Medical.partCount(observation.rows) * settings.PerPartDuration, settings.MaxDuration)
    exam.startedAt, exam.observation = GetGameTimer(), observation
    updatePatientStatus(target, exam.patientId)
    -- 演出終了の通信が来ない場合も表示を残さない。古いタイマーで次の診察を消さない。
    SetTimeout(exam.duration + 2000, function()
        if examinations[src] == exam then endExamination(src) end
    end)
    return { duration = exam.duration, death = result.death, fractures = fractures.parts, report = native and observation or nil }
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
    local dropped = source
    last[dropped] = nil
    endExamination(dropped)
    local affected = {}
    for medic, exam in pairs(examinations) do
        if exam.target == dropped then affected[#affected + 1] = medic end
    end
    for _, medic in ipairs(affected) do endExamination(medic) end
end)

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
    local previousIds = chartsByPatient[exam.patientId] or {}
    local previous = chartsById[previousIds[1]]
    if not previous and #observation.rows == 0 and result.death == '死亡・瀕死フラグなし' then
        return { noChart = true, message = '診察が完了しました。確認できる傷はないようです。' }
    end
    local state = MedicalWoundServer and MedicalWoundServer.get(target).state or { history = {} }
    local now = os.time()
    if previous then
        local known = {}
        for _, row in ipairs(previous.observedRows) do known[row.part .. ':' .. row.kind] = row end
        local added = false
        for _, row in ipairs(observation.rows) do
            local old = known[row.part .. ':' .. row.kind]
            if not old or (row.severity or 0) > (old.severity or 0) or (old.suppressed and not row.suppressed) then
                added = true
                break
            end
        end
        local down = result.death == '死亡' or result.death == '瀕死（laststand）'
        local newDown = down and (previous.revived or previous.death == '死亡・瀕死フラグなし')
        local sealed = previous.invoiceId ~= nil
        if previous.billing or previous.reviving then return { error = '蘇生または請求の完了後に再診察してください' } end
        local canAppend = not (down and previous.revived) and now - previous.createdAt <= chartReuseSeconds
        if not sealed and ((not newDown and not added) or canAppend) then
            local merged = {}
            for index, row in ipairs(previous.injuries) do merged[row.part .. ':' .. row.kind] = index end
            for _, row in ipairs(observation.rows) do
                local index = merged[row.part .. ':' .. row.kind] or (#previous.injuries + 1)
                previous.injuries[index] = row
                merged[row.part .. ':' .. row.kind] = index
            end
            previous.observedRows = observation.rows
            previous.death = result.death
            if observation.cause then previous.deathCause = observation.cause end
            previous.targetId = target
            saveChart(previous)
            return { chart = chartSummary(previous) }
        end
        if MedicalWoundServer and MedicalWoundServer.busy(target) then
            return { error = '処置の完了後に再診察してください' }
        end
        previous.closedRows = previous.observedRows
    end
    chartSequence = chartSequence + 1
    local id = ('%s-%s-%s-%s'):format(now, src, chartSequence, chartRunId)
    local chart = {
        chartId = id, patientId = patient.PlayerData.citizenid,
        patientName = identity(patient.PlayerData), examinerId = medic.PlayerData.citizenid,
        examinerName = identity(medic.PlayerData), issuedAt = os.date('!%Y-%m-%dT%H:%M:%SZ', now), createdAt = now,
        death = result.death, injuries = observation.rows, observationStatus = observation.status,
        observedRows = { table.unpack(observation.rows) },
        dataSource = 'Wasabi client observation (not server-verified injuries)',
        deathCause = observation.cause,
        targetId = target, historyStart = #state.history, historyEnd = #state.history,
    }
    chartsById[id] = chart
    local patientCharts = chartsByPatient[chart.patientId] or {}
    chartsByPatient[chart.patientId] = patientCharts
    table.insert(patientCharts, 1, id)
    if Config.Examination.ChartPhoto and GetResourceState('screenshot-basic') == 'started' then
        chart.capture = { source = src, deadline = GetGameTimer() + 8000 }
    end
    saveChart(chart)
    return { chart = chartSummary(chart), capturePhoto = chart.capture ~= nil }
end)

lib.callback.register('ptech_mediora_medical:capturePhoto', function(src, target, chartId, points)
    if type(chartId) ~= 'string' then return false end
    local chart = chartsById[chartId]
    local ticket = chart and chart.capture
    if not Config.Examination.ChartPhoto or not ticket or ticket.source ~= src or chart.targetId ~= target
        or GetGameTimer() > ticket.deadline or type(points) ~= 'table'
        or GetResourceState('screenshot-basic') ~= 'started' then return false end
    local medic = exports.qbx_core:GetPlayer(src)
    local patient = exports.qbx_core:GetPlayer(target)
    if not medic or not patient or chart.examinerId ~= medic.PlayerData.citizenid
        or chart.patientId ~= patient.PlayerData.citizenid or inspect(src, target).error then return false end

    local anchors = {}
    for _, part in ipairs(MedicalWounds.parts) do
        local point = points[part]
        if type(point) == 'table' and MedicalWounds.finite(point.x) and MedicalWounds.finite(point.y)
            and point.x >= 0 and point.x <= 1 and point.y >= 0 and point.y <= 1 then
            anchors[part] = { x = point.x, y = point.y }
        end
    end
    if not anchors.head or not anchors.upper_body then return false end
    chart.capture = nil
    local result, done = promise.new(), false
    local function complete(value)
        if done then return end
        done = true
        result:resolve(value)
    end
    SetTimeout(2500, function() complete(false) end)
    local ok = pcall(function()
        exports['screenshot-basic']:requestClientScreenshot(src, { encoding = 'jpg', quality = 0.65 }, function(err, data)
            if done or err or type(data) ~= 'string' or #data > 450000
                or chartPhotoBytes + #data > 32000000
                or not data:match('^data:image/jpeg;base64,[A-Za-z0-9+/=]+$') then
                complete(false)
                return
            end
            chart.photo = { image = data, anchors = anchors }
            chartPhotoBytes = chartPhotoBytes + #data
            complete(true)
        end)
    end)
    if not ok then complete(false) end
    return Citizen.Await(result)
end)

RegisterNetEvent('ptech_mediora_medical:requestChartPhoto', function(target, chartId, request)
    local src = source
    if type(request) ~= 'number' or type(chartId) ~= 'string' then return end
    local chart = chartsById[chartId]
    local patient = Medical.validId(target) and exports.qbx_core:GetPlayer(target)
    if not Config.Examination.ChartPhoto or not chart or not chart.photo or not patient or chart.patientId ~= patient.PlayerData.citizenid
        or not allowedMedic(src) then return end
    TriggerLatentClientEvent('ptech_mediora_medical:chartPhoto', src, 250000, request, chart.photo)
end)

-- EMSManager uses these read-only callbacks. The server remains the authority for
-- job and duty checks; the client only supplies the online target server ID.
lib.callback.register('ptech_mediora_medical:managerAccess', function(src, includePatients, target)
    local player, error = allowedMedic(src, target)
    if not player then return { error = error } end
    local access = { name = identity(player.PlayerData) }
    if includePatients == true and Medical.allowed(player.PlayerData) then
        access.patients = {}
        for _, source in ipairs(GetPlayers()) do
            local target = tonumber(source)
            local patient = target and exports.qbx_core:GetPlayer(target)
            if patient then
                access.patients[#access.patients + 1] = { id = target, name = identity(patient.PlayerData) }
            end
        end
        table.sort(access.patients, function(a, b) return a.id < b.id end)
    end
    return access
end)

lib.callback.register('ptech_mediora_medical:getPatientCharts', function(src, target)
    target = tonumber(target)
    if not Medical.validId(target) then return { error = '患者IDには数字を入力してください' } end
    local medic, error = allowedMedic(src, target)
    if not medic then return { error = error } end
    local medicId = medic.PlayerData.citizenid
    local patient = exports.qbx_core:GetPlayer(target)
    if not patient then return { error = 'そのIDのプレイヤーは現在接続していません' } end
    local patientId = patient.PlayerData.citizenid
    local history = historicalCharts(patientId)
    local currentMedic, currentError = allowedMedic(src, target)
    if not currentMedic or currentMedic.PlayerData.citizenid ~= medicId then
        return { error = currentError or '勤務状態を確認してください' }
    end
    patient = exports.qbx_core:GetPlayer(target)
    if not patient or patient.PlayerData.citizenid ~= patientId then return { error = '対象患者が変わりました' } end
    local canReceiveIV = MedicalWoundServer and MedicalWoundServer.canReceiveIV(target)
    local records, ids = {}, chartsByPatient[patientId] or {}
    local savePending = false
    for _, chartId in ipairs(ids) do
        local chart = chartsById[chartId]
        if chart then records[#records + 1] = chartSummary(chart) end
        if pendingChartWrites[chartId] then savePending = true end
    end
    for _, record in ipairs(history or {}) do records[#records + 1] = record end
    local result = {
        historyUnavailable = history == nil,
        savePending = savePending,
        canBill = target ~= src,
        patient = { serverId = target, citizenId = patientId, name = identity(patient.PlayerData) },
        charts = records,
        vitals = (function()
            local metadata = patient.PlayerData.metadata or {}
            local death = Medical.death(Player(target).state.dead, metadata)
            local down = death == '死亡' or death == '瀕死（laststand）'
            local ped = GetPlayerPed(target)
            local maximum = GetEntityMaxHealth and GetEntityMaxHealth(ped) or 200
            return { health = down and 0 or math.max(0, math.min(100,
                (GetEntityHealth(ped) - Config.Wounds.HealthBase) / math.max(1, maximum - Config.Wounds.HealthBase) * 100)),
                hunger = metadata.hunger, thirst = metadata.thirst, stress = metadata.stress, down = down }
        end)(),
    }
    if MedicalWoundServer then
        local current = MedicalWoundServer.get(target)
        result.treatment = true
        result.treatmentItems = MedicalWoundServer.items(src)
        result.currentInjuries = MedicalWounds.rows(current.state)
        result.treatmentHistory = current.state.history
        result.treatmentState = current.state
        result.itemDefinitions = Config.Wounds.Items
        result.photoEnabled = Config.Examination.ChartPhoto == true
        result.canReceiveIV = canReceiveIV
    end
    return result
end)

lib.callback.register('ptech_mediora_medical:reviveChart', function(src, target, chartId)
    local result = inspect(src, target)
    if result.error then return result end
    if result.death ~= '死亡' and result.death ~= '瀕死（laststand）' then
        return { error = '患者は蘇生が必要な状態ではありません' }
    end
    local patient = exports.qbx_core:GetPlayer(target)
    MedicalWoundServer.updateDeath(target)
    local current = MedicalWoundServer.get(target)
    local patientId = patient.PlayerData.citizenid
    local history = chartsByPatient[patientId]
    if current.citizenId ~= patientId or not history or history[1] ~= chartId then
        return { error = '最新のカルテで患者の状態を確認してください' }
    end
    if current.state.ivCondition then return { error = '餓死・溺死の患者には先に点滴を使用してください' } end
    if MedicalWoundServer.busy(target) then return { error = '治療の完了後に蘇生してください' } end
    local chart = chartsById[chartId]
    if chart.invoiceId or chart.billing then return { error = '蘇生には未請求の最新カルテを使用してください' } end
    if chart.reviving then return { error = 'すでに蘇生中です' } end

    chart.reviving = true
    local ok = pcall(function() exports.wasabi_ambulance:RevivePlayer(target) end)
    if ok then
        for _ = 1, 20 do
            Wait(150)
            local current = exports.qbx_core:GetPlayer(target)
            if not current or current.PlayerData.citizenid ~= patientId then break end
            if Medical.death(Player(target).state.dead, current.PlayerData.metadata) == '死亡・瀕死フラグなし' then
                chart.reviving = nil
                chart.revived = true
                MedicalWoundServer.updateDeath(target)
                MedicalWoundServer.assignCrutch(target, 'revive')
                saveChart(chart)
                return { ok = true }
            end
        end
    end
    chart.reviving = nil
    return { error = '蘇生の完了を確認できませんでした' }
end)

lib.callback.register('ptech_mediora_medical:billChart', function(src, target, chartId, category, manualAmount)
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
    if not isLatestChart(chart) then return { error = 'このカルテは請求無効です' } end
    if chart.invoiceId then return { ok = true } end
    if chart.billing then return { error = '請求を送信中です' } end
    if MedicalWoundServer.busy(target) then return { error = '処置が終わってから請求してください' } end
    if chart.reviving then return { error = '蘇生処理の完了後に請求してください' } end
    local summary = chartSummary(chart)
    if #summary.charges == 0 and not summary.unpriced and not chart.revived then
        return { error = '請求する費用がありません' }
    end
    local rate, total
    if manualAmount ~= nil then
        if type(manualAmount) ~= 'number' or manualAmount % 1 ~= 0
            or manualAmount < 1 or manualAmount > manualBillingLimit then
            return { error = ('請求額は1円から%d円までの整数で入力してください'):format(manualBillingLimit) }
        end
        total = manualAmount
    else
        rate = chart.revived and type(category) == 'string' and reviveRates[category]
        if chart.revived and not rate then return { error = '蘇生区分を選んでください' } end
        if summary.unpriced then return { error = '単価が未設定の道具があります。金額を手入力してください' } end
        total = summary.totalCharge + (rate and rate.fee or 0)
    end
    if total <= 0 then return { error = '請求する費用がありません' } end
    if GetResourceState('okokBilling') ~= 'started' or GetResourceState('oxmysql') ~= 'started' then
        return { error = '請求システムを利用できません' }
    end

    local job = medic.PlayerData.job
    local notes = { '診療記録 ' .. chartId }
    for _, line in ipairs(summary.treatmentCharges) do
        notes[#notes + 1] = line.siteCount > 0 and ('%s %dか所'):format(line.label, line.siteCount) or line.label
    end
    if manualAmount ~= nil then notes[#notes + 1] = ('手入力 %d円'):format(total) end
    if rate then notes[#notes + 1] = rate.label end
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
            job.label, '医療費', total, table.concat(notes, '\n'), job.name,
        })
    end)
    chart.billing = nil
    if not ok or not invoiceId or invoiceId <= 0 then
        return { error = '請求を作成できませんでした。医療職の入金口座を確認してください' }
    end
    chart.invoiceId = invoiceId
    chart.invoiceTotal = total
    chart.reviveCategory = rate and category or nil
    saveChart(chart)
    local current = exports.qbx_core:GetPlayer(target)
    if current and current.PlayerData.citizenid == chart.patientId then
        TriggerClientEvent('ox_lib:notify', target, {
            title = '医療費の請求', description = ('医療費の請求が届きました（%d円）'):format(total), type = 'inform',
        })
    end
    return { ok = true }
end)
local refillingKits = {}
RegisterCommand('medkit30', function(src)
    if src <= 0 or refillingKits[src] then return end
    local function reply(message, kind)
        TriggerClientEvent('ox_lib:notify', src, { title = '治療道具の補充', description = message, type = kind })
    end
    refillingKits[src] = true
    local ok = pcall(function()
        if GetResourceState('ox_inventory') ~= 'started' then
            reply('インベントリが起動していません。', 'error')
            return
        end
        local inventory = exports.ox_inventory
        local slots = inventory:GetInventoryItems(src)
        if type(slots) ~= 'table' then
            reply('所持品を取得できませんでした。', 'error')
            return
        end
        local owned = {}
        for _, slot in pairs(slots) do
            if type(slot) ~= 'table' or type(slot.name) ~= 'string'
                or not MedicalWounds.finite(slot.count) or slot.count < 0 or slot.count % 1 ~= 0 then
                reply('所持数を確認できませんでした。', 'error')
                return
            end
            owned[slot.name] = (owned[slot.name] or 0) + slot.count
        end
        local amounts = { pmediora_tablet = 1 }
        for name, item in pairs(Config.Wounds.Items) do
            if not item.suppressFracture and not item.suppressBleeding then amounts[name] = 30 end
        end
        local items = {}
        for name in pairs(amounts) do items[#items + 1] = name end
        table.sort(items)
        local added, failed = 0, {}
        for _, item in ipairs(items) do
            local missing = amounts[item] - (owned[item] or 0)
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
            reply('治療道具は各30個、タブレットは1個以上所持しています。', 'inform')
        end
    end)
    refillingKits[src] = nil
    if not ok then reply('所持品の確認または補充に失敗しました。', 'error') end
end, true)

-- The chart is historical. Only the current episode's pending restoration can be treated.

function MedicalRecordTreatment(target, chartId, item, count, part)
    local chart = chartsById[chartId]
    local patient = exports.qbx_core:GetPlayer(target)
    if chart and patient and chart.patientId == patient.PlayerData.citizenid then
        local state = MedicalWoundServer.get(target).state
        chart.historyEnd = #state.history
        local current = {}
        for _, row in ipairs(MedicalWounds.rows(state)) do current[row.part .. ':' .. row.kind] = row end
        local remaining = {}
        for _, old in ipairs(chart.observedRows) do
            local row = current[old.part .. ':' .. old.kind]
            if row then remaining[#remaining + 1] = (row.severity <= old.severity) and row or old end
        end
        chart.observedRows = remaining
        chart.suppliesUsed = chart.suppliesUsed or {}
        chart.suppliesUsed[item] = (chart.suppliesUsed[item] or 0) + count
        if part then
            chart.treatmentSites = chart.treatmentSites or {}
            local sites = chart.treatmentSites[item] or {}
            sites[part] = true
            chart.treatmentSites[item] = sites
        end
        saveChart(chart)
    end
end
