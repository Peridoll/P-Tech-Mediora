MedicalUI = {}
local current
local chartSession, chartQuery = 0, 0
local chartsOpen = false
local bodyNames = {
    head = '頭部', upper_body = '上半身', lower_body = '下半身',
    left_arm = '左腕', right_arm = '右腕', left_leg = '左脚', right_leg = '右脚',
}
local types = { shot = '銃創', stabbed = '刺創', beat = '打撲', burned = '熱傷' }

local function level(value)
    if type(value) ~= 'number' or value ~= value or value < 0 or value > 4 or value % 1 ~= 0 then return nil end
    return math.floor(value)
end

function MedicalUI.view(snapshot, description)
    local rows, keys = {}, {}
    if type(snapshot.observedInjuries) == 'table' then
        for _, row in ipairs(snapshot.observedInjuries) do
            rows[#rows + 1] = {
                body = row.kind == 'beat' and not row.part and '-' or row.body or bodyNames[row.part] or '部位未取得',
                kind = row.kind == 'beat' and not row.part and '打撃' or types[row.kind] or row.kind,
                severity = row.severity, bleed = row.bleed, cause = row.cause,
            }
        end
    elseif type(snapshot.injuries) == 'table' then
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
    return {
        title = snapshot.title, death = snapshot.death, training = snapshot.training == true,
        mode = snapshot.mode or (#rows > 0 and 'ready' or snapshot.success == false and 'error' or type(snapshot.injuries) ~= 'table' and 'unknown'
            or next(snapshot.injuries) == nil and 'empty' or #rows == 0 and 'unsupported' or 'ready'),
        injuries = rows, details = description,
        canRefresh = type(snapshot.refresh) == 'function', canManage = type(snapshot.manage) == 'function',
        canOpenCharts = Medical.validId(snapshot.targetId),
    }
end

function MedicalUI.close()
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
    if action ~= 'close' and action ~= 'refresh' and action ~= 'manage' then cb({ ok = false }); return end
    local snapshot = current
    MedicalUI.close()
    cb({ ok = true })
    local fn = snapshot and (action == 'refresh' and snapshot.refresh or action == 'manage' and snapshot.manage)
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
    if Config.UI == 'nui' then
        current = snapshot
        lib.hideContext(false)
        MedicalNuiSend('clinical', { action = 'open', data = MedicalUI.view(snapshot, description) })
        SetNuiFocus(true, true)
        return description
    end
    local options = {}
    if snapshot.training then
        options[#options + 1] = {
            title = '訓練用NPC — 模擬データ',
            description = 'UI確認用です。Wasabiによる診察・治療・蘇生は実行しません。',
            icon = 'flask', readOnly = true,
        }
    end
    options[#options + 1] = { title = '死亡状態', description = snapshot.death, readOnly = true }
    options[#options + 1] = {
        title = snapshot.training and '負傷情報（模擬データ）' or '負傷情報（Wasabi返却値）',
        description = description, readOnly = true,
    }
    options[#options + 1] = { title = '同じ対象を再診察', onSelect = snapshot.refresh }
    if Medical.validId(snapshot.targetId) then
        options[#options + 1] = { title = 'カルテ一覧', onSelect = function() MedicalUI.openCharts(snapshot.targetId) end }
    end
    if snapshot.training then
        options[#options + 1] = { title = '患者の状態を変更', onSelect = snapshot.manage }
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
            title = (bodyNames[injury.part] or injury.part or '部位未取得') .. ' / ' .. (types[injury.kind] or injury.kind or '種類未取得'),
            description = ('重症度 %s / 出血 %s'):format(tostring(injury.severity or '未取得'), tostring(injury.bleed or '未取得')),
            readOnly = true,
        }
    end
    lib.registerContext({ id = 'ptech_mediora_medical:chartDetail', title = 'カルテ詳細', menu = 'ptech_mediora_medical:charts', options = options })
    lib.showContext('ptech_mediora_medical:chartDetail')
end

function MedicalUI.openCharts(targetId, chartId, openTreatment)
    MedicalUI.close()
    local request = chartSession
    local ok, access = pcall(lib.callback.await, 'ptech_mediora_medical:managerAccess', false)
    if request ~= chartSession then return end
    if not ok or not access or access.error then
        lib.notify({ title = 'カルテ', description = ok and access and access.error or 'カルテを開けません', type = 'error' })
        return false
    end
    if Config.UI == 'context' then
        if not Medical.validId(targetId) then return false end
        local fetched, result = pcall(lib.callback.await, 'ptech_mediora_medical:getPatientCharts', false, targetId)
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
    MedicalNuiSend('clinical', { action = 'charts:open', data = { targetId = targetId, chartId = chartId, medicName = access.name, openTreatment = openTreatment } })
    SetNuiFocus(true, true)
    return true
end

RegisterNUICallback('getCharts', function(data, cb)
    if not chartsOpen then cb({ error = 'カルテ画面を開いてください' }); return end
    chartQuery = chartQuery + 1
    local request, query = chartSession, chartQuery
    local targetId = type(data) == 'table' and data.targetId
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:getPatientCharts', false, targetId)
    if not chartsOpen or request ~= chartSession or query ~= chartQuery then
        cb({ error = 'カルテの照会を終了しました' }); return
    end
    cb(ok and type(result) == 'table' and result or { error = 'カルテを取得できません' })
end)

function MedicalUI.describe(snapshot)
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
    if treatingPatient then cb({ error = 'すでに治療中です' }); return end

    local function request(phase)
        local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:treat', false,
            data.targetId, data.chartId, data.index, phase, data.method)
        return ok and result or { error = '治療処理に接続できませんでした' }
    end
    local session = chartSession
    treatingPatient = true
    local start = request('start')
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
    local presentation = treatmentPresentation[data.method]
    local animation = presentation and treatmentAnimations[presentation.animation]
    if animation and not DoesAnimDictExist(animation.dict) then animation = treatmentAnimations.kneel end
    if animation and not DoesAnimDictExist(animation.dict) then animation = nil end
    if animation then RequestAnimDict(animation.dict) end
    local playing = false
    SendNUIMessage({
        action = 'exam-progress', duration = start.duration,
        label = presentation and presentation.label or '治療を実行中',
        mode = 'treatment', tool = data.method,
    })
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
    SendNUIMessage({ action = 'exam-progress' })
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
    SendNUIMessage({ action = 'exam-progress', duration = duration, label = '蘇生中', mode = 'revive' })
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
    SendNUIMessage({ action = 'exam-progress' })
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
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:billChart', false, data.targetId, data.chartId, data.category)
    cb(ok and result or { error = '請求処理に接続できませんでした' })
end)