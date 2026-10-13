-- ems-escort / server

local escorts = {}     -- [運ぶ人] = { [運ばれる人] = { slot = n, style = 'cuffed' | 'dead' | 'carry', carryType = id } }
local escortedBy = {}  -- [運ばれる人] = 運ぶ人
local lastRequest = {}
local pendingNpcStarts = {}
local vehiclePatients = {}
local testBodies = {}
local isLivingDownDummy

local function stateValue(v)
    -- wasabi_ambulance v1 は 'dead' / 'laststand'、v2 は 0/1/2 または true
    if v == nil or v == false or v == 0 then return nil end
    return v
end

local npcEntities = {}
local nextNpcTicket = 0

local function targetPed(id)
    if id > 0 then return GetPlayerPed(id) end
    return NetworkGetEntityFromNetworkId(-id) or 0
end

local function targetState(id)
    return id > 0 and Player(id).state or Entity(targetPed(id)).state
end

local function isNPC(ped)
    if ped == 0 or not DoesEntityExist(ped) or GetEntityType(ped) ~= 1 then return false end
    for _, id in ipairs(GetPlayers()) do
        if GetPlayerPed(tonumber(id)) == ped then return false end
    end
    return true
end

local function targetExists(id)
    if id > 0 then return GetPlayerPing(id) > 0 and GetPlayerPed(id) ~= 0 end
    local ped = targetPed(id)
    return isNPC(ped) and (not npcEntities[id] or npcEntities[id] == ped)
end

local function getMetadata(id)
    if id < 0 then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(id) end)
    return ok and player and player.PlayerData and player.PlayerData.metadata or nil
end

local function targetStatus(id)
    local ped = targetPed(id)
    if id < 0 then return EscortRules.npcStatus(targetState(id), GetEntityHealth(ped)) end
    return EscortRules.playerStatus(targetState(id), getMetadata(id), GetEntityHealth(ped))
end

local function canBeEscorted(id)
    return targetExists(id) and EscortRules.allowed(targetStatus(id), id < 0)
end

local function canEscort(id)
    local ped = GetPlayerPed(id)
    return ped ~= 0 and GetEntityHealth(ped) > 0
        and not EscortRules.restrained(targetStatus(id))
end

local function distanceBetween(a, b)
    local pa, pb = targetPed(a), targetPed(b)
    if pa == 0 or pb == 0 then return 9999.0 end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function notify(id, text, kind)
    TriggerClientEvent('ox_lib:notify', id, { description = text, type = kind or 'inform' })
end

local function countOf(escorter)
    local list = escorts[escorter]
    if not list then return 0 end
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

-- 同じ運び方の中で空いている一番小さい番号
local function freeSlot(escorter, style)
    local used = {}
    for _, info in pairs(escorts[escorter] or {}) do
        if info.style == style then used[info.slot] = true end
    end
    local slot = 1
    while used[slot] do slot = slot + 1 end
    return slot
end

-- Authorization is resolved from qbx_core, never from client job claims.
local function getJob(id)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(id) end)
    return ok and player and player.PlayerData and player.PlayerData.job or nil
end

local function isCarryJob(id)
    local job = getJob(id)
    if not job or (Config.RequireDuty and job.onduty ~= true) then return false end
    for _, name in ipairs(Config.EMSJobs) do
        if name == job.name then return true end
    end
    return false
end

local function validId(value)
    return type(value) == 'number' and value == value and value > 0 and value % 1 == 0
end

local function sameBucket(a, b)
    return GetPlayerRoutingBucket(a) == (b > 0 and GetPlayerRoutingBucket(b) or GetEntityRoutingBucket(targetPed(b)))
end

local function pdNearby(src, veh)
    if not Config.PDPriority or Config.PDPriority.mode == 'disabled' then return false end
    for _, id in ipairs(GetPlayers()) do
        local sid = tonumber(id)
        local job = getJob(sid)
        local ped = GetPlayerPed(sid)
        if job and Config.PDPriority.jobs[job.name] and ped ~= 0
            and (not Config.PDPriority.requireDuty or job.onduty == true)
            and sameBucket(src, sid)
            and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= Config.PDPriority.radius then
            return true
        end
    end
    return false
