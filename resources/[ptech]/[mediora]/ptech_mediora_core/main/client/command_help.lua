local settings = Config.CommandHelp
if not settings or not settings.enabled then return end

local resourceName = GetCurrentResourceName()
local generation = 0
local registered = {}
local function chatStarted()
    for _, name in ipairs(settings.chatResources) do
        if GetResourceState(name) == 'started' then return true end
    end
    return false
end

local function removeSuggestions()
    for name in pairs(registered) do TriggerEvent('chat:removeSuggestion', '/' .. name) end
    registered = {}
end

local function fetchCommands()
    local version = generation + 1
    generation = version
    local ok, result = pcall(lib.callback.await, 'ptech_mediora_core:commandHelp', false)
    if generation ~= version then return nil end
    if not ok or type(result) ~= 'table' or not result.ok or type(result.commands) ~= 'table' then
        removeSuggestions()
        return nil
    end
    removeSuggestions()
    -- Compatible chat resources may use a different resource name.
    -- Emit the local suggestion event directly; chat:init replays it once the UI is ready.
    for _, command in ipairs(result.commands) do
        local help = command.help
        if command.example then help = help .. ' 例: ' .. command.example end
        TriggerEvent('chat:addSuggestion', '/' .. command.name, help, command.params or {})
        registered[command.name] = true
    end
    return result.commands
end

local function showHelp(message, failed)
    if chatStarted() then
        TriggerEvent('chat:addMessage', {
            color = failed and { 220, 110, 100 } or { 108, 221, 196 },
            multiline = true, args = { 'Mediora', message },
        })
    else
        lib.notify({ title = 'Mediora', description = message, type = failed and 'error' or 'inform', duration = 12000 })
    end
end

RegisterCommand('mediorahelp', function(_, args)
    CreateThread(function()
        local commands = fetchCommands()
        if not commands then
            showHelp('コマンド情報を取得できませんでした。少し待ってもう一度お試しください。', true)
            return
        end
        if #args > 1 then
            showHelp('使い方: /mediorahelp [コマンド名]' .. string.char(10) .. '例: /mediorahelp mediora_tablet_close', true)
            return
        end
        if args[1] then
            local requested = tostring(args[1]):gsub('^/', ''):lower()
            for _, command in ipairs(commands) do
                if command.name:lower() == requested then
                    local lines = { command.help, '使い方: ' .. command.usage }
                    for _, param in ipairs(command.params or {}) do
                        lines[#lines + 1] = param.name .. ': ' .. param.help
                    end
                    if command.example then lines[#lines + 1] = '例: ' .. command.example end
                    showHelp(table.concat(lines, string.char(10)))
                    return
                end
            end
            showHelp('そのコマンドは見つからないか、使用権限がありません。/mediorahelp で一覧を確認してください。', true)
            return
        end
        local lines = { 'Coreのコマンド一覧' }
        for _, command in ipairs(commands) do
            lines[#lines + 1] = command.usage .. ' — ' .. command.help
        end
        lines[#lines + 1] = '詳しい使い方: /mediorahelp コマンド名'
        showHelp(table.concat(lines, string.char(10)))
    end)
end, false)

local function scheduleRefresh()
    generation = generation + 1
    local version = generation
    SetTimeout(1000, function()
        if generation ~= version then return end
        CreateThread(fetchCommands)
    end)
end

local function isCommandResource(resource)
    for _, command in ipairs(settings.commands) do
        if command.resource == resource then return true end
    end
    return false
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == resourceName or isCommandResource(resource) then scheduleRefresh(); return end
    for _, name in ipairs(settings.chatResources) do
        if resource == name then scheduleRefresh(); return end
    end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', scheduleRefresh)
RegisterNetEvent('ptech_mediora_core:chatReady', scheduleRefresh)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == resourceName then
        generation = generation + 1
        removeSuggestions()
    elseif isCommandResource(resource) then
        scheduleRefresh()
    end
end)
