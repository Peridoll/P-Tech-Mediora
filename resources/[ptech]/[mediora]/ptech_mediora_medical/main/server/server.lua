local last = {}
local examinations, chartsById, chartsByPatient = {}, {}, {}
local chartSequence = 0

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

local function chartSummary(chart)
    return {
        chartId = chart.chartId,
        patientName = chart.patientName,
        examinerName = chart.examinerName,
        issuedAt = chart.issuedAt,
        death = chart.death,
        injuries = chart.injuries,
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
    local result = inspect(src, target)
    if not result.error then
        examinations[src] = { target = target, time = now,
            patientId = exports.qbx_core:GetPlayer(target).PlayerData.citizenid }
    end
    return result
end)

-- Re-check after the Wasabi export, which may yield while fetching patient data.
lib.callback.register('ptech_mediora_medical:confirm', function(src, target)
    return inspect(src, target)
end)

-- Cancellation only discards this medic's temporary authorization. It never
-- mutates patient state and cannot affect another player's examination.
lib.callback.register('ptech_mediora_medical:cancel', function(src, target)
    local exam = examinations[src]
    if exam and exam.target == target then examinations[src] = nil end
    return true
end)

AddEventHandler('playerDropped', function()
    last[source], examinations[source] = nil, nil
end)

-- The chart store is intentionally process-local. It is shared by permitted
-- on-duty medics during this server run and is cleared when the resource stops.
lib.callback.register('ptech_mediora_medical:createChart', function(src, target, injuries, success)
    local exam = examinations[src]
    if not exam or exam.target ~= target or GetGameTimer() - exam.time > 30000 then
        return { error = '診察記録が期限切れです。もう一度診察してください' }
    end
    examinations[src] = nil -- Single use, including failed creation.
    local result = inspect(src, target)
    if result.error then return result end
    local observation = Medical.report(injuries, success)
    if success ~= true or type(injuries) ~= 'table' or #observation.rows == 0 then
        return { noChart = true, message = '確認できる負傷情報がないため、カルテは作成しませんでした' }
    end
    local medic, patient = exports.qbx_core:GetPlayer(src), exports.qbx_core:GetPlayer(target)
    if not medic or not patient then return { error = '患者情報を取得できません' } end
    if patient.PlayerData.citizenid ~= exam.patientId then return { error = '対象患者が変わりました' } end
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
    local patientCharts = chartsByPatient[chart.patientId] or {}
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
    }
end)
