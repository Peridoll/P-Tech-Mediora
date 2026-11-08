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
    panels = {}
    send('clearPanels')
end)
