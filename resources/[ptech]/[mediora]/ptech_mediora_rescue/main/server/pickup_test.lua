local event = 'ptech_mediora_rescue:pickupTest:'
local sessions = {}
local downSince = {}

local function release(src, session, arrived)
    if sessions[src] ~= session then return false end
    sessions[src] = nil
    if GetPlayerRoutingBucket(src) ~= session.privateBucket then return false end
    local ped = GetPlayerPed(src)
    local samePed = ped == session.ped and DoesEntityExist(ped)
    if samePed then
        local position = arrived and Config.Hospital.Entrance or session.origin
        SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
    end
    SetPlayerRoutingBucket(src, session.originBucket)
    return samePed
end

local function isDown(src, ped, data)
    local dead = Player(src).state.dead
    local metadata = data and data.metadata or {}
    return GetEntityHealth(ped) <= 0 or dead == true or dead == 1 or dead == 2
        or dead == 'dead' or dead == 'laststand' or metadata.isdead == true or metadata.inlaststand == true
end

local function status(src)
    local ped = GetPlayerPed(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = player and player.PlayerData
    if not data or ped == 0 or not DoesEntityExist(ped) or not isDown(src, ped, data) then
        downSince[src] = nil
        return { enabled = false }
    end
    local now = GetGameTimer()
    local down = downSince[src]
    if not down or down.ped ~= ped or down.citizenid ~= data.citizenid then
        down = { ped = ped, citizenid = data.citizenid, started = now }
        downSince[src] = down
    end
    local isPd = false
    for _, job in ipairs(Config.AllowedJobs) do
        if data.job and data.job.name == job then isPd = true; break end
    end
    local enabled, duration = exports.ptech_mediora_core:getRescueSettings(isPd)
    return { enabled = enabled, duration = duration, remaining = math.max(0, duration - (now - down.started)) }
end

lib.callback.register(event .. 'status', status)

CreateThread(function()
    while true do
        for src in pairs(downSince) do
            local ped = GetPlayerPed(src)
            local player = exports.qbx_core:GetPlayer(src)
            if ped == 0 or not DoesEntityExist(ped) or ped ~= downSince[src].ped
                or not player or not isDown(src, ped, player.PlayerData) then downSince[src] = nil end
        end
        Wait(250)
    end
end)

lib.callback.register(event .. 'begin', function(src, request)
    if type(request) ~= 'number' or sessions[src] then return false end
    local ped = GetPlayerPed(src)
    local eligibility = status(src)
    if not eligibility.enabled or eligibility.remaining > 0 then return false end
    local originBucket = GetPlayerRoutingBucket(src)
    local privateBucket = Config.TransportBucketBase + src
    for _, id in ipairs(GetPlayers()) do
        if GetPlayerRoutingBucket(tonumber(id)) == privateBucket then return false end
    end
    local session = {
        request = request, ped = ped, origin = GetEntityCoords(ped),
        originBucket = originBucket, privateBucket = privateBucket,
    }
    sessions[src] = session
    SetRoutingBucketPopulationEnabled(privateBucket, false)
    SetPlayerRoutingBucket(src, privateBucket)
    SetTimeout(Config.PreparationTimeout + math.ceil(Config.Helicopter.TestDuration * 1000), function()
        release(src, session, false)
    end)
    return true
end)

lib.callback.register(event .. 'finish', function(src, request)
    local session = sessions[src]
    local player = exports.qbx_core:GetPlayer(src)
    if not session or session.request ~= request or GetPlayerPed(src) ~= session.ped
        or not player or not isDown(src, session.ped, player.PlayerData) then return false end
    return release(src, session, true)
end)

RegisterNetEvent(event .. 'cleanup', function(request)
    local src = source
    local session = sessions[src]
    if session and session.request == request then release(src, session, false) end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    downSince[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, session in pairs(sessions) do release(src, session, false) end
end)

print('[rescue_pickup] SERVER_READY build=local-transport-v1')
