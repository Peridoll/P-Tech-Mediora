-- ems-escort / server

local escorts = {}     -- [運ぶ人] = { [運ばれる人] = { slot = n, style = 'carry', carryType = id } }
local escortedBy = {}  -- [運ばれる人] = 運ぶ人
local lastRequest = {}
local pendingNpcStarts = {}
local vehiclePatients = {}
local testBodies = {}
local registeredNPCs = {} -- [networkId] = { entity = ped, owner = resourceName }
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
    if not targetExists(id) then return false end
    if id < 0 then
        local ped = targetPed(id)
        local record = registeredNPCs[-id]
        if not record or record.entity ~= ped then return false end
        local state = Entity(ped).state
        if state[Config.NPCOwnerKey] ~= record.owner
            or state[Config.NPCStatusKey] ~= 'down' then return false end
    end
    return EscortRules.allowed(targetStatus(id), id < 0)
end

-- 登録は信頼できるサーバーリソースからのexport呼び出しに限る。
-- クライアント由来のState Bagタグのみで搬送許可しない。
exports('registerTransportNPC', function(ped)
    local owner = GetInvokingResource()
    local authorized = false
    for _, name in ipairs(Config.NPCResources or {}) do
        if name == owner then authorized = true; break end
    end
    if not authorized or not isNPC(ped) then return false end
    local id = NetworkGetNetworkIdFromEntity(ped)
    if id < 1 or id > 65535 then return false end
    if Entity(ped).state[Config.NPCStatusKey] ~= 'down' then return false end
    registeredNPCs[id] = { entity = ped, owner = owner }
    Entity(ped).state:set(Config.NPCOwnerKey, owner, true)
    return true
end)

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

local function carryTypeExists(id)
    if id == 'fireman' then return true end -- 内蔵の標準スタイル
    for _, group in pairs(Config.CarryModes or {}) do
        for _, t in ipairs(group) do
            if t.id == id then return true end
        end
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
            TriggerClientEvent('ptech_mediora_escort:client:released', target, info.ticket)
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
    if pendingNpcStarts[src] then return end -- 通常搬送の再操作にクールダウンを設けない
    target = tonumber(target)
    if not target or target ~= target or target % 1 ~= 0 or target == 0 or target == src then return end
    if target < 0 and -target > 65535 then return end
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
        if not canEscort(src) then return end
    end
    if not targetExists(target) or not sameBucket(src, target) then
        notify(src, '対象が見つからないか、別のインスタンスにいます', 'error')
        return
    end

    if vehicleSolo or exiting then
        local claim = vehiclePatients[src]
        local status = targetStatus(target)
        local dead = target > 0 and (status.dead or status.down) or target < 0 and isLivingDownDummy(target)
        if not claim or claim.target ~= target or claim.entity ~= targetPed(target) or not dead then return end
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
    if countOf(src) >= 1 then
        notify(src, Config.Text.tooMany, 'error')
        return
    end
    if not canBeEscorted(target) then
        notify(src, Config.Text.noTarget, 'error')
        return
    end

    -- 現行仕様はダウン・死亡患者を1人だけ担ぐ。
    if type(carryType) ~= 'string' or not carryTypeExists(carryType) then carryType = 'fireman' end
    local style = 'carry'
    -- Check the EFFECTIVE style, including carry-limit fallback.
    local inVehicle = GetVehiclePedIsIn(targetPed(target)) ~= 0
    local maxDist = (vehicleSolo or exiting) and Config.Distances.vehicleCarry or inVehicle and EscortRules.distance('vehicleNormal')
        or (style == 'carry' and EscortRules.distance('walkCarry') or EscortRules.distance('walkNormal'))
    local measuredDistance = distanceBetween(src, target)
    if inVehicle then
        local veh = GetVehiclePedIsIn(targetPed(target))
        measuredDistance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh))
    end
    if measuredDistance > maxDist then
        notify(src, Config.Text.tooFar, 'error')
        return
    end
    local slot = 1
    escorts[src] = escorts[src] or {}
    if style ~= 'carry' then carryType = nil end
    nextNpcTicket = nextNpcTicket + 1
    local sessionTicket = nextNpcTicket
    escorts[src][target] = { slot = slot, style = style, carryType = carryType, ticket = sessionTicket }
    escortedBy[target] = src

    if target > 0 then
        Player(target).state:set('emsEscortedBy', src, true)
    else
        local info = escorts[src][target]
        info.entity, info.ticket = targetPed(target), nextNpcTicket
        npcEntities[target] = info.entity
        Entity(info.entity).state:set('emsEscortedBy', src, true)
        Entity(info.entity).state:set('emsEscortTicket', info.ticket, true)
    end
    syncEscorterState(src)

    TriggerClientEvent('ptech_mediora_escort:client:addTarget', src, target, countOf(src), carryType)
    if target > 0 then
        TriggerClientEvent('ptech_mediora_escort:client:getEscorted', target, src, style, slot, carryType, sessionTicket)
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
    -- NPCはダウンタグ＋サーバー登録を満たしたものだけ収容可能。
    if not targetExists(target) or not canBeEscorted(target) then return false end
    local status = targetStatus(target)
    return target > 0 and EscortRules.allowed(status, false) or target < 0 and status.down
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
    -- JOB type matching is deliberately excluded; only configured PD job names qualify.
    return false