end

local function carryTypeExists(id)
    for _, t in ipairs(Config.CarryTypes) do
        if t.id == id then return true end
    end
    return false
end

local function hasCarry(escorter)
    for _, info in pairs(escorts[escorter] or {}) do
        if info.style == 'carry' then return true end
    end
    return false
end

local function syncEscorterState(escorter)
    if GetPlayerPing(escorter) <= 0 then return end
    local n = countOf(escorter)
    Player(escorter).state:set('emsEscorting', n > 0 and n or nil, true)
end

-- 1人を離す
-- silent = true のときは相手側の「解放」処理を送らない（車に乗せる時など）
local function stopOne(escorter, target, silent)
    local list = escorts[escorter]
    if not list or not list[target] then return end
    local info = list[target]
    list[target] = nil
    escortedBy[target] = nil
    local remain = countOf(escorter)
    if remain == 0 then escorts[escorter] = nil end

    if target < 0 then
        if DoesEntityExist(info.entity) and targetPed(target) == info.entity then
            Entity(info.entity).state:set('emsEscortedBy', nil, true)
            Entity(info.entity).state:set('emsEscortTicket', nil, true)
        end
        npcEntities[target] = nil
        if not silent then TriggerClientEvent('ptech_mediora_escort:client:releaseNPC', -1, target, info.ticket) end
    elseif GetPlayerPing(target) > 0 then
        Player(target).state:set('emsEscortedBy', nil, true)
        if not silent then
            TriggerClientEvent('ptech_mediora_escort:client:released', target)
        end
    end
    if GetPlayerPing(escorter) > 0 then
        syncEscorterState(escorter)
        TriggerClientEvent('ptech_mediora_escort:client:removeTarget', escorter, target, remain)
    end
end

