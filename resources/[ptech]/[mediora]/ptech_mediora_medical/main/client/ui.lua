MedicalUI = {}
local current
local chartSession, chartQuery = 0, 0
local chartsOpen = false
local currentPatient
local bodyNames = {
    head = '頭部', upper_body = '上半身', lower_body = '下半身',
    left_arm = '左腕', right_arm = '右腕', left_leg = '左脚', right_leg = '右脚',
}
local types = { shot = '銃創', stabbed = '切り傷', beat = '打撲', burned = '火傷', fracture = '骨折',
    blunt = '打ち身', bruise = '打撲', cut = '切り傷', burn = '火傷', pin = '通電ピン', bleeding = '出血', starvation = '餓死', drowning = '溺死' }

local function fetchCharts(targetId)
    return lib.callback.await('ptech_mediora_medical:getPatientCharts', false, targetId)
end

local function level(value)
    if type(value) ~= 'number' or value ~= value or value < 0 or value > 4 or value % 1 ~= 0 then return nil end
    return math.floor(value)
end

function MedicalUI.view(snapshot, description)
    local rows, keys = {}, {}
    if type(snapshot.injuries) == 'table' then
        for key in pairs(snapshot.injuries) do
            if #keys >= 40 then break end
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local item = snapshot.injuries[key]
            if type(item) == 'table' and type(item.type) == 'string' then
                local data = type(item.data) == 'table' and item.data or {}
                rows[#rows + 1] = {
                    body = bodyNames[key] or tostring(key):sub(1, 80),
                    kind = types[item.type] or item.type:sub(1, 80),
                    severity = level(data.level), bleed = level(data.bleed),
                }
            end
        end
    end
    if snapshot.fractures then
        for _, part in ipairs(Medical.fractureParts) do
            local severity = snapshot.fractures[part]
            if severity then
                rows[#rows + 1] = { body = bodyNames[part], kind = '骨折', severity = severity, bleed = 0 }
            end
        end
    end
    if snapshot.report then
        rows = {}
        for _, row in ipairs(snapshot.report.rows) do
            local value = MedicalWounds.copy(row)
            value.body = bodyNames[row.part]
            rows[#rows + 1] = value
        end
    end
    return {
        title = snapshot.title, death = snapshot.death,
        mode = snapshot.mode or (snapshot.report and (#rows > 0 and 'ready' or 'empty')) or (snapshot.success == false and 'error' or type(snapshot.injuries) ~= 'table' and 'unknown'
            or (next(snapshot.injuries) == nil and #rows == 0) and 'empty' or #rows == 0 and 'unsupported' or 'ready'),
        injuries = rows, details = description,
        canRefresh = type(snapshot.refresh) == 'function',
        canOpenCharts = Medical.validId(snapshot.targetId),
    }
end

function MedicalUI.close()
    if MedicalTreatment then MedicalTreatment.cancel() end
    currentPatient = nil
    chartSession, chartQuery = chartSession + 1, chartQuery + 1
    chartsOpen = false
    current = nil
    SetNuiFocus(false, false)
    lib.hideContext(false)
    MedicalNuiSend('clinical', { action = 'close' })
end

RegisterNUICallback('action', function(data, cb)
    local action = type(data) == 'table' and data.action
    if action == 'charts' then
        local target = current and current.targetId
        local request = chartSession
        cb({ ok = Medical.validId(target) })
        if Medical.validId(target) then
            CreateThread(function() if request == chartSession then MedicalUI.openCharts(target) end end)
        end
        return
    end
    if action ~= 'close' and action ~= 'refresh' then cb({ ok = false }); return end
    local snapshot = current
    MedicalUI.close()
    cb({ ok = true })
    local fn = snapshot and action == 'refresh' and snapshot.refresh
    if type(fn) == 'function' then
        CreateThread(function()
            local ok, err = pcall(fn)
            if not ok then
                print('[ptech_mediora_medical:ui] ' .. tostring(err))
                lib.notify({ title = '診察', description = '画面を更新できませんでした。もう一度診察してください。', type = 'error' })
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then MedicalUI.close() end
end)
AddEventHandler('QBCore:Client:OnPlayerUnload', MedicalUI.close)

function MedicalUI.show(snapshot)
    chartSession, chartQuery = chartSession + 1, chartQuery + 1
    chartsOpen = false
    local description = MedicalUI.describe(snapshot)
    current = snapshot
    if Config.UI == 'nui' then
        lib.hideContext(false)
        MedicalNuiSend('clinical', { action = 'open', data = MedicalUI.view(snapshot, description) })
        SetNuiFocus(true, true)
        return description
    end
    local options = {}
    options[#options + 1] = { title = '死亡状態', description = snapshot.death, readOnly = true }
    options[#options + 1] = {
        title = '負傷情報（Wasabi返却値）',
        description = description, readOnly = true,
    }
    options[#options + 1] = { title = '同じ対象を再診察', onSelect = snapshot.refresh }
    if Medical.validId(snapshot.targetId) then
        options[#options + 1] = { title = 'カルテ一覧', onSelect = function() MedicalUI.openCharts(snapshot.targetId) end }
    end
    lib.registerContext({ id = 'ptech_mediora_medical:diagnosis', title = snapshot.title, options = options })
    lib.showContext('ptech_mediora_medical:diagnosis')
    return description
end

local function showChartContext(result, chart)
    local options = {
        { title = '患者', description = result.patient.name, readOnly = true },
        { title = '診察日時・診察者', description = (chart.issuedAt or '未記録') .. ' / ' .. (chart.examinerName or '未記録'), readOnly = true },
        { title = '診察時の状態', description = chart.death or '未取得', readOnly = true },
    }
    for _, injury in ipairs(chart.injuries or {}) do
        options[#options + 1] = {
            title = (injury.body or bodyNames[injury.part] or injury.part or '部位未取得') .. ' / ' .. (types[injury.kind] or injury.kind or '種類未取得'),
            description = ('重症度 %s / 出血 %s'):format(tostring(injury.severity or '未取得'), tostring(injury.bleed or '未取得')),
            readOnly = true,
        }
    end
    if chart.archived then
        local treatment = #(chart.currentInjuries or chart.injuries or {}) == 0 and '治療済' or '治療無効'
        local billing = chart.invoiceId and '請求済' or '請求無効'
        options[#options + 1] = { title = treatment .. ' / ' .. billing, readOnly = true }
    elseif result.treatment and chart.canTreat then
        for _, row in ipairs(result.currentInjuries or {}) do
            options[#options + 1] = { title = '治療 / ' .. (row.body or bodyNames[row.part] or row.part) .. ' / ' .. (types[row.kind] or row.kind),
                onSelect = function() MedicalTreatment.menu(result.patient.serverId, row.part, chart.chartId) end }
        end
    end
    lib.registerContext({ id = 'ptech_mediora_medical:chartDetail', title = 'カルテ詳細', menu = 'ptech_mediora_medical:charts', options = options })
    lib.showContext('ptech_mediora_medical:chartDetail')
end

function MedicalUI.openCharts(targetId, chartId, openTreatment)
    MedicalUI.close()
    local request = chartSession
    local ok, access = pcall(lib.callback.await, 'ptech_mediora_medical:managerAccess', false, true)
    if request ~= chartSession then return end
    if not ok or not access or access.error then
        lib.notify({ title = 'カルテ', description = ok and access and access.error or 'カルテを開けません', type = 'error' })
        return false
    end
    if Config.UI == 'context' and Medical.validId(targetId) then
        local fetched, result = pcall(fetchCharts, targetId)
        if request ~= chartSession then return end
        if not fetched or not result or result.error then
            lib.notify({ title = 'カルテ', description = fetched and result and result.error or 'カルテを取得できません', type = 'error' })
            return false
        end
        local options = {}
        for _, chart in ipairs(result.charts or {}) do
            options[#options + 1] = {
                title = chart.issuedAt or '日時未記録', description = '担当: ' .. (chart.examinerName or '未記録'),
                onSelect = function() if request == chartSession then showChartContext(result, chart) end end,
            }
        end
        if #options == 0 then options[1] = { title = 'この患者のカルテはありません', readOnly = true } end
        lib.registerContext({ id = 'ptech_mediora_medical:charts', title = 'カルテ / ' .. result.patient.name, options = options })
        if chartId then
            for _, chart in ipairs(result.charts or {}) do
                if chart.chartId == chartId then showChartContext(result, chart); return true end
            end
        end
        lib.showContext('ptech_mediora_medical:charts')
        return true
    end
    chartsOpen = true
    currentPatient = targetId
    MedicalNuiSend('clinical', { action = 'charts:open', data = { targetId = targetId, chartId = chartId, medicName = access.name, patients = access.patients, openTreatment = openTreatment } })
    SetNuiFocus(true, true)
    return true
end

RegisterNUICallback('getCharts', function(data, cb)
    if not chartsOpen then cb({ error = 'カルテ画面を開いてください' }); return end
    chartQuery = chartQuery + 1
    local request, query = chartSession, chartQuery
    local targetId = type(data) == 'table' and data.targetId
    targetId = tonumber(targetId)
    if not Medical.validId(targetId) then cb({ error = '有効なプレイヤーIDを指定してください' }); return end
    if MedicalTreatment then MedicalTreatment.cancel() end
    currentPatient = targetId
    local ok, result = pcall(fetchCharts, targetId)
    if not chartsOpen or request ~= chartSession or query ~= chartQuery then
        cb({ error = 'カルテの照会を終了しました' }); return
    end
    cb(ok and type(result) == 'table' and result or { error = 'カルテを取得できません' })
end)

local photoRequests, photoSequence = {}, 0

RegisterNetEvent('ptech_mediora_medical:chartPhoto', function(request, photo)
    if source ~= 65535 then return end
    local pending = photoRequests[request]
    if pending then pending(photo) end
end)

RegisterNUICallback('getChartPhoto', function(data, cb)
    if not chartsOpen or not Medical.validId(currentPatient)
        or type(data) ~= 'table' or type(data.chartId) ~= 'string' then cb({}); return end
    photoSequence = photoSequence + 1
    local request, session, query = photoSequence, chartSession, chartQuery
    photoRequests[request] = function(photo)
        photoRequests[request] = nil
        local current = chartsOpen and session == chartSession and query == chartQuery
        cb(current and photo or {})
    end
    SetTimeout(6000, function()
        local pending = photoRequests[request]
        if pending then pending() end
    end)
    TriggerServerEvent('ptech_mediora_medical:requestChartPhoto', currentPatient, data.chartId, request)
end)

function MedicalUI.describe(snapshot)
    if snapshot.report then return Medical.describe(snapshot.report.rows) end
    local description = snapshot.details
    if description then
        return description
    elseif snapshot.success == false then description = '取得失敗：Wasabiのexportを確認してください'
    elseif type(snapshot.injuries) ~= 'table' then
        description = '未取得・未対応（戻り値型：' .. type(snapshot.injuries) .. '）'
    elseif next(snapshot.injuries) == nil then
        description = '返却された負傷情報は空です（健康の保証ではありません）'
    else description = Medical.describe(snapshot.injuries) end
    return description
end

local treatingPatient = false
local treatmentPresentation = {
    health = { label = '救急キットで処置中', animation = 'inspect' },
    bandage = { label = '包帯で止血中', animation = 'work' },
    beat = { label = '冷却パックで処置中', animation = 'kneel' },
    shot = { label = '弾丸を摘出中', animation = 'work' },
    forceps = { label = 'ピンセットで摘出中', animation = 'work' },
    stabbed = { label = '縫合キットで処置中', animation = 'work' },
    needle = { label = '針と糸で縫合中', animation = 'work' },
    burned = { label = '火傷クリームを塗布中', animation = 'kneel' },
}
local treatmentAnimations = {
    kneel = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },
    inspect = { dict = 'amb@medic@standing@tendtodead@base', clip = 'base' },
    work = { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_a' },
}
RegisterNUICallback('treatChartInjury', function(data, cb)
    if not chartsOpen or type(data) ~= 'table' then cb({ error = 'カルテを開き直してください' }); return end
    if treatingPatient or MedicalTreatment.isBusy() then cb({ error = 'すでに治療中です' }); return end
    data.targetId = currentPatient

    local token
    local function request(phase)
        local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:treatment:' .. phase, false,
            phase == 'start' and data.targetId or token, data.part, data.item, data.chartId, false)
        return ok and result or { error = '治療処理に接続できませんでした' }
    end
    local session = chartSession
    treatingPatient = true
    local start = request('start')
    token = start.token
    if not start.duration then
        treatingPatient = false
        cb(start)
        return
    end
    if session ~= chartSession then
        treatingPatient = false
        cb({ error = '治療を中止しました' })
        request('cancel')
        return
    end

    cb({ started = true })
    MedicalUI.close()
    local closedSession = chartSession
    local spec = Config.Wounds.Items[data.item]
    local presentation = treatmentPresentation[data.method] or { label = (spec and spec.label or '道具') .. 'で処置中', animation = 'work' }
    local animation = presentation and treatmentAnimations[presentation.animation]
    if animation and not DoesAnimDictExist(animation.dict) then animation = treatmentAnimations.kneel end
    if animation and not DoesAnimDictExist(animation.dict) then animation = nil end
    if animation then RequestAnimDict(animation.dict) end
    local playing = false
    local progress = MedicalProgress.start(start.duration, presentation.label, 'treatment', data.item, start.motion)
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + start.duration
    local cancelled = false
    while GetGameTimer() < deadline do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)
        if PlayerPedId() ~= ped or IsEntityDead(ped) or IsDisabledControlJustPressed(0, 73) then
            cancelled = true
            break
        end
        if animation and not playing and HasAnimDictLoaded(animation.dict) then
            TaskPlayAnim(ped, animation.dict, animation.clip, 4.0, -4.0, -1, 1, 0.0, false, false, false)
            playing = true
        end
        Wait(0)
    end
    if playing then StopAnimTask(ped, animation.dict, animation.clip, 2.0) end
    if animation then RemoveAnimDict(animation.dict) end
    MedicalProgress.stop(progress)
    local result = request(cancelled and 'cancel' or 'finish')
    treatingPatient = false
    lib.notify({
        title = '治療',
        description = cancelled and '治療を中止しました' or result.error or '処置が完了しました。',
        type = cancelled and 'inform' or result.ok and 'success' or 'error',
    })
    if not cancelled and result.ok then
        Wait(350)
        if chartSession == closedSession and PlayerPedId() == ped and not IsEntityDead(ped) then
            MedicalUI.openCharts(data.targetId, data.chartId, true)
        end
    end
end)
RegisterNUICallback('reviveChart', function(data, cb)
    if not chartsOpen or type(data) ~= 'table' then cb({ error = 'カルテを開き直してください' }); return end
    if treatingPatient then cb({ error = 'すでに処置中です' }); return end
    treatingPatient = true
    cb({ started = true })
    MedicalUI.close()
    local session = chartSession
    local duration = 3000
    local progress = MedicalProgress.start(duration, '蘇生中', 'revive')
    local ped = PlayerPedId()
    local dict = 'mini@cpr@char_a@cpr_str'
    local clip = 'cpr_pumpchest'
    local hasAnimation = DoesAnimDictExist(dict)
    local playing = false
    if hasAnimation then RequestAnimDict(dict) end
    local deadline = GetGameTimer() + duration
    local cancelled = false
    while GetGameTimer() < deadline do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)
        if PlayerPedId() ~= ped or IsEntityDead(ped) or IsDisabledControlJustPressed(0, 73) then
            cancelled = true
            break
        end
        if hasAnimation and not playing and HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, clip, 4.0, -4.0, -1, 1, 0.0, false, false, false)
            playing = true
        end
        Wait(0)
    end
    if playing then StopAnimTask(ped, dict, clip, 2.0) end
    if hasAnimation then RemoveAnimDict(dict) end
    MedicalProgress.stop(progress)
    local result
    if not cancelled then
        local ok, response = pcall(lib.callback.await, 'ptech_mediora_medical:reviveChart', false, data.targetId, data.chartId)
        result = ok and response or { error = '蘇生処理に接続できませんでした' }
    end
    treatingPatient = false
    lib.notify({
        title = '蘇生',
        description = cancelled and '蘇生を中止しました' or result.error or '蘇生が完了しました。',
        type = cancelled and 'inform' or result.ok and 'success' or 'error',
    })
    if chartSession == session and PlayerPedId() == ped and not IsEntityDead(ped) then
        MedicalUI.openCharts(data.targetId, data.chartId)
    end
end)
RegisterNetEvent('ptech_mediora_medical:restoreHealth', function(fraction)
    if source ~= 65535 then return end
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then
        local maximum = GetEntityMaxHealth(ped)
        local health = fraction and math.min(maximum, GetEntityHealth(ped) + math.floor((maximum - 100) * fraction)) or maximum
        SetEntityHealth(ped, health)
    end
end)
RegisterNUICallback('billChart', function(data, cb)
    if not chartsOpen or type(data) ~= 'table' then cb({ error = 'カルテを開き直してください' }); return end
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:billChart', false, data.targetId, data.chartId, data.category, data.manualAmount)
    cb(ok and result or { error = '請求処理に接続できませんでした' })
end)
RegisterNUICallback('treat', function(data, cb)
    if not chartsOpen or not Medical.validId(currentPatient) then cb({ error = '患者のカルテを開いてください' }); return end
    local request, query, target = chartSession, chartQuery, currentPatient
    local function isCurrent() return chartsOpen and request == chartSession and query == chartQuery and currentPatient == target end
    data = type(data) == 'table' and data or {}
    data.targetId = target
    local ok, result = pcall(function() return MedicalTreatment.treat(data, isCurrent) end)
    if ok and result and result.ok and isCurrent() then result.result = fetchCharts(target) end
    cb(ok and type(result) == 'table' and result or { error = '治療に失敗しました' })
end)

