local settings = Config.CommandHelp
if not settings or not settings.enabled then return end

lib.callback.register('ptech_mediora_core:commandHelp', function(source)
    local commands = {}
    for _, command in ipairs(settings.commands) do
        if (not command.ace or IsPlayerAceAllowed(source, command.ace))
            and (not command.resource or GetResourceState(command.resource) == 'started') then
            commands[#commands + 1] = {
                name = command.name, help = command.help, params = command.params,
                usage = command.usage, example = command.example,
            }
        end
    end
    return { ok = true, commands = commands }
end)

-- The standard chat sends this after its input UI has mounted.
-- Re-register our descriptions after its automatic command suggestions.
AddEventHandler('chat:init', function()
    local player = source
    if type(player) == 'number' and player > 0 then
        TriggerClientEvent('ptech_mediora_core:chatReady', player)
    end
end)