end

-- 運転席の勤務中EMSだけが使うPD一括ピックアップ。
-- 対象・座席をサーバーで確保し、プレイヤー本人のクライアントが乗車する。
local pdBatchClaims, pdBatches, pdBatchTicket = {}, {}, 0
local function clearPDBatchClaim(target)
    local info = pdBatchClaims[target]
    if not info then return end
    pdBatchClaims[target] = nil
    if GetPlayerPing(target) > 0 then
        local st = Player(target).state
        if st.emsVehicleTicket == info.ticket and st.emsVehicleBy == info.src then
            st:set('emsVehicleBy', nil, true)
            st:set('emsVehicleTicket', nil, true)
        end
    end
end

RegisterNetEvent('ptech_mediora_escort:server:vehiclePickup', function(seats)
    local src = source
    if not Config.VehiclePickup.Enabled or rateLimited(src) or not isCarryJob(src)
        or not canEscort(src) or escortedBy[src] or countOf(src) > 0
        or pdBatches[src] or type(seats) ~= 'table' then return end
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped)
    if veh == 0 or not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped
        or GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end

    local vehiclePosition = GetEntityCoords(veh)
    local candidates = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= src and policeCorpse(target) and canBeEscorted(target)
            and not escortedBy[target] and not escorts[target] and not pdBatchClaims[target]
            and not targetState(target).emsVehicleBy and sameBucket(src, target)
            and GetVehiclePedIsIn(targetPed(target)) == 0 then
            local status = targetStatus(target)
            local dist = #(GetEntityCoords(targetPed(target)) - vehiclePosition)
            local busy = false
            for _, key in ipairs(Config.ExternalBusyKeys) do
                if stateValue(targetState(target)[key]) then busy = true; break end
            end
            if not busy and dist <= (Config.VehiclePickup.Range or 8.0) then
                candidates[#candidates + 1] = { id = target, dist = dist }
            end
        end
    end
    table.sort(candidates, function(x, y) return x.dist < y.dist end)
    if #candidates == 0 then
        notify(src, '付近に救助対象のPD隊員はいないようだ', 'inform')
        return
    end
    local freeSeats, seenSeats = {}, {}
    for _, seat in ipairs(seats) do
        if type(seat) == 'number' and seat % 1 == 0 and seat >= 0 and seat <= 15
            and not seenSeats[seat] and GetPedInVehicleSeat(veh, seat) == 0 then
            seenSeats[seat] = true
            freeSeats[#freeSeats + 1] = seat
        end
    end
    if #freeSeats == 0 then notify(src, Config.Text.noSeat, 'error'); return end

    local batch = { success = 0, eligible = #candidates, picked = 0 }
    pdBatches[src] = batch
    local vehNetId = NetworkGetNetworkIdFromEntity(veh)
    for i = 1, math.min(#candidates, #freeSeats) do
        local target, seat = candidates[i].id, freeSeats[i]
        pdBatchTicket = pdBatchTicket + 1
        local ticket = pdBatchTicket
        pdBatchClaims[target] = { src = src, vehicle = veh, seat = seat, ticket = ticket, batch = batch }
        Player(target).state:set('emsVehicleBy', src, true)
        Player(target).state:set('emsVehicleTicket', ticket, true)
        batch.picked = batch.picked + 1
        TriggerClientEvent('ptech_mediora_escort:client:pdBatchSeat', target, src, vehNetId, seat, ticket)
    end
    CreateThread(function()
        Wait(2500)
        for target, claim in pairs(pdBatchClaims) do
            if claim.batch == batch then clearPDBatchClaim(target) end
        end
        if pdBatches[src] ~= batch then return end
        pdBatches[src] = nil
        if GetPlayerPing(src) <= 0 then return end
        if batch.success > 0 then
            notify(src, ('PD隊員を%d名収容しました'):format(batch.success), 'success')
        end
        if batch.success < batch.eligible then
            notify(src, Config.Text.noSeat, 'error')
        end
    end)
end)

RegisterNetEvent('ptech_mediora_escort:server:pdBatchSeatDone', function(ticket)
    local target = source
    local claim = pdBatchClaims[target]
    if not claim or claim.ticket ~= ticket then return end
    local ped = targetPed(target)
    local success = DoesEntityExist(claim.vehicle)
        and GetVehiclePedIsIn(ped) == claim.vehicle
        and GetPedInVehicleSeat(claim.vehicle, claim.seat) == ped
    if success then claim.batch.success = claim.batch.success + 1 end
    clearPDBatchClaim(target)
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearPDBatchClaim(src)
    pdBatches[src] = nil
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for target in pairs(pdBatchClaims) do clearPDBatchClaim(target) end
end)

RegisterNetEvent('ptech_mediora_escort:server:soloCarryReady', function(target, ticket)
    local src = source
    local info = vehiclePatients[src]
    if not info or info.target ~= target or info.ticket ~= ticket or not info.pending
        or not isCarryJob(src) or not canEscort(src) or not isBike(info.vehicle)
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= info.vehicle or not vehicleCorpse(target)
        or not sameBucket(src, target) or distanceBetween(src, target) > Config.Distances.vehicleCarry then return end
    if not carryTypeExists('fireman') then notify(src, '車両用の担ぎスタイル設定が無効です', 'error'); return end
    startEscort(src, target, 'fireman', true)
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
    if not carryTypeExists('fireman') then notify(src, '車両用の担ぎスタイル設定が無効です', 'error'); return end
    startEscort(src, info.target, 'fireman', false, true)
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
RegisterNetEvent('ptech_mediora_escort:server:lost', function(ticket)
    local src = source
    local escorter = escortedBy[src]
    local info = escorter and escorts[escorter] and escorts[escorter][src]
    if info and info.ticket == ticket then stopOne(escorter, src) end
end)

-- 運んでいる人を車に乗せる（空いている座席の数だけ）
RegisterNetEvent('ptech_mediora_escort:server:putInVehicle', function(netId, seats, mode)
    local src = source
    if rateLimited(src) or not canEscort(src) or GetPlayerPed(src) == 0
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= 0 then return end
    if mode ~= 'normal' and mode ~= 'medical' then return end
    if not validId(netId) then return end
    local list = escorts[src]
    if not list or type(seats) ~= 'table' then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli') then return end
    if GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end
    local maxDist = EscortRules.distance(mode == 'medical' and 'vehicleMedical' or 'vehicleNormal')
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > maxDist then
        notify(src, Config.Text.tooFar, 'error')
        return
    end

    -- 先に運び始めた人（番号の小さい人）から乗せる
    local order = {}
    local rank = { carry = 1 }
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
    if rateLimited(src) or not canEscort(src) or not validId(netId)
        or type(seats) ~= 'table' or (mode ~= 'normal' and mode ~= 'medical') then return end
    local list = escorts[src]
    if not list then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 or (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli')
        or GetVehiclePedIsIn(GetPlayerPed(src)) ~= veh
        or GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) then return end
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
        Wait((Config.Sync and Config.Sync.Interval) or 500)
        local toStop = {}
        for escorter, list in pairs(escorts) do
            if GetPlayerPing(escorter) <= 0 or not canEscort(escorter)
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
                    elseif ownerVeh ~= 0 and ownerType ~= 'automobile' and ownerType ~= 'bike' and ownerType ~= 'heli' then
                        toStop[#toStop + 1] = { escorter, target }
                    elseif not targetExists(target) or not sameBucket(escorter, target) then
                        -- 一時的な同期欠落やバケット不一致は待機。距離ずれだけでは解除しない。
                        info.syncMissingSince = info.syncMissingSince or GetGameTimer()
                        if GetGameTimer() - info.syncMissingSince >= ((Config.Sync and Config.Sync.Timeout) or 3000) then
                            toStop[#toStop + 1] = { escorter, target }
                        end
                    elseif not canBeEscorted(target) then
                        -- 蘇生・状態解除は復旧対象ではなく即時解除。
                        toStop[#toStop + 1] = { escorter, target }
                    elseif info.syncMissingSince then
                        info.syncMissingSince = nil
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
    if info then registeredNPCs[info.netId] = nil end
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
    registeredNPCs[netId] = { entity = body, owner = GetCurrentResourceName() }
    Entity(body).state:set(Config.NPCOwnerKey, GetCurrentResourceName(), true)
    Entity(body).state:set(Config.NPCStatusKey, 'down', true)
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


-- ox_inventory: 搬送者は自身のインベントリ閲覧・整理だけ可能。
-- アイテム使用・他インベントリへの移動・他者との譲渡をサーバーで拒否。
local inventoryHooksInstalled = false
local function registerInventoryHooks()
    if inventoryHooksInstalled or GetResourceState('ox_inventory') ~= 'started' then return end
    local ok, err = pcall(function()
        exports.ox_inventory:registerHook('usingItem', function(payload)
            if escorts[payload.source] and countOf(payload.source) > 0 then return false end
        end)
        exports.ox_inventory:registerHook('swapItems', function(payload)
            local receiver = type(payload.toInventory) == 'number' and payload.toInventory
                or type(payload.toInventory) == 'table' and tonumber(payload.toInventory.id)
            if payload.action == 'give' and receiver and countOf(receiver) > 0 then return false end
            if countOf(payload.source) <= 0 then return end
            if payload.action == 'give' or payload.fromType ~= 'player'
                or payload.toType ~= 'player' or payload.fromInventory ~= payload.toInventory then
                return false
            end
        end)
        exports.ox_inventory:registerHook('openInventory', function(payload)
            if countOf(payload.source) > 0 then return false end
        end)
    end)
    if ok then
        inventoryHooksInstalled = true
    else
        print(('[Mediora Escort] ox_inventory hooks could not be registered: %s'):format(tostring(err)))
    end
end
AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' or resource == GetCurrentResourceName() then
        registerInventoryHooks()
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == 'ox_inventory' then inventoryHooksInstalled = false end
end)
