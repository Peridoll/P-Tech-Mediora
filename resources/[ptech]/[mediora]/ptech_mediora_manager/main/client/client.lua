local open = false
local lastPage = 'home'
local verifiedPatient
local session, chartQuery, viewRequest = 0, 0, 0

local function notify(message, kind)
    lib.notify({ title = Config.Home.Title, description = message, type = kind or 'error' })
end

local function closeManager()
    session, viewRequest = session + 1, viewRequest + 1
    verifiedPatient = nil
    ManagerPatientView.stop()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function treatmentItems()
    if GetResourceState('ptech_mediora_medical') ~= 'started' then return {} end
    local ok, items = pcall(function()
        return exports.ptech_mediora_medical:getTreatmentItems()
    end)
    return ok and type(items) == 'table' and items or {}
end

-- 表示専用。複数スロットに分かれた同名の医療品を合計する。
-- 処置成功時の消費・所持数の最終確認はMedicalサーバーが担当する。
local function treatmentSupplies()
    local definitions = treatmentItems()
    if next(definitions) == nil then return { error = 'Medicalの医療品設定を取得できません' } end
    local ok, slots = pcall(function() return exports.ox_inventory:GetPlayerItems() end)
    if not ok or type(slots) ~= 'table' then return { error = '医療品の所持数を取得できません' } end
    local counts, items = {}, {}
    for _, slot in pairs(slots) do
        if type(slot) == 'table' and definitions[slot.name] then
            local count = tonumber(slot.count) or 0
            if count > 0 then counts[slot.name] = (counts[slot.name] or 0) + count end
        end
    end
    for name, definition in pairs(definitions) do
        if counts[name] then
            items[#items + 1] = {
                name = name, label = definition.label, uiLabel = definition.uiLabel,
                description = definition.description, treatment = definition.treatment, count = counts[name],
            }
        end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    return { items = items }
end

local function updateSupplies()
    if open then SendNUIMessage({ action = 'treatment:supplies', data = treatmentSupplies() }) end
end

AddEventHandler('ox_inventory:updateInventory', updateSupplies)

RegisterNUICallback('getTreatmentSupplies', function(_, cb)
    cb(open and treatmentSupplies() or { error = 'EMSManagerを開いてください' })
end)

local function openManager(initial)
    session, viewRequest = session + 1, viewRequest + 1
    local request = session
    verifiedPatient = nil
    ManagerPatientView.stop()
    local access = lib.callback.await('ptech_mediora_medical:managerAccess', false)
    if request ~= session then return end
    if not access or access.error then
        notify(access and access.error or 'EMSManagerを開けません')
        return
    end
    initial = initial or {}
    local page = initial.page == 'charts' and 'charts' or (lastPage == 'charts' and 'charts' or 'home')
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            title = Config.Home.Title,
            medicName = access.name,
            wallpaper = Config.Home.Wallpaper,
            page = page,
            targetId = initial.targetId,
            chartId = initial.chartId,
            treatmentItems = treatmentItems(),
        },
    })
end

-- ox_inventory calls this from the ptech_ems_tablet item's client.export.
exports('openTablet', function(data, slot)
    if open then return end
    exports.ox_inventory:useItem(data, function(used)
        if used then openManager() end
    end)
end)

-- Medical calls this after diagnosis; its target action uses the same export.
exports('openCharts', function(targetId, chartId)
    openManager({ page = 'charts', targetId = targetId, chartId = chartId })
end)

RegisterNUICallback('close', function(_, cb)
    closeManager()
    cb({ ok = true })
end)

RegisterNUICallback('rememberPage', function(data, cb)
    if type(data) == 'table' and (data.page == 'home' or data.page == 'charts') then lastPage = data.page end
    cb({ ok = true })
end)

RegisterNUICallback('getCharts', function(data, cb)
    chartQuery = chartQuery + 1
    local query, revision = chartQuery, session
    verifiedPatient = nil
    ManagerPatientView.stop()
    local targetId = type(data) == 'table' and data.targetId
    local result = lib.callback.await('ptech_mediora_medical:getPatientCharts', false, targetId)
    if not open or revision ~= session or query ~= chartQuery then cb({ error = 'カルテの照会を終了しました' }); return end
    if result and not result.error and type(result.patient) == 'table' then verifiedPatient = result.patient end
    cb(result or { error = 'カルテを取得できません' })
end)

RegisterNUICallback('setPatientView', function(data, cb)
    viewRequest = viewRequest + 1
    local request, revision, patient = viewRequest, session, verifiedPatient
    ManagerPatientView.stop()
    if type(data) ~= 'table' or data.active ~= true then cb({ active = false }); return end
    if not open or not patient then cb({ active = false, message = '患者のカルテを選択してください。' }); return end
    -- NUIから任意のIDを受け取らない。サーバー照会済み患者を再確認してから映す。
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:getPatientCharts', false, patient.serverId)
    if not open or request ~= viewRequest or revision ~= session or verifiedPatient ~= patient then
        cb({ active = false }); return
    end
    if not ok or not result or result.error or not result.patient or result.patient.citizenId ~= patient.citizenId then
        cb({ active = false, message = '患者を再確認できません。カルテを開き直してください。' }); return
    end
    cb(ManagerPatientView.start(patient.serverId))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeManager() end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', closeManager)
