local last = {}
local examinations, issuing = {}, {}
local reportSequence = 0

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
AddEventHandler('playerDropped', function()
    last[source], examinations[source] = nil, nil
end)

lib.callback.register('ptech_mediora_medical:createReport', function(src, target, injuries, success)
    local exam = examinations[src]
    if issuing[src] or not exam or exam.target ~= target or GetGameTimer() - exam.time > 30000 then
        return { error = '診察記録が期限切れです。もう一度診察してください' }
    end
    examinations[src] = nil -- Single use, including failed issuance.
    local result = inspect(src, target)
    if result.error then return result end
    if GetResourceState('ox_inventory') ~= 'started' then return { error = 'インベントリが起動していません' } end
    local medic, patient = exports.qbx_core:GetPlayer(src), exports.qbx_core:GetPlayer(target)
    if not medic or not patient then return { error = '患者情報を取得できません' } end
    if patient.PlayerData.citizenid ~= exam.patientId then return { error = '対象患者が変わりました' } end
    local function identity(data)
        local info = data.charinfo or {}
        return tostring(info.firstname or ''):sub(1, 60) .. ' ' .. tostring(info.lastname or ''):sub(1, 60)
    end
    reportSequence = reportSequence + 1
    local id = ('%s-%s-%s'):format(os.time(), src, reportSequence)
    local observation = Medical.report(injuries, success)
    local summaries = {}
    local names = { head = '頭部', neck = '首', upper_body = '胸部・腹部', lower_body = '腰部', spine = '背中',
        left_arm = '左腕', right_arm = '右腕', left_leg = '左脚', right_leg = '右脚',
        left_hand = '左手', right_hand = '右手', left_foot = '左足', right_foot = '右足' }
    local kinds = { shot = '銃創', stabbed = '刺創', beat = '打撲', burned = '熱傷' }
    for _, row in ipairs(observation.rows) do
        summaries[#summaries + 1] = ('%s: %s / 重症度 %s / 出血 %s')
            :format(names[row.part], kinds[row.kind], row.severity or '未取得', row.bleed or '未取得')
    end
    local patientName = identity(patient.PlayerData)
    local job = medic.PlayerData.job or {}
    local grade = job.grade
    local gradeName = type(grade) == 'table' and (grade.name or grade.level) or grade
    local report = {
        label = '診断書 — ' .. patientName,
        reportId = id, patientId = patient.PlayerData.citizenid,
        patientName = patientName, examinerId = medic.PlayerData.citizenid,
        examinerName = identity(medic.PlayerData), examinerGrade = tostring(gradeName or '不明'), issuedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        death = result.death, injuries = observation.rows, observationStatus = observation.status,
        dataSource = 'Wasabi client observation (not server-verified injuries)',
        description = ('患者: %s'):format(patientName), -- do not expose clinical details in inventory hover
    }
    issuing[src] = true
    local ok, added = pcall(function() return exports.ox_inventory:AddItem(src, Config.ReportItem, 1, report) end)
    issuing[src] = nil
    if not ok or not added then return { error = '診断書を追加できません。空き容量とアイテム登録を確認してください' } end
    return { reportId = id }
end)

