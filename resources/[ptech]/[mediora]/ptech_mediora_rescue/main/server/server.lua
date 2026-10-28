-- 要請の正当性・重複・死亡セッションをサーバー側で管理する。
local sessions, lastRequest, aircraft = {}, {}, {}
local function removeAircraft(src)
    local a = aircraft[src]
    if not a then return end
    aircraft[src] = nil
    if a.pilot and DoesEntityExist(a.pilot) then DeleteEntity(a.pilot) end
    if a.heli and DoesEntityExist(a.heli) then DeleteEntity(a.heli) end
end
local function data(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData
end
local function valid(src)
    local d = data(src)
    local ped = GetPlayerPed(src)
    return d and d.citizenid and Rescue.allowed(d.job) and ped ~= 0
        and Rescue.down(Player(src).state, d.metadata), d
end
local function session(src)
    local ok, d = valid(src)
    if not ok then return nil end
    local s = sessions[src]
    if not s or s.id ~= d.citizenid then
        s = { id = d.citizenid, started = GetGameTimer(), used = false, phase = nil }
        sessions[src] = s
    end
    return s
end
lib.callback.register('ptech_mediora_rescue:status', function(src)
    local s = session(src)
    if not s then return { eligible = false } end
    return { eligible = true, remaining = Rescue.remaining(s.started, GetGameTimer()), used = s.used }
end)
lib.callback.register('ptech_mediora_rescue:request', function(src)
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 500 then return false end
    lastRequest[src] = now
    local s = session(src)
    if not s or s.used or Rescue.remaining(s.started, now) > 0 then return false end
    local ped = GetPlayerPed(src)
    local bucket = GetPlayerRoutingBucket(src)
    local coords = GetEntityCoords(ped)
    local heli = CreateVehicleServerSetter(joaat(Config.Helicopter.Model), 'heli', coords.x, coords.y, coords.z + Config.Helicopter.HoverOffset, GetEntityHeading(ped))
    if not heli or heli == 0 or not DoesEntityExist(heli) then return false end
    SetEntityOrphanMode(heli, 2)
    SetEntityRoutingBucket(heli, bucket)
    local pilot = CreatePed(4, joaat(Config.Helicopter.Pilot), coords.x, coords.y, coords.z + Config.Helicopter.HoverOffset, GetEntityHeading(ped), true, true)
    if not pilot or pilot == 0 or not DoesEntityExist(pilot) then DeleteEntity(heli); return false end
    SetEntityRoutingBucket(pilot, bucket)
    SetEntityOrphanMode(pilot, 2)
    s.used, s.phase, s.requestedAt, s.ped, s.bucket = true, 'requested', now, ped, bucket
    aircraft[src] = { heli = heli, pilot = pilot, created = now, bucket = bucket }
    TriggerClientEvent('ptech_mediora_rescue:dispatch', src, NetworkGetNetworkIdFromEntity(heli), NetworkGetNetworkIdFromEntity(pilot))
    return true
end)
-- 完了通知はクライアントから受けても、サーバー上の予約状態と死亡を再確認する。
RegisterNetEvent('ptech_mediora_rescue:phase', function(phase)
    local src = source
    local s = sessions[src]
    local ok, d = valid(src)
    if not s or not s.used or not ok or s.id ~= d.citizenid or s.ped ~= GetPlayerPed(src)
        or s.bucket ~= GetPlayerRoutingBucket(src) or s.phase == 'invalid' then return end
    if phase == 'transporting' and s.phase == 'requested' then
        if GetGameTimer() - s.requestedAt < Config.Helicopter.PickupSeconds * 1000
            or GetGameTimer() - s.requestedAt > 15000 then return end
        local a = aircraft[src]
        if not a or GetVehiclePedIsIn(s.ped) ~= a.heli then return end
        s.phase, s.transportAt = 'transporting', GetGameTimer()
        for _, id in ipairs(GetPlayers()) do
            local target = tonumber(id)
            local ed = data(target)
            if ed and ed.job and ed.job.name == Config.EMSJob and ed.job.onduty == true then
                TriggerClientEvent('ptech_mediora_rescue:emsNotify', target, '搬送開始')
            end
        end
    elseif phase == 'arrived' and s.phase == 'transporting' then
        if GetGameTimer() - (s.transportAt or 0) < 1000 then return end
        local coords, dest = GetEntityCoords(s.ped), Config.Hospital.Entrance
        local dx, dy, dz = coords.x-dest.x, coords.y-dest.y, coords.z-dest.z
        if dx*dx + dy*dy + dz*dz > 625 then return end
        s.phase = 'arrived'
        for _, id in ipairs(GetPlayers()) do
            local target = tonumber(id)
            local ed = data(target)
            if ed and ed.job and ed.job.name == Config.EMSJob and ed.job.onduty == true then
                TriggerClientEvent('ptech_mediora_rescue:emsNotify', target, '病院到着')
            end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(250)
        local online = {}
        for _, v in ipairs(GetPlayers()) do
            local src = tonumber(v)
            if src then
                online[src] = true
                if not valid(src) then
                    removeAircraft(src)
                    sessions[src] = nil
                else
                    local current = session(src)
                    if current and current.used and (current.ped ~= GetPlayerPed(src)
                        or current.bucket ~= GetPlayerRoutingBucket(src)) then
                        current.phase = 'invalid'; removeAircraft(src)
                    end
                end
            end
        end
        for src in pairs(sessions) do if not online[src] then removeAircraft(src); sessions[src] = nil end end
    end
end)
AddEventHandler('playerDropped', function()
    removeAircraft(source)
    sessions[source], lastRequest[source] = nil, nil
end)
lib.callback.register('ptech_mediora_rescue:aircraftSnapshot', function(src)
    local result = {}
    local bucket = GetPlayerRoutingBucket(src)
    for owner, a in pairs(aircraft) do
        if a.bucket == bucket and DoesEntityExist(a.heli) and DoesEntityExist(a.pilot) then
            result[#result + 1] = { heli = NetworkGetNetworkIdFromEntity(a.heli), pilot = NetworkGetNetworkIdFromEntity(a.pilot), owner = owner,
                published = GetGameTimer() - a.created >= Config.Helicopter.PublishAfter * 1000 }
        end
    end
    return result
end)
RegisterNetEvent('ptech_mediora_rescue:finish', function()
    local src = source
    local s = sessions[src]
    if not s or not s.used or s.phase == 'invalid' then return end
    removeAircraft(src)
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(aircraft) do removeAircraft(src) end
end)
CreateThread(function()
    while true do
        Wait(1000)
        for src, a in pairs(aircraft) do
            if GetGameTimer() - a.created > (Config.Helicopter.MaxFlightSeconds + Config.Helicopter.LandingTimeout + 30) * 1000 then
                removeAircraft(src)
            end
        end
    end
end)
