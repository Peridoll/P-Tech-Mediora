local prefix = 'ptech_mediora_procurement:'
local mission, blip, busy
local zones = {}

local function update(m)
    mission = m or nil
    if blip then RemoveBlip(blip); blip = nil end
    if not mission or mission.stage == 'blocked' then return end
    local coords = mission.stage == 'pickup' and Config.Suppliers[mission.supplier].coords or Config.Hospital
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 2)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(mission.stage == 'pickup' and '医療物資の仕入れ先' or '病院納品口')
    EndTextCommandSetBlipName(blip)
end

local function apply(response)
    if not response then lib.notify({ type = 'error', description = '通信に失敗しました。病院端末で状態を確認してください。' }); return end
    update(response.mission)
    if response.message ~= '' then
        lib.notify({ type = response.ok and 'success' or 'error', description = response.message })
    end
end

local function call(action, ...)
    return lib.callback.await(prefix .. action, false, ...)
end

local function work(kind)
    if busy or (kind == 'pickup' and not mission) then return end
    busy = true
    local id = kind == 'pickup' and mission.id or 0
    local ok, err = pcall(function()
        local response = call('begin', kind, id)
        apply(response)
        if not response or not response.ok then return end
        if lib.progressCircle({ duration = Config.Duration, label = '医療物資を確認しています',
            position = 'bottom', canCancel = true, useWhileDead = false,
            disable = { move = true, car = true, combat = true } }) then
            apply(call('finish', kind, id))
        end
    end)
    busy = false
    if not ok then
        print(('[ptech_mediora_procurement] %s'):format(err))
        lib.notify({ type = 'error', description = '処理に失敗しました。病院端末で状態を確認してください。' })
    end
end

local uiOpen, uiBusy = false, false
local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
local function dashboard()
    local response = call('dashboard')
    if not response or not response.ok then
        closeUI()
        if response then lib.notify({ type = 'error', description = response.message }) end
        return response
    end
    update(response.mission)
    SendNUIMessage({ action = 'state', data = response })
    return response
end
local function menu()
    if busy or uiBusy then return end
    local response = dashboard()
    if not response or not response.ok then return end
    uiOpen = true
    SendNUIMessage({ action = 'open' })
    SetNuiFocus(true, true)
end
RegisterNUICallback('logistics_close', function(_, cb) closeUI(); cb({ ok = true }) end)
RegisterNUICallback('logistics_action', function(data, cb)
    if not uiOpen or uiBusy or busy then cb({ ok = false, message = '処理中です。' }); return end
    uiBusy = true
    local ok, response = pcall(function()
        if data.action == 'start' then
            local started = call('start')
            apply(started)
            if not started or not started.ok then
                return dashboard() or { ok = false, message = '通信に失敗しました。' }
            end
            -- A successful order should immediately return input to the game.
            -- update() above has already left the supplier route active.
            closeUI()
            return started
        elseif data.action == 'cancel' and mission then
            apply(call('cancel', mission.id))
        elseif data.action == 'stash' then
            closeUI()
            exports.ox_inventory:openInventory('stash', Config.Stash.id)
            return { ok = true }
        elseif data.action ~= 'refresh' then
            return { ok = false, message = '無効な操作です。' }
        end
        return dashboard() or { ok = false, message = '通信に失敗しました。' }
    end)
    uiBusy = false
    cb(ok and response or { ok = false, message = '通信に失敗しました。再度開いてください。' })
end)

local function zone(coords, options)
    zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = coords, radius = 1.5, options = options })
end

zone(Config.Hospital, {
    { name = prefix .. 'terminal', icon = 'fa-solid fa-box', label = '医療物資調達端末',
        distance = 2.0, groups = Config.Jobs, onSelect = menu },
    { name = prefix .. 'deliver', icon = 'fa-solid fa-truck', label = '医療物資を納品',
        distance = 2.0, groups = Config.Jobs,
        canInteract = function() return not busy and exports.ox_inventory:Search('count', Config.CargoItem) > 0 end,
        onSelect = function() work('delivery') end },
})
for index, supplier in ipairs(Config.Suppliers) do
    local supplierIndex = index
    zone(supplier.coords, {
        { name = prefix .. 'pickup' .. index, icon = 'fa-solid fa-box', label = '医療物資を受け取る',
            distance = 2.0, groups = Config.Jobs,
            canInteract = function() return not busy and mission and mission.stage == 'pickup' and mission.supplier == supplierIndex end,
            onSelect = function() work('pickup') end },
    })
end

CreateThread(function()
    while true do
        Wait(15000)
        if uiOpen and not uiBusy then dashboard()
        elseif mission and not busy then apply(call('status')) end
    end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('ptech_mediora_procurement:unload')
    update(nil); closeUI()
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUI()
    if blip then RemoveBlip(blip) end
    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
end)

