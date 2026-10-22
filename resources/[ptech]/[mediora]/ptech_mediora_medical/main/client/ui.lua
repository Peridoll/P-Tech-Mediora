MedicalUI = {}
local current
local bodyNames = {
    head = '頭部', neck = '首', upper_body = '胸部・腹部', lower_body = '腰部',
    spine = '背中', left_arm = '左腕', right_arm = '右腕', left_leg = '左脚', right_leg = '右脚',
    left_hand = '左手', right_hand = '右手', left_foot = '左足', right_foot = '右足',
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
        mode = snapshot.success == false and 'error' or type(snapshot.injuries) ~= 'table' and 'unknown'
            or next(snapshot.injuries) == nil and 'empty' or #rows == 0 and 'unsupported' or 'ready',
        injuries = rows, details = description,
        canRefresh = type(snapshot.refresh) == 'function', canManage = type(snapshot.manage) == 'function',
    }
end

function MedicalUI.close()
    current = nil
    SetNuiFocus(false, false)
    MedicalNuiSend('clinical', { action = 'close' })
end

RegisterNUICallback('action', function(data, cb)
    local action = type(data) == 'table' and data.action
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
    if snapshot.training then
        options[#options + 1] = { title = '患者の状態を変更', onSelect = snapshot.manage }
    end
    lib.registerContext({ id = 'ptech_mediora_medical:diagnosis', title = snapshot.title, options = options })
    lib.showContext('ptech_mediora_medical:diagnosis')
    return description
end

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
