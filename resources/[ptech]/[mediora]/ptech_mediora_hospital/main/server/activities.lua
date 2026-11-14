local namespace = 'ptech_mediora_hospital:'
local hospitals = {}
local tasks = {}
local claims = {}
local sequence = 0
local claimSequence = 0

local function employee(source)
    local player = exports.qbx_core:GetPlayer(source)
    local data = player and player.PlayerData
    if Hospital.canWork(data, Player(source).state.dead) then return data.citizenid end
end

local function nearby(source, task)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetEntityHealth(ped) > 0
        and GetPlayerRoutingBucket(source) == (task.hospital.config.bucket or 0)
        and #(GetEntityCoords(ped) - task.spot.coords) <= Hospital.interactionDistance + 0.75
end

local function resetCooldown(group, now)
    local range = group.config.cooldown
    group.readyAt = now + math.random(range[1] * 60, range[2] * 60)
end

for hospitalId, config in pairs(Hospital.hospitals) do
    local hospital = { config = config, occupied = {}, groups = {}, count = 0 }
    hospitals[hospitalId] = hospital
    for index, spot in ipairs(config.spots) do
        local activity = assert(Hospital.activities[spot.activity], 'Unknown hospital activity: ' .. spot.activity)
        local group = hospital.groups[spot.activity]
        if not group then
            group = { config = activity, spots = {}, count = 0 }
            resetCooldown(group, os.time())
            hospital.groups[spot.activity] = group
        end
        group.spots[#group.spots + 1] = index
    end
end

local function draw(now)
    for _, hospital in pairs(hospitals) do
        local eligible = {}
        for _, group in pairs(hospital.groups) do
            if now >= group.readyAt and group.count < group.config.limit then
                eligible[#eligible + 1] = group
            end
        end
        while hospital.count < hospital.config.limit and #eligible > 0 do
            local group = table.remove(eligible, math.random(#eligible))
            local free = {}
            for _, index in ipairs(group.spots) do
                if not hospital.occupied[index] then free[#free + 1] = index end
            end
            if #free > 0 and math.random(100) <= group.config.chance then
                local index = free[math.random(#free)]
                sequence = sequence + 1
                local id = ('%d:%d:%d'):format(os.time(), GetGameTimer(), sequence)
                tasks[id] = { hospital = hospital, group = group, index = index, spot = hospital.config.spots[index] }
                hospital.occupied[index] = true
                hospital.count = hospital.count + 1
                group.count = group.count + 1
                if Hospital.cooldownStart == 'complete' then
                    group.readyAt = math.huge
                else
                    resetCooldown(group, now)
                end
            end
        end
    end
end

local function release(task)
    claims[task.worker] = nil
    task.worker = nil
    task.character = nil
    task.token = nil
end

local function canContinue(source, task)
    return employee(source) == task.character and nearby(source, task)
end

lib.callback.register(namespace .. 'list', function(source)
    local result = {}
    if not employee(source) then return result end
    local bucket = GetPlayerRoutingBucket(source)
    for id, task in pairs(tasks) do
        if bucket == (task.hospital.config.bucket or 0) then
            result[#result + 1] = { id = id, coords = task.spot.coords, activity = task.spot.activity, available = not task.worker }
        end
    end
    return result
end)

lib.callback.register(namespace .. 'start', function(source, id)
    local task = tasks[id]
    local character = employee(source)
    if not task or task.worker or claims[source] or not character or not nearby(source, task) then return false end
    task.worker = source
    task.character = character
    task.startedAt = GetGameTimer()
    claimSequence = claimSequence + 1
    task.token = claimSequence
    claims[source] = task
    return task.token
end)

RegisterNetEvent(namespace .. 'cancel', function(id, token)
    local task = tasks[id]
    if task and task.worker == source and task.token == token and not task.paying then release(task) end
end)

lib.callback.register(namespace .. 'finish', function(source, id, token)
    local task = tasks[id]
    if not task or task.worker ~= source or task.token ~= token or task.paying then return false end
    if not canContinue(source, task) or GetGameTimer() - task.startedAt < Hospital.duration then
        release(task)
        return false
    end

    task.paying = true
    local ok, awarded = pcall(function()
        return exports.ptech_mediora_core:AddPoints(source, Hospital.points, 'Hospital: ' .. task.spot.activity)
    end)
    task.paying = nil
    if not ok or not awarded then
        release(task)
        return false
    end

    tasks[id] = nil
    local hospital, group = task.hospital, task.group
    hospital.occupied[task.index] = nil
    hospital.count = hospital.count - 1
    group.count = group.count - 1
    if Hospital.cooldownStart == 'complete' then resetCooldown(group, os.time()) end
    release(task)
    return true
end)

AddEventHandler('playerDropped', function()
    local task = claims[source]
    if task and not task.paying then release(task) end
end)

CreateThread(function()
    local nextDraw = os.time() + Hospital.drawInterval
    while true do
        Wait(1000)
        local now = os.time()
        if now >= nextDraw then
            draw(now)
            nextDraw = now + Hospital.drawInterval
        end
        for source, task in pairs(claims) do
            if not task.paying and (not canContinue(source, task)
                or GetGameTimer() - task.startedAt > Hospital.duration + 15000) then
                release(task)
            end
        end
    end
end)