local function stopAll(escorter)
    local list = escorts[escorter]
    if not list then return end
    local targets = {}
    for target in pairs(list) do targets[#targets + 1] = target end
    for _, target in ipairs(targets) do stopOne(escorter, target) end
end

local function rateLimited(src)
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 400 then return true end
    lastRequest[src] = now
    return false
end

-- エスコート開始・追加（Zキー / ox_target / 車から連れ出す）
local function startEscort(src, target, carryType, vehicleSolo, exiting)
    if pendingNpcStarts[src] or (not vehicleSolo and not exiting and rateLimited(src)) or not isCarryJob(src) then return end
    target = tonumber(target)
    if not target or target ~= target or target % 1 ~= 0 or target == 0 or target == src then return end
    if target < 0 and (-target > 65535 or not Config.Targets.npcs.enabled) then return end
    if target < 0 then
        local pending = { target = target }
        pendingNpcStarts[src] = pending
        local deadline = GetGameTimer() + 1500
        -- Client control and server-visible ownership need not update in the same tick.
        while not pending.cancelled and GetPlayerPing(src) > 0 and GetGameTimer() < deadline
            and (not targetExists(target) or NetworkGetEntityOwner(targetPed(target)) ~= src) do
            Wait(50)
        end
        if pendingNpcStarts[src] == pending then pendingNpcStarts[src] = nil end
        if pending.cancelled or GetPlayerPing(src) <= 0 then return end
        if not targetExists(target) then
            notify(src, 'NPCがサーバーに同期されていません', 'error')
            return
        end
        if NetworkGetEntityOwner(targetPed(target)) ~= src then
            notify(src, 'NPCの制御権をサーバーで確認できませんでした', 'error')
            return
        end
        if not isCarryJob(src) then return end
    end
    if not targetExists(target) or not sameBucket(src, target) then
        notify(src, '対象が見つからないか、別のインスタンスにいます', 'error')
        return
    end

    if vehicleSolo or exiting then
        local claim = vehiclePatients[src]
        local status = targetStatus(target)
        local dead = target > 0 and (status.dead or status.down) or target < 0 and isLivingDownDummy(target)
        if not claim or claim.target ~= target or claim.entity ~= targetPed(target) or not dead or status.cuffed then return end
        if vehicleSolo and GetVehiclePedIsIn(GetPlayerPed(src)) ~= claim.vehicle then return end
    end
    if escortedBy[src] or (vehiclePatients[src] and not vehicleSolo and not exiting) then return end
    for _, id in ipairs({src, target}) do
        for _, key in ipairs(Config.ExternalBusyKeys) do
            if stateValue(targetState(id)[key]) then
                notify(src, Config.Text.alreadyTaken, 'error')
                return
            end
        end
    end
    if not canEscort(src) or (not vehicleSolo and GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0) then
        notify(src, Config.Text.cannotNow, 'error')
        return
    end
    if escortedBy[target] or escorts[target] or (targetState(target).emsVehicleBy and targetState(target).emsVehicleBy ~= src) then
        notify(src, Config.Text.alreadyTaken, 'error')
        return
    end
    if Config.MaxPerEscorter > 0 and countOf(src) >= Config.MaxPerEscorter then
        notify(src, Config.Text.tooMany, 'error')
        return
    end
    if not canBeEscorted(target) then
        notify(src, Config.Text.noTarget, 'error')
        return
    end

    -- 運び方：手錠中 = 右横に立たせる / ダウン体 = 左側
    -- 医者がオプションでキャリーを選んでいればその運び方（ダウン中・手錠中どちらも）
    -- キャリーは同時に1人まで。すでにキャリー中なら通常の運び方にする
    local style = 'cuffed'
    if type(carryType) ~= 'string' or not carryTypeExists(carryType) then carryType = nil end
    local status = targetStatus(target)
    if not status.cuffed and (status.dead or status.down) then
        style = 'dead'
    end
    if carryType and isCarryJob(src) then
        if hasCarry(src) then
            notify(src, Config.Text.carryLimit, 'inform')
        else
            style = 'carry'
        end
    end
    -- Check the EFFECTIVE style, including carry-limit fallback.
    local inVehicle = GetVehiclePedIsIn(targetPed(target)) ~= 0
    local maxDist = (vehicleSolo or exiting) and Config.Distances.vehicleCarry or inVehicle and EscortRules.distance('vehicleNormal')
        or (style == 'carry' and EscortRules.distance('walkCarry') or EscortRules.distance('walkNormal'))
    if distanceBetween(src, target) > maxDist then
        notify(src, Config.Text.tooFar, 'error')
        return
    end
    local slot = freeSlot(src, style)
    escorts[src] = escorts[src] or {}
    if style ~= 'carry' then carryType = nil end
    escorts[src][target] = { slot = slot, style = style, carryType = carryType }
    escortedBy[target] = src

    if target > 0 then
        Player(target).state:set('emsEscortedBy', src, true)
    else
        nextNpcTicket = nextNpcTicket + 1
        local info = escorts[src][target]
        info.entity, info.ticket = targetPed(target), nextNpcTicket
        npcEntities[target] = info.entity
        Entity(info.entity).state:set('emsEscortedBy', src, true)
        Entity(info.entity).state:set('emsEscortTicket', info.ticket, true)
    end
    syncEscorterState(src)

    TriggerClientEvent('ptech_mediora_escort:client:addTarget', src, target, countOf(src), carryType)
    if target > 0 then
        TriggerClientEvent('ptech_mediora_escort:client:getEscorted', target, src, style, slot, carryType)
    else
        local info = escorts[src][target]
        TriggerClientEvent('ptech_mediora_escort:client:escortNPC', -1, target, src, style, slot, carryType, info.ticket)
    end
end

RegisterNetEvent('ptech_mediora_escort:server:start', function(target, carryType) startEscort(source, target, carryType) end)

-- Vehicle patients are reserved separately from an attached escort (one per EMS).
local vehicleSequence = 0

isLivingDownDummy = function(target)
    if target >= 0 or not targetExists(target) or GetEntityHealth(targetPed(target)) <= 100 then return false end
    local state = targetState(target)
    local info = testBodies[state.emsTestBodyOwner]
    return info and info.entity == targetPed(target) and info.netId == -target and state.emsDownDummy == true
end

local function vehicleCorpse(target)
    if target < 0 and not isLivingDownDummy(target) then return false end
    if not targetExists(target) or not canBeEscorted(target) then return false end
    local status = targetStatus(target)
    local state = targetState(target)
    if status.cuffed or EscortRules.playerStatus(state, nil, GetEntityHealth(targetPed(target))).cuffed then return false end
    return target > 0 and (status.dead or status.down) or target < 0 and isLivingDownDummy(target)
end

local function isBike(veh)
    return GetVehicleType(veh) == 'bike'
end

local function clearVehiclePatient(src)
    local info = vehiclePatients[src]
    if not info then return end
    vehiclePatients[src] = nil
    if targetExists(info.target) and targetPed(info.target) == info.entity then
        local state = targetState(info.target)
        if state.emsVehicleTicket == info.ticket then
            state:set('emsVehicleBy', nil, true)
            state:set('emsVehicleTicket', nil, true)
        end
    end
    TriggerClientEvent('ptech_mediora_escort:client:vehiclePatient', src, nil)
end

local function reserveVehiclePatient(src, target, veh, seat, pending)
    vehicleSequence = vehicleSequence + 1
    local info = { target = target, vehicle = veh, entity = targetPed(target), seat = seat,
        ticket = vehicleSequence, pending = pending, deadline = GetGameTimer() + 4000 }
    vehiclePatients[src] = info
    targetState(target):set('emsVehicleBy', src, true)
    targetState(target):set('emsVehicleTicket', info.ticket, true)
    TriggerClientEvent('ptech_mediora_escort:client:vehiclePatient', src, target, info.ticket)
    return info
end

local function vehicleAvailable(src, target, veh)
    if target == src or not vehicleCorpse(target) or not sameBucket(src, target)
        or GetVehiclePedIsIn(targetPed(target)) ~= 0 or escortedBy[target] or escorts[target]
        or targetState(target).emsVehicleBy then return false end
    for _, key in ipairs(Config.ExternalBusyKeys) do if stateValue(targetState(target)[key]) then return false end end
    return #(GetEntityCoords(targetPed(target)) - GetEntityCoords(veh)) <= Config.Distances.vehicleCarry
end

local function policeCorpse(target)
    if target < 0 then return false end
    local job = getJob(target)
    if not job then return false end
    for _, name in ipairs(Config.VehiclePickup.PDJobs) do if job.name == name then return true end end
    for _, kind in ipairs(Config.VehiclePickup.PDJobTypes) do if job.type == kind then return true end end
    return false
end

RegisterNetEvent('ptech_mediora_escort:server:vehiclePickup', function(seats)
    local src = source
    if rateLimited(src) or not isCarryJob(src) or not canEscort(src) or escortedBy[src]
        or countOf(src) > 0 or vehiclePatients[src] or type(seats) ~= 'table' then return end
    local veh = GetVehiclePedIsIn(GetPlayerPed(src))
    if veh == 0 or not DoesEntityExist(veh) or GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end
    local kind = GetVehicleType(veh)
    if kind ~= 'automobile' and kind ~= 'bike' then return end
    local seat
    local solo = isBike(veh)
    if not solo then
        for _, candidate in ipairs(seats) do
            if type(candidate) == 'number' and candidate % 1 == 0 and candidate >= 0 and candidate <= 15
                and GetPedInVehicleSeat(veh, candidate) == 0 then seat = candidate; break end
        end
        if not seat then notify(src, Config.Text.noSeat, 'error'); return end
    end
    local best, bestDist, bestPD
    local function consider(target)
        if not vehicleAvailable(src, target, veh) then return end
        local pd = policeCorpse(target)
        local dist = #(GetEntityCoords(targetPed(target)) - GetEntityCoords(veh))
        if not best or (pd and not bestPD) or (pd == bestPD and dist < bestDist) then
            best, bestDist, bestPD = target, dist, pd
        end
    end
    for _, id in ipairs(GetPlayers()) do consider(tonumber(id)) end
    if Config.Targets.npcs.enabled then
        for _, ped in ipairs(GetAllPeds()) do
            if isNPC(ped) then
                local netId = NetworkGetNetworkIdFromEntity(ped)
                if netId > 0 and netId <= 65535 then consider(-netId) end
            end
        end
    end
    if not best then notify(src, '範囲内に搬送できるダウン体がありません', 'error'); return end
    local info = reserveVehiclePatient(src, best, veh, seat, true)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if solo then
        TriggerClientEvent('ptech_mediora_escort:client:prepareSoloCarry', src, best, info.ticket)
    elseif best > 0 then
        TriggerClientEvent('ptech_mediora_escort:client:seatPickupPlayer', best, src, netId, seat, info.ticket)
    else
        TriggerClientEvent('ptech_mediora_escort:client:seatPickupNPC', src, best, src, netId, seat, info.ticket)
    end
end)

RegisterNetEvent('ptech_mediora_escort:server:soloCarryReady', function(target, ticket)
    local src = source
    local info = vehiclePatients[src]
    if not info or info.target ~= target or info.ticket ~= ticket or not info.pending
        or not isCarryJob(src) or not canEscort(src) or not isBike(info.vehicle)
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= info.vehicle or not vehicleCorpse(target)
        or not sameBucket(src, target) or distanceBetween(src, target) > Config.Distances.vehicleCarry then return end
    if not carryTypeExists(Config.VehiclePickup.CarryType) then notify(src, '車両用の担ぎスタイル設定が無効です', 'error'); return end
    startEscort(src, target, Config.VehiclePickup.CarryType, true)
    if escortedBy[target] == src then clearVehiclePatient(src) end
end)

RegisterNetEvent('ptech_mediora_escort:server:exitWithPatient', function(ticket)
    local src = source
    local info = vehiclePatients[src]
    if not info or info.ticket ~= ticket or info.pending or GetVehiclePedIsIn(GetPlayerPed(src)) ~= 0
        or not isCarryJob(src) or not canEscort(src) or not targetExists(info.target)
        or targetPed(info.target) ~= info.entity or not sameBucket(src, info.target)
        or not vehicleCorpse(info.target) or GetVehiclePedIsIn(info.entity) ~= info.vehicle
        or GetPedInVehicleSeat(info.vehicle, info.seat) ~= info.entity
        or distanceBetween(src, info.target) > Config.Distances.vehicleCarry or countOf(src) > 0 then return end
    if not carryTypeExists(Config.VehiclePickup.CarryType) then notify(src, '車両用の担ぎスタイル設定が無効です', 'error'); return end
    startEscort(src, info.target, Config.VehiclePickup.CarryType, false, true)
    if escortedBy[info.target] == src then clearVehiclePatient(src) end
end)

CreateThread(function()
    while true do
        Wait(250)
        for src, info in pairs(vehiclePatients) do
            if GetPlayerPing(src) <= 0 or not isCarryJob(src) or not canEscort(src) or not targetExists(info.target)
                or targetPed(info.target) ~= info.entity or not sameBucket(src, info.target)
                or not DoesEntityExist(info.vehicle) or not vehicleCorpse(info.target) then
                clearVehiclePatient(src)
            elseif info.pending then
                if info.seat and GetVehiclePedIsIn(GetPlayerPed(src)) == info.vehicle
                    and GetVehiclePedIsIn(info.entity) == info.vehicle
                    and GetPedInVehicleSeat(info.vehicle, info.seat) == info.entity then
                    info.pending = false
                    notify(src, '患者を座席に乗せました', 'success')
                elseif GetGameTimer() >= info.deadline or GetVehiclePedIsIn(GetPlayerPed(src)) ~= info.vehicle then
                    clearVehiclePatient(src)
                    notify(src, '車両ピックに失敗しました', 'error')
                end
            elseif GetVehiclePedIsIn(info.entity) ~= info.vehicle
                or GetPedInVehicleSeat(info.vehicle, info.seat) ~= info.entity
                or distanceBetween(src, info.target) > Config.BreakDistance then
                clearVehiclePatient(src)
            end
        end
    end
end)

AddEventHandler('playerDropped', function() clearVehiclePatient(source) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(vehiclePatients) do clearVehiclePatient(src) end
end)

-- 全員離す
RegisterNetEvent('ptech_mediora_escort:server:stopAll', function()
    if pendingNpcStarts[source] then pendingNpcStarts[source].cancelled = true end
    stopAll(source)
end)

-- 1人だけ離す
RegisterNetEvent('ptech_mediora_escort:server:stopOne', function(target)
    target = tonumber(target)
    local pending = pendingNpcStarts[source]
    if pending and pending.target == target then pending.cancelled = true end
    stopOne(source, target)
end)

-- 運ばれている側から「運ぶ人が見つからない」と報告があった場合
RegisterNetEvent('ptech_mediora_escort:server:lost', function()
    local src = source
    local escorter = escortedBy[src]
    if escorter then stopOne(escorter, src) end
end)

-- 運んでいる人を車に乗せる（空いている座席の数だけ）
RegisterNetEvent('ptech_mediora_escort:server:putInVehicle', function(netId, seats, mode)
    local src = source
    if rateLimited(src) or not isCarryJob(src) or not canEscort(src) or GetPlayerPed(src) == 0
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= 0 then return end
    if mode ~= 'normal' and mode ~= 'medical' then return end
    if not validId(netId) then return end
    local list = escorts[src]
    if not list or type(seats) ~= 'table' then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if GetVehicleType(veh) ~= 'automobile' then return end
    if GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end
    local maxDist = EscortRules.distance(mode == 'medical' and 'vehicleMedical' or 'vehicleNormal')
    if mode == 'medical' and pdNearby(src, veh) then
        notify(src, Config.Text.pdPriority, 'error')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > maxDist then
        notify(src, Config.Text.tooFar, 'error')
        return
    end

    -- 先に運び始めた人（番号の小さい人）から乗せる
    local order = {}
    local rank = { cuffed = 1, carry = 2, dead = 3 }
    for target, info in pairs(list) do order[#order + 1] = { id = target, slot = info.slot, style = info.style } end
    table.sort(order, function(a, b)
        if a.style ~= b.style then return rank[a.style] < rank[b.style] end
        return a.slot < b.slot
    end)

    local placed = 0
    local usedSeats = {}
    for i, entry in ipairs(order) do
        local seat = tonumber(seats[i])
        if not seat or seat ~= seat or seat % 1 ~= 0 or seat < 0 or seat > 15 then break end
        if usedSeats[seat] or GetPedInVehicleSeat(veh, seat) ~= 0 then break end
        usedSeats[seat] = true
        if not sameBucket(src, entry.id) or not canBeEscorted(entry.id)
            or (entry.id < 0 and NetworkGetEntityOwner(targetPed(entry.id)) ~= src)
            or distanceBetween(src, entry.id) > Config.BreakDistance
            or #(GetEntityCoords(targetPed(entry.id)) - GetEntityCoords(veh)) > maxDist then break end
        local info = list[entry.id]
        stopOne(src, entry.id, true)
        if entry.id > 0 then
            TriggerClientEvent('ptech_mediora_escort:client:putInVehicle', entry.id, netId, seat)
        else
            TriggerClientEvent('ptech_mediora_escort:client:putNPCInVehicle', -1, entry.id, info.ticket, netId, seat)
        end
        placed = placed + 1
    end

    if placed > 0 then
        notify(src, Config.Text.putInVehicle:format(placed), 'success')
    else
        notify(src, Config.Text.noSeat, 'error')
    end
end)

-- Automatic transfer is allowed only into the vehicle the EMS is actually occupying.
RegisterNetEvent('ptech_mediora_escort:server:autoBoard', function(netId, seats, mode)
    local src = source
    if rateLimited(src) or not isCarryJob(src) or not canEscort(src) or not validId(netId)
        or type(seats) ~= 'table' or (mode ~= 'normal' and mode ~= 'medical') then return end
    local list = escorts[src]
    if not list then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 or GetVehicleType(veh) ~= 'automobile'
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= veh
        or GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end
    if mode == 'medical' and pdNearby(src, veh) then
        notify(src, Config.Text.pdPriority, 'error')
        return
    end
    local maxDist = EscortRules.distance(mode == 'medical' and 'vehicleMedical' or 'vehicleNormal')
    local used = {}
    for target, info in pairs(list) do
        if not info.autoVehicle and targetExists(target) and sameBucket(src, target) and canBeEscorted(target)
            and distanceBetween(src, target) <= Config.BreakDistance
            and #(GetEntityCoords(targetPed(target)) - GetEntityCoords(veh)) <= maxDist
            and (target > 0 or NetworkGetEntityOwner(targetPed(target)) == src) then
            local seat
            for _, candidate in ipairs(seats) do
                if type(candidate) == 'number' and candidate % 1 == 0 and candidate >= 0 and candidate <= 15
                    and not used[candidate] and GetPedInVehicleSeat(veh, candidate) == 0 then
                    seat = candidate
                    break
                end
            end
            if not seat then notify(src, Config.Text.noSeat, 'error'); return end
            used[seat] = true
            info.autoVehicle, info.autoSeat, info.autoDeadline = veh, seat, GetGameTimer() + 3000
            if target > 0 then
                TriggerClientEvent('ptech_mediora_escort:client:autoBoardPlayer', target, src, netId, seat)
            else
                TriggerClientEvent('ptech_mediora_escort:client:autoBoardNPC', src, target, info.ticket, src, netId, seat)
            end
        end
    end
end)

-- 状態の見回り（手錠が外れた・蘇生された・離れすぎた等で自動解除）
CreateThread(function()
    while true do
        Wait(1000)
        local toStop = {}
        for escorter, list in pairs(escorts) do
            if GetPlayerPing(escorter) <= 0 or not isCarryJob(escorter) or not canEscort(escorter)
                or GetPlayerPed(escorter) == 0 then
                toStop[#toStop + 1] = { escorter }
            else
                local ownerVeh = GetVehiclePedIsIn(GetPlayerPed(escorter))
                local ownerType = ownerVeh ~= 0 and GetVehicleType(ownerVeh) or nil
                for target, info in pairs(list) do
                    if info.autoVehicle and targetExists(target) and ownerVeh == info.autoVehicle
                        and GetVehiclePedIsIn(targetPed(target)) == info.autoVehicle
                        and GetPedInVehicleSeat(info.autoVehicle, info.autoSeat) == targetPed(target) then
                        if vehicleCorpse(target) and not vehiclePatients[escorter] then
                            reserveVehiclePatient(escorter, target, info.autoVehicle, info.autoSeat, false)
                        end
                        toStop[#toStop + 1] = { escorter, target, true }
                    elseif ownerVeh ~= 0 and ownerType ~= 'automobile' and ownerType ~= 'bike' then
                        toStop[#toStop + 1] = { escorter, target }
                    elseif not targetExists(target) or not sameBucket(escorter, target) or not canBeEscorted(target)
                        or (target < 0 and NetworkGetEntityOwner(targetPed(target)) ~= escorter)
                        or distanceBetween(escorter, target) > Config.BreakDistance then
                        toStop[#toStop + 1] = { escorter, target }
                    elseif info.autoVehicle and (ownerVeh ~= info.autoVehicle or GetGameTimer() >= info.autoDeadline) then
                        info.autoVehicle, info.autoSeat, info.autoDeadline = nil, nil, nil
                        notify(escorter, '患者を座席に移せませんでした。搬送を維持します', 'error')
                    end
                end
            end
        end
        for _, entry in ipairs(toStop) do
            if entry[2] then
                stopOne(entry[1], entry[2])
                if entry[3] then notify(entry[1], Config.Text.putInVehicle:format(1), 'success') end
            else stopAll(entry[1]) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastRequest[src] = nil
    if pendingNpcStarts[src] then pendingNpcStarts[src].cancelled = true end
    if escorts[src] then stopAll(src) end
    local escorter = escortedBy[src]
    if escorter then stopOne(escorter, src) end
end)

-- 他スクリプト用
exports('getEscorting', function(id)
    local result = {}
    for target in pairs(escorts[id] or {}) do if target > 0 then result[#result + 1] = target end end
    return result
end)
exports('isEscorted', function(id) return escortedBy[id] end)
exports('stopEscort', function(id)
    if escorts[id] then stopAll(id) end
    if escortedBy[id] then stopOne(escortedBy[id], id) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ids = {}
    for id in pairs(escorts) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do stopAll(id) end
end)

exports('getEscortingNPCs', function(id)
    local result = {}
    for target in pairs(escorts[id] or {}) do if target < 0 then result[#result + 1] = -target end end
    return result
end)


-- One temporary living down dummy per EMS. Its identity is checked before cleanup.
local function removeTestBody(src)
    local info = testBodies[src]
    testBodies[src] = nil
    if info and DoesEntityExist(info.entity) and NetworkGetNetworkIdFromEntity(info.entity) == info.netId
        and GetEntityModel(info.entity) == joaat('a_m_m_business_01')
        and Entity(info.entity).state.emsTestBodyOwner == src then DeleteEntity(info.entity) end
end

RegisterCommand('emsdummy', function(src, args)
    if src <= 0 or not isCarryJob(src) then return end
    if args[1] == 'delete' then removeTestBody(src); notify(src, 'テスト用NPCを削除しました'); return end
    if not canEscort(src) or GetVehiclePedIsIn(GetPlayerPed(src)) ~= 0 then
        notify(src, '徒歩の状態で作成してください', 'error'); return
    end
    if rateLimited(src) then return end
    removeTestBody(src)
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local angle = math.rad(heading)
    local body = CreatePed(4, joaat('a_m_m_business_01'), pos.x - math.sin(angle)*2.0,
        pos.y + math.cos(angle)*2.0, pos.z, heading, true, true)
    if body == 0 or not DoesEntityExist(body) then notify(src, 'テスト用NPCの作成に失敗しました', 'error'); return end
    SetEntityRoutingBucket(body, GetPlayerRoutingBucket(src))
    local netId = NetworkGetNetworkIdFromEntity(body)
    if netId <= 0 then DeleteEntity(body); notify(src, 'NPCの同期に失敗しました', 'error'); return end
    local info = { entity = body, netId = netId }
    testBodies[src] = info
    Entity(body).state:set('emsTestBodyOwner', src, true)
    Entity(body).state:set('emsDownDummy', true, true)
    TriggerClientEvent('ptech_mediora_escort:client:createTestBody', src, netId)
    CreateThread(function()
        Wait(5000)
        if testBodies[src] == info and DoesEntityExist(body) and Entity(body).state.emsDummyReady ~= true then
            removeTestBody(src)
            notify(src, 'テスト用NPCの準備に失敗しました。制御権を確認してください', 'error')
        end
    end)
end, false)

AddEventHandler('playerDropped', function() removeTestBody(source) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(testBodies) do removeTestBody(src) end
end)

RegisterNetEvent('ptech_mediora_escort:server:dummyReady', function(netId)
    local src = source
    local info = testBodies[src]
    if not isCarryJob(src) or not info or info.netId ~= netId or not DoesEntityExist(info.entity)
        or NetworkGetEntityOwner(info.entity) ~= src or GetEntityHealth(info.entity) <= 100 then return end
    Entity(info.entity).state:set('emsDummyReady', true, true)
end)
