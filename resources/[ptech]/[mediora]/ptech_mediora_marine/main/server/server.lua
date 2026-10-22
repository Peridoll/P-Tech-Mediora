local floats, fins, activated, deathSince, pending, last = {}, {}, {}, {}, {}, {}
local sequence = 0
local revision = 0

local function playerData(id)
    local player = exports.qbx_core:GetPlayer(id)
    return player and player.PlayerData
end

local function down(id)
    local data = playerData(id)
    return data and Marine.down(Player(id).state, data.metadata) or false
end

local function exists(id)
    return Marine.validId(id) and GetPlayerPed(id) ~= 0 and playerData(id) ~= nil
end

local function has(id, item)
    return (exports.ox_inventory:Search(id, 'count', item) or 0) > 0
end

local function limited(id)
    local now = GetGameTimer()
    if last[id] and now - last[id] < 750 then return true end
    last[id] = now
    return false
end

local function setFins(id, enabled)
    fins[id] = enabled and GetPlayerPed(id) or nil
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:fins', id, enabled, revision)
end

local function clearFloat(id)
    if not floats[id] then return end
    floats[id] = nil
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:flotation', -1, id, nil, revision)
end

local function countdownReady(id)
    local started = deathSince[id]
    return started ~= nil and GetGameTimer() - started >= math.max(0, Config.Flotation.Countdown) * 1000
end

local function eligible(id)
    return Config.Flotation.Enabled and exists(id) and down(id) and countdownReady(id)
        and not activated[id] and not floats[id] and not Marine.busy(Player(id).state)
        and GetVehiclePedIsIn(GetPlayerPed(id)) == 0
end

lib.callback.register('ptech_mediora_marine:toggleFins', function(src)
    if limited(src) then return false end
    if fins[src] then setFins(src, false); return true end
    local data = playerData(src)
    if not Config.Fins.Enabled or not data or not Marine.finsAllowed(data.job)
        or down(src) or not has(src, Config.Fins.Item) then return false end
    setFins(src, true)
    return true
end)

-- クライアントは水面を観測するだけで、起動時刻・死亡状態・座標・浮上状態はサーバーが確認する。
lib.callback.register('ptech_mediora_marine:activateFlotation', function(src)
    if limited(src) or pending[src] or not eligible(src) then return false end
    local token = { ped = GetPlayerPed(src), patientId = playerData(src).citizenid,
        bucket = GetPlayerRoutingBucket(src) }
    pending[src] = token
    SetTimeout(5000, function() if pending[src] == token then pending[src] = nil end end)

    local ok, observation = pcall(lib.callback.await, 'ptech_mediora_marine:water', src)
    if pending[src] ~= token then return false end
    pending[src] = nil
    if not ok or not eligible(src) or GetPlayerPed(src) ~= token.ped
        or playerData(src).citizenid ~= token.patientId
        or GetPlayerRoutingBucket(src) ~= token.bucket then return false end

    local coords = GetEntityCoords(token.ped)
    if not Marine.validSurface(coords, observation) then return false end
    local surface = observation.surface
    if MarineServer.WaterHeight then
        surface = MarineServer.WaterHeight(coords, token.bucket)
        if not Marine.finite(surface) or math.abs(surface - observation.surface) > Config.Flotation.SurfaceTolerance then
            return false
        end
    end

    sequence = sequence + 1
    floats[src] = { x = coords.x, y = coords.y, z = coords.z,
        surface = surface + Config.Flotation.SurfaceOffset, ticket = sequence,
        ped = token.ped, patientId = token.patientId, bucket = token.bucket }
    activated[src] = true -- 同じ死亡中の再起動を防ぐ。蘇生後の次回死亡では解除される。
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:flotation', -1, src, floats[src], revision)
    return true
end)

lib.callback.register('ptech_mediora_marine:snapshot', function(src)
    return { floats = floats, fins = fins[src] ~= nil, revision = revision }
end)

CreateThread(function()
    while true do
        Wait(250)
        local online = {}
        for _, value in ipairs(GetPlayers()) do
            local id = tonumber(value)
            if id and exists(id) then
                online[id] = true
                if down(id) then
                    deathSince[id] = deathSince[id] or GetGameTimer()
                else
                    deathSince[id], activated[id] = nil, nil
                    clearFloat(id)
                end
            end
        end

        for id, ped in pairs(fins) do
            local data = playerData(id)
            if not Config.Fins.Enabled or not data or GetPlayerPed(id) ~= ped
                or not Marine.finsAllowed(data.job) or down(id) or not has(id, Config.Fins.Item) then setFins(id, false) end
        end
        for id, float in pairs(floats) do
            if not online[id] or GetPlayerPed(id) ~= float.ped or not down(id)
                or playerData(id).citizenid ~= float.patientId
                or Marine.busy(Player(id).state) or GetPlayerRoutingBucket(id) ~= float.bucket
                or GetVehiclePedIsIn(GetPlayerPed(id)) ~= 0 then clearFloat(id) end
        end
        for id in pairs(deathSince) do
            if not online[id] then deathSince[id], activated[id], pending[id], last[id] = nil, nil, nil, nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local id = source
    clearFloat(id)
    fins[id], activated[id], deathSince[id], pending[id], last[id] = nil, nil, nil, nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TriggerClientEvent('ptech_mediora_marine:reset', -1) end
end)
