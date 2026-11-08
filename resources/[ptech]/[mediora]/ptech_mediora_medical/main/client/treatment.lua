MedicalTreatment = {}
local T, operation = MedicalTreatment, nil

function T.isBusy() return operation ~= nil end

function T.items()
    local items = {}
    for name, item in pairs(Config.Wounds.Items) do
        local count = 0
        if GetResourceState('ox_inventory') == 'started' then
            local ok, value = pcall(function() return exports.ox_inventory:Search('count', name) end)
            if ok and type(value) == 'number' then count = value end
        end
        if count > 0 then items[#items + 1] = { name = name, label = item.label, count = count } end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    return items
end

function T.cancel()
    local active = operation
    operation = nil
    if active then
        MedicalProgress.stop(active.progress)
        if active.token then TriggerServerEvent('ptech_mediora_medical:treatment:cancel', active.token) end
    end
end

function T.treat(data, isCurrent)
    if operation then return { error = '別の操作が進行中です' } end
    if T.canStart and not T.canStart() then return { error = '診察中は処置できません' } end
    if type(data) ~= 'table' or not Medical.validId(data.targetId) or not MedicalWounds.validPart(data.part)
        or type(data.item) ~= 'string' then return { error = '患者・部位・道具を確認してください' } end
    local active = {}
    operation = active
    local id = exports.qbx_core:GetPlayerData().citizenid
    local function current()
        return operation == active and exports.qbx_core:GetPlayerData().citizenid == id and (not isCurrent or isCurrent())
    end
    local ok, result = pcall(function()
        local start = lib.callback.await('ptech_mediora_medical:treatment:start', false,
            data.targetId, data.part, data.item, data.chartId, data.selfUse == true)
        if start and start.token then active.token = start.token end
        if not current() then return { error = '処置を中止しました' } end
        if not start or start.error then return { error = start and start.error or '処置を開始できません' } end
        active.progress = MedicalProgress.start(start.duration, start.label .. 'で処置中', 'treatment', data.item, start.motion)
        local deadline, finished = GetGameTimer() + start.duration, true
        while GetGameTimer() < deadline do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            if not current() or IsEntityDead(PlayerPedId()) or IsDisabledControlJustPressed(0, 73) then
                finished = false
                break
            end
            Wait(0)
        end
        MedicalProgress.stop(active.progress)
        if not finished or not current() then return { error = '処置を中止しました' } end
        local response = lib.callback.await('ptech_mediora_medical:treatment:finish', false, active.token)
        if not current() then return { error = '処置結果はカルテを再確認してください' } end
        if response and response.ok then active.token = nil end
        return response or { error = '処置結果を取得できません' }
    end)
    MedicalProgress.stop(active.progress)
    if active.token then TriggerServerEvent('ptech_mediora_medical:treatment:cancel', active.token) end
    if operation == active then operation = nil end
    if not ok then
        if Config.Debug then print('[ptech_mediora_medical:treatment] ' .. tostring(result)) end
        return { error = '処置に失敗しました。カルテを再確認してください' }
    end
    return result
end

function T.menu(target, part, chartId, selfUse)
    local options = {}
    for _, item in ipairs(T.items()) do options[#options + 1] = { value = item.name, label = item.label .. '（所持 ' .. item.count .. '）' } end
    local answer = lib.inputDialog('治療道具を選択', { { type = 'select', label = '道具', options = options, required = true } })
    if not answer then return end
    local response = T.treat({ targetId = target, part = part, chartId = chartId, item = answer[1], selfUse = selfUse })
    lib.notify({ title = '治療', description = response.error or '処置が完了しました', type = response.error and 'error' or 'success' })
    if not selfUse and response.ok then MedicalUI.openCharts(target, chartId) end
end

-- ox_inventoryのclient.export。consume=0で定義し、成功後のRemoveItemだけで消費する。
-- useItemを重ねて呼ぶと二重消費になるため呼ばない。所持・使用権限はサーバーで検証する。
exports('useMedicalItem', function(item)
    local name = type(item) == 'table' and item.name
    local spec = name and Config.Wounds.Items[name]
    if not spec then return end
    local fields, options = {}, {}
    local names = {head='頭部',upper_body='上半身',lower_body='下半身',left_arm='左腕',right_arm='右腕',left_leg='左脚',right_leg='右脚'}
    for _, part in ipairs(MedicalWounds.parts) do options[#options + 1] = { value = part, label = names[part] } end
    if not spec.heal or spec.bleeding then
        fields[1] = { type = 'select', label = '処置する部位', options = options, required = true }
    end
    local part = 'upper_body'
    if #fields > 0 then local answer = lib.inputDialog(spec.label, fields); if not answer then return end; part = answer[1] end
    local response = T.treat({ targetId = GetPlayerServerId(PlayerId()), part = part, item = name, selfUse = true })
    lib.notify({ title = spec.label, description = response.error or '処置が完了しました', type = response.error and 'error' or 'success' })
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', T.cancel)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then T.cancel() end end)
