-- 浮上開始条件・退避完了・目標座標をサーバーで管理する。
-- 対象クライアントはサーバー配信の目標座標に沿って自分のPedだけを動かす。

local floats, activated, deathSince, pending, last = {}, {}, {}, {}, {}
local sequence, revision, tokenSequence = 0, 0, 0

local function playerData(id)
    local player = exports.qbx_core:GetPlayer(id)
    return player and player.PlayerData
end

local function exists(id)
    return Marine.validId(id) and GetPlayerPed(id) ~= 0 and playerData(id) ~= nil
end

local function down(id)
    local data = playerData(id)
    return data and Marine.down(Player(id).state, data.metadata) or false
end

local function limited(id)
    local now = GetGameTimer()
    if last[id] and now - last[id] < 750 then return true end
    last[id] = now
    return false
end

local function clearFloat(id)
    if not floats[id] then return end
    floats[id] = nil
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:flotation', -1, id, nil, revision)
end

local function publicFloat(float)
    return { x = float.x, y = float.y, z = float.z, surface = float.surface,
        ticket = float.ticket, blocked = float.blocked == true }
end

local function countdownReady(id)
    return deathSince[id] ~= nil
        and GetGameTimer() - deathSince[id] >= math.max(0, Config.Flotation.Countdown) * 1000
end

local function eligible(id)
    return Config.Flotation.Enabled and exists(id) and down(id) and countdownReady(id)
        and not activated[id] and not floats[id] and not Marine.busy(Player(id).state)
end

local function requestValid(src, request)
    local data = playerData(src)
    return pending[src] == request and GetGameTimer() <= request.expires
        and eligible(src) and GetPlayerPed(src) == request.ped
        and data and data.citizenid == request.patientId
        and GetPlayerRoutingBucket(src) == request.bucket
end

local function readWater(src, request)
    local ok, observation = pcall(lib.callback.await, 'ptech_mediora_marine:flotationWater', src)
    if not ok or not requestValid(src, request) then return nil end

    local coords = GetEntityCoords(request.ped)
    if not Marine.validSurface(coords, observation) then return nil end
    local surface = observation.surface
    if MarineServer.WaterHeight then
        surface = MarineServer.WaterHeight(coords, request.bucket)
        if not Marine.finite(surface)
            or math.abs(surface - observation.surface) > Config.Flotation.SurfaceTolerance then return nil end
    end
    return { coords = coords, surface = surface }
end

local function startFloat(src, request, water)
    if not requestValid(src, request) or GetVehiclePedIsIn(request.ped) ~= 0 or not water then
        if pending[src] == request then pending[src] = nil end
        return false
    end

    sequence = sequence + 1
    local now = GetGameTimer()
    floats[src] = {
        x = water.coords.x, y = water.coords.y, z = water.coords.z,
        surface = water.surface + Config.Flotation.SurfaceOffset,
        ticket = sequence, ped = request.ped, patientId = request.patientId, bucket = request.bucket,
        updatedAt = now,
    }
    pending[src] = nil
    activated[src] = true
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:flotation', -1, src, publicFloat(floats[src]), revision)
    return true
end

local function newRequest(src)
    local data = playerData(src)
    if not data then return nil end
    tokenSequence = tokenSequence + 1
    local request = {
        token = tokenSequence, stage = 'observe', ped = GetPlayerPed(src),
        patientId = data.citizenid, bucket = GetPlayerRoutingBucket(src),
        expires = GetGameTimer() + 5000,
    }
    pending[src] = request
    SetTimeout(5000, function()
        if pending[src] == request then pending[src] = nil end
    end)
    return request
end

lib.callback.register('ptech_mediora_marine:activateFlotation', function(src)
    if limited(src) or pending[src] or not eligible(src) then return false end
    local request = newRequest(src)
    if not request then return false end

    local water = readWater(src, request)
    if not water then pending[src] = nil; return false end
    if GetVehiclePedIsIn(request.ped) ~= 0 then
        request.stage = 'eject'
        return { ejectToken = request.token }
    end
    return startFloat(src, request, water)
end)

lib.callback.register('ptech_mediora_marine:confirmFlotationEjection', function(src, token)
    local request = pending[src]
    if type(token) ~= 'number' or not request or request.stage ~= 'eject'
        or request.token ~= token or not requestValid(src, request)
        or GetVehiclePedIsIn(request.ped) ~= 0 then return false end

    request.stage = 'confirm'
    local water = readWater(src, request)
    return startFloat(src, request, water)
end)

lib.callback.register('ptech_mediora_marine:flotationSnapshot', function()
    local snapshot = {}
    for id, float in pairs(floats) do snapshot[id] = publicFloat(float) end
    return { floats = snapshot, revision = revision }
end)

lib.callback.register('ptech_mediora_marine:reportFlotationObstacle', function(src, ticket, route)
    local float = floats[src]
    if not float or type(ticket) ~= 'number' or ticket ~= float.ticket or type(route) ~= 'table'
        or not Marine.finite(route.x) or not Marine.finite(route.y) or not Marine.finite(route.z)
        or GetPlayerPed(src) ~= float.ped or not down(src) or Marine.busy(Player(src).state)
        or GetPlayerRoutingBucket(src) ~= float.bucket or GetVehiclePedIsIn(float.ped) ~= 0 then return false end

    local dx, dy = route.x - float.x, route.y - float.y
    if dx * dx + dy * dy > 100.0 or math.abs(route.z - float.z) > 3.0 then return false end

    if route.blocked == true then
        float.blocked = true
        float.z = math.min(float.z, route.z)
    else
        float.x, float.y = route.x, route.y
        float.blocked = false
    end
    float.updatedAt = GetGameTimer()
    revision = revision + 1
    TriggerClientEvent('ptech_mediora_marine:flotation', -1, src, publicFloat(float), revision)
    return true
end)

-- サーバーが上昇目標Zを刻み、各クライアントへ同じ進行状態を配信する。
CreateThread(function()
    while true do
        Wait(100)
        local now = GetGameTimer()
        for id, float in pairs(floats) do
            if not float.blocked then
                local elapsed = math.max(0, math.min(now - float.updatedAt, 500)) / 1000
                float.updatedAt = now
                local nextZ = math.min(float.surface,
                    float.z + math.max(0.0, Config.Flotation.RiseSpeed) * elapsed)
                if nextZ > float.z then
                    float.z = nextZ
                    revision = revision + 1
                    TriggerClientEvent('ptech_mediora_marine:flotation', -1, id, publicFloat(float), revision)
                end
            end
        end
    end
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

        for id, float in pairs(floats) do
            local data = playerData(id)
            if not online[id] or GetPlayerPed(id) ~= float.ped or not data or not down(id)
                or data.citizenid ~= float.patientId or Marine.busy(Player(id).state)
                or GetPlayerRoutingBucket(id) ~= float.bucket or GetVehiclePedIsIn(GetPlayerPed(id)) ~= 0 then
                clearFloat(id)
            end
        end
        for id in pairs(deathSince) do
            if not online[id] then deathSince[id], activated[id], pending[id], last[id] = nil, nil, nil, nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local id = source
    clearFloat(id)
    activated[id], deathSince[id], pending[id], last[id] = nil, nil, nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TriggerClientEvent('ptech_mediora_marine:resetFlotation', -1) end
end)
