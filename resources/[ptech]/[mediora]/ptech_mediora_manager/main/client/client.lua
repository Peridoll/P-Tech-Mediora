local open = false
local lastPage = 'home'

local function notify(message, kind)
    lib.notify({ title = Config.Home.Title, description = message, type = kind or 'error' })
end

local function closeManager()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openManager(initial)
    local access = lib.callback.await('ptech_mediora_medical:managerAccess', false)
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
    local targetId = type(data) == 'table' and data.targetId
    local result = lib.callback.await('ptech_mediora_medical:getPatientCharts', false, targetId)
    cb(result or { error = 'カルテを取得できません' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeManager() end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', closeManager)
