local panels = {}
local switchKey = (Config and Config.ActionPanel and Config.ActionPanel.switchKey) or 'Z'
local keybind

local function send(action, data)
    local currentKey = keybind and keybind.currentKey
    local message = { action = action, switchKey = currentKey and currentKey ~= '' and currentKey or switchKey }
    for key, value in pairs(data or {}) do message[key] = value end
    SendNUIMessage(message)
end

local function validId(id)
    return type(id) == 'string' and #id > 0 and #id <= 32 and id:match('^[a-z0-9_-]+$') ~= nil
end

local function setActionPanel(panel)
    if type(panel) ~= 'table' or not validId(panel.id)
        or type(panel.text) ~= 'string' or #panel.text > 240 then
        return false
    end

    local clean = {
        id = panel.id,
        title = type(panel.title) == 'string' and panel.title:sub(1, 48) or panel.id,
        icon = type(panel.icon) == 'string' and panel.icon:sub(1, 8) or nil,
        state = type(panel.state) == 'string' and panel.state:match('^[a-z0-9_-]+$') and panel.state or 'ready',
        text = panel.text,
        temporaryExpand = panel.temporaryExpand == true,
        startMinimized = panel.startMinimized == true,
        accent = type(panel.accent) == 'string' and panel.accent:match('^#%x%x%x%x%x%x$') and panel.accent or nil,
    }
    if type(panel.progress) == 'number' and panel.progress == panel.progress then
        clean.progress = math.max(0, math.min(100, panel.progress))
    end

    panels[clean.id] = clean
    send('setPanel', { id = clean.id, panel = clean })
    return true
end

local function removeActionPanel(id)
    if not validId(id) then return false end
    panels[id] = nil
    send('removePanel', { id = id })
    return true
end

local function nextActionPanel()
    send('nextTab')
    return true
end


local positionEditing = false
local inventoryPositionEditing = false
local deathPositionEditing = false
local inventoryReleaseX, inventoryReleaseY
local positionFocused = false
local positionKeepInput = false
local positionSession = 0
local position

local function validPosition(value)
    return type(value) == 'table' and type(value.right) == 'number' and type(value.top) == 'number'
        and value.right >= 0 and value.right <= 1 and value.top >= 0 and value.top <= 1
end

local storedPosition = GetResourceKvpString('actionPanelPosition')
if storedPosition then
    local ok, value = pcall(json.decode, storedPosition)
    if ok and validPosition(value) then position = value end
end

local function finishPositionEditing()
    positionSession = positionSession + 1
    if inventoryPositionEditing and positionFocused then
        inventoryReleaseX, inventoryReleaseY = GetNuiCursorPosition()
    end
    positionEditing = false
    inventoryPositionEditing = false
    deathPositionEditing = false
    if positionFocused then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(positionKeepInput and LocalPlayer.state.invOpen == true)
    end
    positionFocused = false
    send('panelPosition', { position = position or false, editing = false })
end

local function editActionPanel(fromInventory, fromDeath)
    if positionEditing or IsPauseMenuActive() then return false end
    if IsNuiFocused() and LocalPlayer.state.invOpen ~= true then return false end
    positionEditing = true
    inventoryPositionEditing = fromInventory == true
    deathPositionEditing = fromDeath == true
    positionSession = positionSession + 1
    local session = positionSession
    send('panelPosition', { position = position or false, editing = true, inventory = inventoryPositionEditing, death = deathPositionEditing, session = session })
    SetTimeout(2000, function()
        if positionEditing and not positionFocused and positionSession == session then finishPositionEditing() end
    end)
    return true
end


local panelBounds
local inventoryHoverReady = true

