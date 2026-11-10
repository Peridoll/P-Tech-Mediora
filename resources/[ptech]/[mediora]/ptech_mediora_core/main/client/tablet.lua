local opened = false
local focused = false
local ready = false
local generation = 0
local usingItem = false
local resourceName = GetCurrentResourceName()
local version = GetResourceMetadata(resourceName, 'version', 0) or 'unknown'
local tabletItem = Config and Config.Tablet and Config.Tablet.item
if not tabletItem then
    tabletItem = 'pmediora_tablet'
    print(('[%s] Tablet %s: Config.Tablet.item unavailable; using %s'):format(resourceName, version, tabletItem))
end
local progressThemes = { mediora = true, blue = true, amber = true, violet = true, peach = true, lime = true }
local progressTheme = GetResourceKvpString('progressTheme')
if not progressThemes[progressTheme] then progressTheme = 'mediora' end

local function closeTablet(keepFocus)
    if not opened then return end
    opened = false
    generation = generation + 1
    if focused and keepFocus ~= true then SetNuiFocus(false, false) end
    focused = false
    SendNUIMessage({ action = 'tablet:close' })
end

local function openTablet()
    if opened then return false end
    if not ready then
        lib.notify({ type = 'error', description = 'タブレット画面の準備ができていません。Coreの起動ログを確認してください。' })
        return false
    end
    if IsPauseMenuActive() then return false end
    if (exports.ox_inventory:Search('count', tabletItem) or 0) < 1 then
        lib.notify({ type = 'error', description = 'Medioraタブレットを所持していません。' })
        return false
    end
    exports.ox_inventory:closeInventory()
    opened = true
    generation = generation + 1
    local openingGeneration = generation
    SendNUIMessage({ action = 'tablet:open', generation = openingGeneration })
    SetTimeout(2000, function()
        if not opened or focused or generation ~= openingGeneration then return end
        closeTablet()
        lib.notify({ type = 'error', description = 'タブレットを開けませんでした。もう一度お試しください。' })
    end)
    return true
end

exports('useTablet', function(data)
    if usingItem or opened then return end
    if not ready or IsPauseMenuActive() then
        lib.notify({ type = 'error', description = '現在タブレットを開けません。少し待ってもう一度使用してください。' })
        return
    end
    if type(data) ~= 'table' or data.name ~= tabletItem then
        lib.notify({ type = 'error', description = 'タブレットのアイテム名とCoreの設定が一致していません。' })
        return
    end
    usingItem = true
    local accepted = false
    local ok, err = pcall(function()
        exports.ox_inventory:useItem(data, function(used)
            if used then accepted = true; openTablet() end
        end)
    end)
    usingItem = false
    if not ok then
        print(('[ptech_mediora_core] tablet use failed: %s'):format(tostring(err)))
        lib.notify({ type = 'error', description = 'タブレットの使用に失敗しました。F8のエラーを確認してください。' })
    elseif not accepted then
        lib.notify({ type = 'error', description = 'インベントリが使用を許可しませんでした。行動を終えてからもう一度使用してください。' })
    end
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if opened and itemName == tabletItem and totalCount < 1 then closeTablet() end
end)

RegisterNUICallback('tabletReady', function(_, cb)
    if not ready then print(('[%s] Tablet %s: UI ready'):format(resourceName, version)) end
    ready = true
    SendNUIMessage({ action = 'progress:theme', theme = progressTheme })
    cb({ ok = true })
end)

RegisterNUICallback('tabletProgressTheme', function(data, cb)
    local theme = type(data) == 'table' and data.theme
    if not opened or type(theme) ~= 'string' or not progressThemes[theme] then
        cb({ ok = false })
        return
    end
    SetResourceKvp('progressTheme', theme)
    progressTheme = theme
    SendNUIMessage({ action = 'progress:theme', theme = theme })
    cb({ ok = true, theme = theme })
end)

RegisterNUICallback('tabletOpened', function(data, cb)
    local openingGeneration = type(data) == 'table' and data.generation
    -- Give the inventory time to finish releasing its focus.
    while opened and not focused and generation == openingGeneration do
        if not IsNuiFocused() and not IsPauseMenuActive() then
            SetNuiFocus(true, true)
            focused = true
            break
        end
        Wait(25)
    end
    cb({ ok = opened and focused and generation == openingGeneration })
end)

RegisterNUICallback('tabletClose', function(data, cb)
    if type(data) == 'table' and data.generation == generation then closeTablet() end
    cb({ ok = true })
end)

