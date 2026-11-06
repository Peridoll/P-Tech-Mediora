local opened = false
local ready = false
local loading = false
local generation = 0
local usingItem = false

local function closeTablet()
    opened = false
    generation = generation + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tablet:close' })
end

local function openTablet()
    if not ready or IsPauseMenuActive() then return false end
    if (exports.ox_inventory:Search('count', Config.Tablet.item) or 0) < 1 then
        lib.notify({ type = 'error', description = 'Medioraタブレットを所持していません。' })
        return false
    end
    exports.ox_inventory:closeInventory()
    opened = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'tablet:open' })
    return true
end

exports('useTablet', function(data)
    if usingItem or opened then return end
    if not ready or IsPauseMenuActive() then
        lib.notify({ type = 'error', description = '現在タブレットを開けません。少し待ってもう一度使用してください。' })
        return
    end
    if type(data) ~= 'table' or data.name ~= Config.Tablet.item then return end
    usingItem = true
    local ok = pcall(function()
        exports.ox_inventory:useItem(data, function(used)
            if used then openTablet() end
        end)
    end)
    usingItem = false
    if not ok then lib.notify({ type = 'error', description = 'タブレットの使用に失敗しました。' }) end
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if opened and itemName == Config.Tablet.item and totalCount < 1 then closeTablet() end
end)

RegisterNUICallback('tabletReady', function(_, cb)
    ready = true
    cb({ ok = true })
end)

RegisterNUICallback('tabletClose', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('tabletProfile', function(_, cb)
    if not opened or loading then cb({ ok = false, error = 'busy' }) return end
    loading = true
    local requestGeneration = generation
    local ok, result = pcall(function()
        return lib.callback.await('ptech_mediora_core:tabletProfile', false)
    end)
    loading = false
    if not opened or requestGeneration ~= generation then cb({ ok = false, error = 'closed' }) return end
    cb(ok and result or { ok = false, error = 'unavailable' })
end)

exports('openTablet', openTablet)
exports('closeTablet', closeTablet)

AddEventHandler('QBCore:Client:OnPlayerUnload', closeTablet)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeTablet() end
end)