RegisterNUICallback('actionPanelBounds', function(data, cb)
    local bounds = type(data) == 'table' and data.bounds
    panelBounds = nil
    if type(bounds) == 'table' then
        local valid = true
        for _, key in ipairs({ 'left', 'top', 'right', 'bottom' }) do
            local value = bounds[key]
            if type(value) ~= 'number' or value < 0 or value > 1 or value ~= value then valid = false end
        end
        if valid and bounds.left < bounds.right and bounds.top < bounds.bottom then panelBounds = bounds end
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local inventoryOpen = LocalPlayer.state.invOpen == true
        if inventoryPositionEditing and not inventoryOpen then finishPositionEditing() end
        if inventoryOpen and panelBounds and not positionEditing then
            local x, y = GetNuiCursorPosition()
            local width, height = GetActiveScreenResolution()
            local inside = width > 0 and height > 0
                and x / width >= panelBounds.left and x / width <= panelBounds.right
                and y / height >= panelBounds.top and y / height <= panelBounds.bottom
            if not inside then
                inventoryHoverReady = true
            elseif inventoryHoverReady and IsNuiFocused() and IsNuiFocusKeepingInput()
                and (not inventoryReleaseX or math.abs(x - inventoryReleaseX) + math.abs(y - inventoryReleaseY) > 3) then
                inventoryHoverReady = false
                editActionPanel(true)
            end
        elseif not inventoryOpen then
            inventoryHoverReady = true
            inventoryReleaseX, inventoryReleaseY = nil, nil
        end
        Wait(inventoryOpen and 25 or 200)
    end
end)


local function playerIsDown()
    local state = LocalPlayer.state.dead
    local data = exports.qbx_core:GetPlayerData()
    local metadata = data and data.metadata or {}
    return IsEntityDead(PlayerPedId()) or state == true or state == 1 or state == 2
        or state == 'dead' or state == 'laststand'
        or metadata.isdead == true or metadata.inlaststand == true
end

CreateThread(function()
    while true do
        local down = playerIsDown()
        if deathPositionEditing and not down then finishPositionEditing() end
        if down then
            DisableControlAction(0, 37, true)
            if IsDisabledControlJustPressed(0, 37) and not positionEditing and not IsNuiFocused() then
                editActionPanel(false, true)
            end
        end
        Wait(down and 0 or 200)
    end
end)

exports('editActionPanel', editActionPanel)

RegisterNUICallback('actionPanelReady', function(_, cb)
    finishPositionEditing()
    cb({ ok = true })
end)

RegisterNUICallback('actionPanelEditing', function(data, cb)
    if not positionEditing or data.session ~= positionSession or IsPauseMenuActive()
        or (IsNuiFocused() and LocalPlayer.state.invOpen ~= true) then
        cb({ ok = false })
        return
    end
    positionKeepInput = IsNuiFocusKeepingInput()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    positionFocused = true
    cb({ ok = true })
end)

RegisterNUICallback('actionPanelPositionFinish', function(data, cb)
    if not positionEditing or data.session ~= positionSession then cb({ ok = false }); return end
    if data.save == true then
        if data.position ~= false and not validPosition(data.position) then cb({ ok = false }); return end
        position = data.position or nil
        if position then SetResourceKvp('actionPanelPosition', json.encode(position))
        else DeleteResourceKvp('actionPanelPosition') end
    end
    finishPositionEditing()
    cb({ ok = true })
end)

if lib.addKeybind then
    lib.addKeybind({
        name = 'ptech_mediora_core_action_panel_move',
        description = 'Medioraパネルの位置をドラッグで調整',
        defaultKey = (Config.ActionPanel and Config.ActionPanel.moveKey) or 'F7',
        onPressed = editActionPanel,
    })
end

AddEventHandler('QBCore:Client:OnPlayerUnload', finishPositionEditing)

exports('setActionPanel', setActionPanel)
exports('removeActionPanel', removeActionPanel)
exports('nextActionPanel', nextActionPanel)

if lib.addKeybind then
    keybind = lib.addKeybind({
        name = 'ptech_mediora_core_action_panel_next',
        description = 'Medioraの右側表示を切り替える',
        defaultKey = switchKey,
        onPressed = function(self)
            switchKey = self.currentKey or switchKey
            nextActionPanel()
        end,
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    finishPositionEditing()
    panels = {}
    send('clearPanels')
end)
