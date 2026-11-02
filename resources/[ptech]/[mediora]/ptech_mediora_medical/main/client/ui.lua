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
    return {
        title = snapshot.title, death = snapshot.death, training = snapshot.training == true,
        mode = snapshot.mode or (snapshot.success == false and 'error' or type(snapshot.injuries) ~= 'table' and 'unknown'
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

function MedicalUI.openCharts(targetId, chartId)
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
    MedicalNuiSend('clinical', { action = 'charts:open', data = { targetId = targetId, chartId = chartId, medicName = access.name } })
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