RegisterCommand('mediora_tablet_close', function()
    closeTablet()
end, false)

RegisterNUICallback('tabletChartPatients', function(_, cb)
    if not opened or GetResourceState('ptech_mediora_medical') ~= 'started' then
        cb({ error = 'Medicalのカルテを照会できません' }); return
    end
    local requestGeneration = generation
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:managerAccess', false, true)
    if not opened or requestGeneration ~= generation then
        cb({ error = 'カルテの照会を終了しました' }); return
    end
    cb(ok and type(result) == 'table' and result or { error = '患者候補を取得できません' })
end)

RegisterNUICallback('tabletCharts', function(data, cb)
    if not opened then cb({ error = 'タブレットを開き直してください' }); return end
    local target = type(data) == 'table' and tonumber(data.targetId)
    if not target or target <= 0 or target % 1 ~= 0 then
        cb({ error = '患者のサーバーIDを入力してください' })
        return
    end
    if GetResourceState('ptech_mediora_medical') ~= 'started' then
        cb({ error = 'Medicalが停止中のため、カルテを確認できません' })
        return
    end
    local requestGeneration = generation
    -- Medical validates the caller's job and duty status on every lookup.
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:getPatientCharts', 500, target)
    if not opened or requestGeneration ~= generation then
        cb({ error = 'カルテの照会を終了しました' })
        return
    end
    cb(ok and type(result) == 'table' and result or { error = 'カルテを取得できませんでした' })
end)

local openingChart = false
RegisterNUICallback('tabletOpenChart', function(data, cb)
    if not opened or openingChart then cb({ error = 'カルテ画面を開けません' }); return end
    if type(data) ~= 'table' then cb({ error = 'カルテ画面を開けません' }); return end
    local target = tonumber(data.targetId)
    if data.targetId ~= nil and (not target or target <= 0 or target % 1 ~= 0
        or type(data.chartId) ~= 'string' or data.chartId == '') then
        cb({ error = '患者のカルテを選択してください' }); return
    end
    if GetResourceState('ptech_mediora_medical') ~= 'started' then
        cb({ error = 'Medicalが停止中のため、カルテを開けません' }); return
    end
    openingChart = true
    -- Release Core before Medical acquires the cursor. Closing Core afterward only hides its UI.
    SetNuiFocus(false, false)
    local ok, displayed = pcall(function()
        return exports.ptech_mediora_medical:openCharts(target, data.chartId)
    end)
    openingChart = false
    if not ok or displayed ~= true then
        if opened then SetNuiFocus(true, true) end
        cb({ error = 'カルテを開けませんでした。勤務状態を確認してください' })
        return
    end
    closeTablet(true)
    cb({ ok = true })
end)

exports('openTablet', openTablet)
for _, route in ipairs({ 'tabletAccess', 'tabletHome', 'tabletPersonnel', 'tabletPersonnelAction', 'tabletResources', 'tabletResourceAction' }) do
    local callbackRoute = route
    RegisterNUICallback(callbackRoute, function(data, cb)
        if not opened then cb({ ok = false, error = 'closed' }) return end
        local requestGeneration = generation
        local ok, result = pcall(function()
            local delay = 1000
            if callbackRoute == 'tabletAccess' or callbackRoute == 'tabletHome' then delay = false end
            return lib.callback.await('ptech_mediora_core:' .. callbackRoute, delay, data)
        end)
        if not opened or requestGeneration ~= generation then
            cb({ ok = false, error = 'closed' })
            return
        end
        cb(ok and result or { ok = false, error = 'unavailable' })
    end)
end

local shopRoutes = { tabletShopCatalog = 'catalog', tabletShopPlace = 'place' }
for route, action in pairs(shopRoutes) do
    RegisterNUICallback(route, function(data, cb)
        if not opened or GetResourceState('ptech_mediora_logistics') ~= 'started' then
            cb({ ok = false, error = '医療物資ストアを利用できません。' })
            return
        end
        local ok, result = pcall(lib.callback.await, 'ptech_mediora_logistics:orders:' .. action, false, data)
        if not ok then
            print(('[ptech_mediora_core] shop %s callback failed: %s'):format(action, tostring(result)))
        end
        cb(ok and type(result) == 'table' and result or { ok = false, error = '注文結果を確認できません。注文履歴を確認してください。' })
    end)
end

exports('closeTablet', closeTablet)

print(('[%s] Tablet %s: useTablet registered (item=%s)'):format(resourceName, version, tabletItem))

AddEventHandler('QBCore:Client:OnPlayerUnload', closeTablet)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeTablet() end
end)
