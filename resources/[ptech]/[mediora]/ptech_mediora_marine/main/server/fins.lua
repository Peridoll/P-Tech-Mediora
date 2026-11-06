local equipped = {}
local lastToggle = {}

local function playerData(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData
end

local function hasFins(src)
    return (exports.ox_inventory:Search(src, 'count', Config.Fins.Item) or 0) > 0
end

local function allowedJob(job)
    if not job or job.onduty ~= true then return false end
    for _, name in ipairs(Config.Fins.Jobs) do
        if job.name == name then return true end
    end
    return false
end

local function eligible(src)
    local data = playerData(src)
    return Config.Fins.Enabled and data and allowedJob(data.job)
        and not Marine.down(Player(src).state, data.metadata) and hasFins(src)
end

local function setEquipped(src, state)
    equipped[src] = state or nil
    TriggerClientEvent('ptech_mediora_marine:finsState', src, state == true)
end

lib.callback.register('ptech_mediora_marine:toggleFins', function(src)
    local now = GetGameTimer()
    if lastToggle[src] and now - lastToggle[src] < 750 then return nil end
    lastToggle[src] = now

    if equipped[src] then
        setEquipped(src, false)
        return false
    end
    if not eligible(src) then return nil end

    setEquipped(src, true)
    return true
end)

CreateThread(function()
    while true do
        Wait(500)
        for src in pairs(equipped) do
            if not eligible(src) then setEquipped(src, false) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    equipped[src], lastToggle[src] = nil, nil
end)
