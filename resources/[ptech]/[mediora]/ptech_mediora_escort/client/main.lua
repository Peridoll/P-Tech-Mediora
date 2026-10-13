-- ems-escort / client

local escorting = {}        -- [運んでいる人のサーバーID] = true
local escortingCount = 0
local escortingOrder = {}   -- 運び始めた順（Zで離すときは最後の人から1人ずつ）
local escortedBy = nil      -- 自分を運んでいる人のサーバーID
local escortedStyle = nil    -- 'cuffed' / 'dead' / 'carry'
local carryingTarget = nil   -- 自分がキャリーしている人のサーバーID
local carryingType = nil     -- 自分のキャリーの種類（Config.CarryTypes の id）
local escortedCarryType = nil -- 自分がキャリーされているときの種類

local function getCarryType(id)
    for _, t in ipairs(Config.CarryTypes) do
        if t.id == id then return t end
    end
    return nil
end
local selectedCarry = 'fireman'
local selectedVehicleMode = "normal" -- Used for manual placement only.
local escortedSlot = 1
local watchLoopRunning = false

local WALK_DICT = 'move_m@generic_variations@walk'
local WALK_ANIM = 'walk_a'

-- ───────────── 判定 ─────────────

local function stateValue(v)
    if v == nil or v == false or v == 0 then return nil end
    return v
end

local function isServerIdEscortable(sid)
    local idx = GetPlayerFromServerId(sid)
    local ped = idx ~= -1 and GetPlayerPed(idx) or 0
    if ped == 0 then return false end
    return EscortRules.allowed(EscortRules.playerStatus(Player(sid).state, nil, GetEntityHealth(ped)), false)
end

local function amIRestrained()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    return EscortRules.restrained(EscortRules.playerStatus(LocalPlayer.state,
        ok and data and data.metadata or nil, GetEntityHealth(cache.ped))) or IsEntityDead(cache.ped)
end

local function serverIdFromPed(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) then return nil end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return nil end
    return GetPlayerServerId(idx)
end

local function isFree(sid)
    local st = Player(sid).state
    if st.emsVehicleBy then return false end
    for _, key in ipairs(Config.ExternalBusyKeys) do
        if st[key] ~= nil and st[key] ~= false and st[key] ~= 0 then return false end
    end
    return st.emsEscortedBy == nil and st.emsEscorting == nil
end

local function canAddMore()
    return Config.MaxPerEscorter <= 0 or escortingCount < Config.MaxPerEscorter
end

-- Selection range follows the effective carry mode.
local function isEMS()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local job = ok and data and data.job
    if not job or (Config.RequireDuty and job.onduty ~= true) then return false end
    for _, name in ipairs(Config.EMSJobs) do
        if name == job.name then return true end
    end
    return false
end

local function getStartDistance()
    return selectedCarry and not carryingTarget and EscortRules.distance('walkCarry') or EscortRules.distance('walkNormal')
end

local function vehicleDistance()
    return EscortRules.distance(selectedVehicleMode == 'medical' and 'vehicleMedical' or 'vehicleNormal')
end

local function npcId(ped)
    if ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) or not NetworkGetEntityIsNetworked(ped) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    return netId > 0 and -netId or nil
end

local function npcEscortable(ped)
    if not Config.Targets.npcs.enabled or ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped)
        or IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end
    local id = npcId(ped)
    if id and escorting[id] then return false end
    local state = Entity(ped).state
    if state.emsEscortedBy or state.emsVehicleBy then return false end
    for _, key in ipairs(Config.ExternalBusyKeys) do if stateValue(state[key]) then return false end end
    return EscortRules.allowed(EscortRules.npcStatus(state, GetEntityHealth(ped), IsEntityDead(ped) or IsPedDeadOrDying(ped, true)), true)
end

local function getClosestEscortable()
    local myCoords = GetEntityCoords(cache.ped)
    local range = getStartDistance()
    local bestSid, bestDist
    for _, idx in ipairs(GetActivePlayers()) do
        if idx ~= cache.playerId then
            local ped = GetPlayerPed(idx)
            if ped ~= 0 and not IsPedInAnyVehicle(ped, false) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= range and (not bestDist or dist < bestDist) then
                    local sid = GetPlayerServerId(idx)
                    if not escorting[sid] and isFree(sid) and isServerIdEscortable(sid) then
                        bestSid, bestDist = sid, dist
                    end
                end
            end
        end
    end
    if Config.Targets.npcs.enabled then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if not IsPedInAnyVehicle(ped, false) and npcEscortable(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= range and (not bestDist or dist < bestDist) then
                    bestSid, bestDist = npcId(ped) or { npcPed = ped }, dist
                end
            end
        end
    end
    return bestSid
end

-- 空いている座席（後部座席 → 助手席の順）
local function getFreeSeats(veh)
    local seats = {}
    local max = GetVehicleMaxNumberOfPassengers(veh)
    for seat = 1, max - 1 do
        if IsVehicleSeatFree(veh, seat) then seats[#seats + 1] = seat end
    end
    if max > 0 and IsVehicleSeatFree(veh, 0) then seats[#seats + 1] = 0 end
    return seats
end

local function getRestrainedPassenger(veh)
    local max = GetVehicleMaxNumberOfPassengers(veh)
    for seat = -1, max - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and ped ~= cache.ped then
            local sid = serverIdFromPed(ped)
            if sid and isServerIdEscortable(sid) and isFree(sid) then return sid end
            if not sid and npcEscortable(ped) then return npcId(ped) or { npcPed = ped } end
        end
    end
    return nil
end

-- ───────────── 運ぶ側 ─────────────

-- 自分が「エスコートオプション」を使えるジョブか（医者のみ）
local function isCarryJob()
    return isEMS()
end

-- 医者がオプションで選んだ運び方（nil = 通常のエスコート）。次にエスコートする人から使われる
local function requestStart(sid)
    if not isEMS() then return end
    if escortedBy then return end
    if amIRestrained() or IsPedInAnyVehicle(cache.ped, false) then
        lib.notify({ description = Config.Text.cannotNow, type = 'error' })
        return
    end
    if not canAddMore() then
        lib.notify({ description = Config.Text.tooMany, type = 'error' })
        return
    end
    local carryType = (selectedCarry and isCarryJob()) and selectedCarry or nil
    if type(sid) == 'table' then
        local ped = sid.npcPed
        if not ped or not npcEscortable(ped) then return end
        if #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) > getStartDistance() then
            lib.notify({ description = Config.Text.tooFar, type = 'error' })
            return
        end
        -- Do this only when actually selected, never while rendering target options.
        NetworkRegisterEntityAsNetworked(ped)
        local deadline = GetGameTimer() + 1500
        while DoesEntityExist(ped) and not npcId(ped) and GetGameTimer() < deadline do Wait(0) end
        sid = DoesEntityExist(ped) and npcId(ped) or nil
        if not sid then
            lib.notify({ description = 'NPCをサーバーへ同期できませんでした', type = 'error' })
            return
        end
    end
    if sid < 0 then
        local ped = NetworkGetEntityFromNetworkId(-sid)
        if ped == 0 or IsPedAPlayer(ped) then return end
        NetworkRequestControlOfEntity(ped)
        local timeout = GetGameTimer() + 1000
        while DoesEntityExist(ped) and not NetworkHasControlOfEntity(ped) and GetGameTimer() < timeout do
            NetworkRequestControlOfEntity(ped)
            Wait(0)
        end
        if not DoesEntityExist(ped) or npcId(ped) ~= sid or not NetworkHasControlOfEntity(ped) then
            lib.notify({ description = 'NPCの制御権を取得できませんでした', type = 'error' })
            return
        end
    end
    if sid < 0 and not npcEscortable(NetworkGetEntityFromNetworkId(-sid)) then
        lib.notify({ description = '死亡したNPCは搬送できません', type = 'error' }); return
    end
    if not isEMS() or escortedBy or amIRestrained() or IsPedInAnyVehicle(cache.ped, false) then return end
    TriggerServerEvent('ptech_mediora_escort:server:start', sid, carryType)
end

-- 医者用のオプション画面（運び方を選ぶだけ。近くの人をエスコートはしない）
local vehiclePatientTarget, vehiclePatientTicket

RegisterNetEvent('ptech_mediora_escort:client:vehiclePatient', function(target, ticket)
    if source ~= 65535 then return end
    vehiclePatientTarget, vehiclePatientTicket = target, ticket
end)

local function requestVehiclePickup()
    if not isEMS() or escortedBy or amIRestrained() then return end
    local veh = GetVehiclePedIsIn(cache.ped, false)
    if veh == 0 then lib.notify({ description = '車両に乗ってからピックしてください', type = 'error' }); return end
    if escortingCount > 0 or vehiclePatientTarget then
        lib.notify({ description = 'すでに患者を搬送しています', type = 'error' }); return
    end
    local registered = false
    if Config.Targets.npcs.enabled then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if not IsPedAPlayer(ped) and DoesEntityExist(ped) and GetEntityHealth(ped) > 0 and Entity(ped).state.emsDownDummy == true
                and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= Config.Distances.vehicleCarry
                and not NetworkGetEntityIsNetworked(ped) then
                NetworkRegisterEntityAsNetworked(ped)
                registered = true
            end
        end
    end
    if registered then Wait(250) end -- Allow newly networked corpse NPCs to reach the server.
    if not isEMS() or amIRestrained() or GetVehiclePedIsIn(cache.ped, false) ~= veh then return end
    TriggerServerEvent('ptech_mediora_escort:server:vehiclePickup', getFreeSeats(veh))
end

local function claimNPCControl(target)
    if target >= 0 then return true end
    local ped = NetworkGetEntityFromNetworkId(-target)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(ped)
        Wait(0)
    end
    return DoesEntityExist(ped) and NetworkGetEntityFromNetworkId(-target) == ped and NetworkHasControlOfEntity(ped)
end

local function waitVehicleClaim(state, escorter, ticket)
    local deadline = GetGameTimer() + 1500
    while (state.emsVehicleBy ~= escorter or state.emsVehicleTicket ~= ticket) and GetGameTimer() < deadline do Wait(0) end
    return state.emsVehicleBy == escorter and state.emsVehicleTicket == ticket
end

RegisterNetEvent('ptech_mediora_escort:client:prepareSoloCarry', function(target, ticket)
    if source ~= 65535 or vehiclePatientTarget ~= target or vehiclePatientTicket ~= ticket then return end
    if claimNPCControl(target) then TriggerServerEvent('ptech_mediora_escort:server:soloCarryReady', target, ticket) end
end)

RegisterNetEvent('ptech_mediora_escort:client:seatPickupPlayer', function(escorter, netId, seat, ticket)
    if source ~= 65535 or not waitVehicleClaim(LocalPlayer.state, escorter, ticket) then return end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetVehicleType(veh) ~= 'automobile' or not IsVehicleSeatFree(veh, seat) then return end
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local status = EscortRules.playerStatus(LocalPlayer.state, ok and data and data.metadata or nil, GetEntityHealth(cache.ped))
    if status.cuffed or not (status.dead or status.down) then return end
    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
end)

RegisterNetEvent('ptech_mediora_escort:client:seatPickupNPC', function(target, escorter, netId, seat, ticket)
    if source ~= 65535 or not claimNPCControl(target) then return end
    local ped = NetworkGetEntityFromNetworkId(-target)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) or not DoesEntityExist(veh) or GetVehicleType(veh) ~= 'automobile' or not IsVehicleSeatFree(veh, seat) then return end
    local state = Entity(ped).state
    if not waitVehicleClaim(state, escorter, ticket) or GetEntityHealth(ped) <= 100 or IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or state.emsDownDummy ~= true then return end
    SetPedCanRagdoll(ped, false)
    ClearPedTasksImmediately(ped)
    TaskWarpPedIntoVehicle(ped, veh, seat)
    if GetVehiclePedIsIn(ped, false) ~= veh then SetPedCanRagdoll(ped, true) end
end)

CreateThread(function()
    local previousVehicle = GetVehiclePedIsIn(cache.ped, false)
    while true do
        Wait(250)
        local current = GetVehiclePedIsIn(cache.ped, false)
        if previousVehicle ~= 0 and current == 0 and vehiclePatientTicket then
            local ticket, target = vehiclePatientTicket, vehiclePatientTarget
            if isEMS() and not amIRestrained() and claimNPCControl(target) then
                TriggerServerEvent('ptech_mediora_escort:server:exitWithPatient', ticket)
            end
        end
        previousVehicle = current
    end
end)

local onCarryKey, onReleaseKey

local function refreshEscortRadial()
    local groups = {
        { id = 'shoulder', label = '肩・背負い', icon = 'person-carry-box', items = {} },
        { id = 'back', label = 'おんぶ', icon = 'person', items = {} },
        { id = 'arms', label = '抱える', icon = 'hand-holding-heart', items = {} },
        { id = 'drag', label = '引きずる', icon = 'people-pulling', items = {} },
    }
    for _, t in ipairs(Config.CarryTypes) do
        local carry = t
        local group = t.id:find('piggyback', 1, true) and groups[2]
            or t.id:find('drag', 1, true) and groups[4]
            or (t.id:find('fireman', 1, true) or t.id == 'back_horizontal') and groups[1]
            or groups[3]
        group.items[#group.items + 1] = {
            label = (selectedCarry == t.id and '✓ ' or '') .. t.label:gsub('（比較用）', ''),
            icon = t.icon,
            onSelect = function()
                if not isEMS() then return end
                selectedCarry = carry.id
                lib.notify({ description = Config.Text.modeChanged:format(carry.label), type = 'success' })
                refreshEscortRadial()
            end,
        }
    end
    local root = {}
    for _, group in ipairs(groups) do
        if #group.items > 0 then
            local id = 'ems_escort_radial_' .. group.id
            lib.registerRadial({ id = id, items = group.items })
            root[#root + 1] = { label = group.label, icon = group.icon, menu = id }
        end
    end
    lib.registerRadial({ id = 'ems_escort_radial_styles', items = root })
    lib.registerRadial({ id = 'ems_escort_radial_transport', items = {
        { label = '患者を担ぐ', icon = 'person-carry-box', onSelect = function() onCarryKey() end },
        { label = '患者を下す', icon = 'hand-holding', onSelect = function() onReleaseKey() end },
        { label = 'スタイルを変更', icon = 'arrows-rotate', menu = 'ems_escort_radial_styles' },
    } })
end

local function openOptions()
    if not isEMS() then return end
    local options = {}
    for _, t in ipairs(Config.CarryTypes) do
        local carry = t
        options[#options + 1] = {
            title = (selectedCarry == t.id and '✓ ' or '') .. t.label,
            description = t.description,
            icon = t.icon,
            onSelect = function()
                if not isEMS() then return end
                selectedCarry = carry.id
                lib.notify({ description = Config.Text.modeChanged:format(carry.label), type = 'success' })
                if lib.registerRadial then refreshEscortRadial() end
            end,
        }
    end
    lib.registerContext({ id = 'ems_escort_options', title = Config.Text.optionsTitle, options = options })
    lib.showContext('ems_escort_options')
end

local function syncEscortJobEntry()
    if not lib.registerRadial or not lib.addRadialItem then return end
    refreshEscortRadial()
    -- Qbox may not have created JOB yet. Retry on lifecycle events, never by polling.
    if isEMS() then
        pcall(lib.addRadialItem, {
            id = 'emsEscort', label = 'EMS搬送', icon = 'truck-medical', menu = 'ems_escort_radial_transport',
        }, 'jobInteractionsMenu')
        pcall(lib.removeRadialItem, 'emsEscortStyles', 'jobInteractionsMenu')
    else
        pcall(lib.removeRadialItem, 'emsEscort', 'jobInteractionsMenu')
        pcall(lib.removeRadialItem, 'emsEscortStyles', 'jobInteractionsMenu')
    end
end

local function scheduleJobEntry()
    CreateThread(function()
        Wait(100) -- Let Qbox rebuild its JOB submenu first.
        syncEscortJobEntry()
    end)
end

for _, event in ipairs({ 'QBCore:Client:OnPlayerLoaded', 'QBCore:Client:OnJobUpdate', 'QBCore:Client:SetDuty', 'radialmenu:client:deadradial' }) do
    RegisterNetEvent(event, scheduleJobEntry)
end
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'qbx_radialmenu' then scheduleJobEntry() end
end)
scheduleJobEntry()

-- おろす専用：最後に運び始めた人を1人ずつ離す。
onReleaseKey = function()
    if not isEMS() or escortedBy or escortingCount <= 0 then return end
    local last = escortingOrder[#escortingOrder]
    if last then
        TriggerServerEvent('ptech_mediora_escort:server:stopOne', last)
    else
        TriggerServerEvent('ptech_mediora_escort:server:stopAll')
    end
end

-- 運ぶ専用：相手がいなくても、運んでいる人は離さない。
onCarryKey = function()
    if not isEMS() or escortedBy then return end
    if IsPedInAnyVehicle(cache.ped, false) then requestVehiclePickup(); return end
    if not canAddMore() then
        lib.notify({ description = Config.Text.tooMany, type = 'error' })
        return
    end
    local sid = getClosestEscortable()
    if sid then
        requestStart(sid)
    else
        lib.notify({ description = Config.Text.noTarget, type = 'error' })
    end
end

-- EMSキャリー：運んでいなければ拾い、運んでいれば落とす。
local function onKey()
    if not isEMS() or escortedBy then return end
    if escortingCount > 0 then onReleaseKey()
    elseif IsPedInAnyVehicle(cache.ped, false) then requestVehiclePickup()
    else onCarryKey() end
end

-- 運ぶ側の操作は何も制限しない（攻撃・エイム・ジャンプ・車に乗るすべて可）
-- 自分が死亡/手錠になった、または車に乗ったら運んでいる全員を離す
local function stopCarryAnim()
    local t = getCarryType(carryingType)
    if not t then return end
    local c = { escorterDict = t.escorter.dict, escorterAnim = t.escorter.anim }
    if IsEntityPlayingAnim(cache.ped, c.escorterDict, c.escorterAnim, 3) then
        StopAnimTask(cache.ped, c.escorterDict, c.escorterAnim, 1.0)
    end
end

-- キャリー中は運ぶ側のアニメ（上半身）を維持する。エイム・射撃中はかけ直さない
local function startCarryLoop()
    local t = getCarryType(carryingType)
    if not t then return end
    local c = { escorterDict = t.escorter.dict, escorterAnim = t.escorter.anim, flag = t.escorter.flag or 49 }
    lib.requestAnimDict(c.escorterDict)
    CreateThread(function()
        while carryingTarget do
            local ped = cache.ped
            if not IsPlayerFreeAiming(cache.playerId) and not IsPedShooting(ped)
                and not IsPedInAnyVehicle(ped, false)
                and not IsEntityPlayingAnim(ped, c.escorterDict, c.escorterAnim, 3) then
                TaskPlayAnim(ped, c.escorterDict, c.escorterAnim, 8.0, -8.0, -1, c.flag, 0.0, false, false, false)
            end
            Wait(250)
        end
        if IsEntityPlayingAnim(cache.ped, c.escorterDict, c.escorterAnim, 3) then
            StopAnimTask(cache.ped, c.escorterDict, c.escorterAnim, 1.0)
        end
    end)
end

local function startEscorterLoops()
    if watchLoopRunning then return end
    watchLoopRunning = true
    CreateThread(function()
        local handledVehicle = 0
        while escortingCount > 0 do
            Wait(500)
            if escortingCount > 0 then
                if amIRestrained() then
                    TriggerServerEvent('ptech_mediora_escort:server:stopAll')
                    Wait(1000)
                else
                    local veh = GetVehiclePedIsIn(cache.ped, false)
                    if veh == 0 then
                        handledVehicle = 0
                    elseif veh ~= handledVehicle then
                        handledVehicle = veh
                        if GetVehicleType(veh) == 'automobile' then
                            local seats = getFreeSeats(veh)
                            if #seats > 0 then
                                TriggerServerEvent('ptech_mediora_escort:server:autoBoard', NetworkGetNetworkIdFromEntity(veh), seats, selectedVehicleMode)
                            else
                                lib.notify({ description = Config.Text.noSeat, type = 'error' })
                            end
                        elseif GetVehicleType(veh) ~= 'bike' then
                            TriggerServerEvent('ptech_mediora_escort:server:stopAll')
                        end
                    end
                end
            end
        end
        watchLoopRunning = false
    end)
end

RegisterNetEvent('ptech_mediora_escort:client:addTarget', function(target, count, carryType)
    if carryType and not carryingTarget and getCarryType(carryType) then
        carryingTarget = target
        carryingType = carryType
        startCarryLoop()
    end
    if not escorting[target] then
        escorting[target] = true
        escortingOrder[#escortingOrder + 1] = target
    end
    escortingCount = count
    lib.notify({ description = Config.Text.started:format(count), type = 'success' })
    startEscorterLoops()
end)

RegisterNetEvent('ptech_mediora_escort:client:removeTarget', function(target, remain)
    if not escorting[target] then return end
    escorting[target] = nil
    if carryingTarget == target then stopCarryAnim() carryingTarget = nil carryingType = nil end
    for i = #escortingOrder, 1, -1 do
        if escortingOrder[i] == target then table.remove(escortingOrder, i) end
    end
    escortingCount = remain
    if remain > 0 then
        lib.notify({ description = Config.Text.stoppedOne:format(remain), type = 'inform' })
    else
        lib.notify({ description = Config.Text.stoppedAll, type = 'inform' })
    end
end)

-- ───────────── 運ばれる側 ─────────────

local function getEscorterPed()
    if not escortedBy then return 0 end
    local idx = GetPlayerFromServerId(escortedBy)
    if idx == -1 then return 0 end
    return GetPlayerPed(idx)
end

-- 何人目かによって位置をずらす
-- 肩に担ぐ：ambulance のみ（1人まで）
-- ダウン体：必ず左側（2人目以降も左へ少しずつずらして重ねる）
-- 手錠中：右横にまっすぐ立たせる（2人目以降はさらに右へ）
local function getOffset()
    local n = escortedSlot - 1
    local ct = escortedStyle == 'carry' and getCarryType(escortedCarryType) or nil
    if ct then
        return ct.pos[1], ct.pos[2], ct.pos[3], ct.rot[1], ct.rot[2], ct.rot[3]
    elseif escortedStyle == 'dead' then
        local d = Config.Dead
        return d.x + d.stepX * n, d.y + d.stepY * n, d.z, 0.0, 0.0, d.heading
    end
    local s = Config.Side
    return s.x + s.stepX * n, s.y, 0.0, 0.0, 0.0, 0.0
end

-- どちらも運ぶ人の「本体の位置」に付ける（ボーン番号 -1）
-- 体の骨（ルート・骨盤など）に付けると、歩くアニメに合わせて骨が動くので運ばれている人が揺れる・傾く
local function attachToEscorter(escorterPed)
    local ped = cache.ped
    local x, y, z, rx, ry, rz = getOffset()
    SetPedCanRagdoll(ped, false)
    if escortedStyle == 'cuffed' and IsPedRagdoll(ped) then
        -- 倒れた状態で付くと横になったまま運ばれるので起こしてから付ける
        ClearPedTasksImmediately(ped)
    end
    AttachEntityToEntity(ped, escorterPed, -1, x, y, z, rx, ry, rz, false, false, false, false, 2, true)
end

local function stopTargetAnims()
    local ped = cache.ped
    if IsEntityPlayingAnim(ped, WALK_DICT, WALK_ANIM, 3) then
        StopAnimTask(ped, WALK_DICT, WALK_ANIM, 1.0)
    end
    for _, t in ipairs(Config.CarryTypes) do
        if IsEntityPlayingAnim(ped, t.target.dict, t.target.anim, 3) then
            StopAnimTask(ped, t.target.dict, t.target.anim, 1.0)
        end
    end
end

local function detachSelf()
    escortedBy = nil
    escortedStyle = nil
    escortedCarryType = nil
    local ped = cache.ped
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    stopTargetAnims()
    SetPedCanRagdoll(ped, true)
end

RegisterNetEvent('ptech_mediora_escort:client:getEscorted', function(escorter, style, slot, carryType)
    local ped = cache.ped
    escortedBy = escorter
    escortedStyle = (style == 'carry' or style == 'dead') and style or 'cuffed'
    escortedCarryType = carryType
    if escortedStyle == 'carry' and not getCarryType(carryType) then escortedStyle = 'dead' end
    escortedSlot = tonumber(slot) or 1

    -- 車に乗っていたら降ろす
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        local timeout = GetGameTimer() + 1500
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeout do Wait(0) end
    end

    local escorterPed = getEscorterPed()
    if escorterPed == 0 then
        TriggerServerEvent('ptech_mediora_escort:server:lost')
        escortedBy = nil
        return
    end


    stopTargetAnims()
    if escortedStyle == 'carry' then lib.requestAnimDict(getCarryType(escortedCarryType).target.dict) end
    attachToEscorter(escorterPed)
    lib.notify({ description = Config.Text.beingEscorted, type = 'inform' })

    -- 操作ロック・アニメ維持
    CreateThread(function()
        while escortedBy do
            -- 肩に担がれているときだけ担がれる姿勢を維持（左側のダウン体・手錠中はアニメをかけない）
            if escortedStyle == 'carry' then
                local ct = getCarryType(escortedCarryType)
                if ct and not IsEntityPlayingAnim(cache.ped, ct.target.dict, ct.target.anim, 3) then
                    TaskPlayAnim(cache.ped, ct.target.dict, ct.target.anim, 8.0, -8.0, -1, ct.target.flag or 33, 0.0, false, false, false)
                end
            end
            -- 運ばれている間は一切動かない
            -- すべての操作を止め、カメラ・チャット・ボイス・ESCメニューだけ使えるようにする
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)     -- カメラ左右
            EnableControlAction(0, 2, true)     -- カメラ上下
            EnableControlAction(0, 245, true)   -- チャット
            EnableControlAction(0, 249, true)   -- ボイス（押して話す）
            EnableControlAction(0, 199, true)   -- ESC（ポーズメニュー）
            EnableControlAction(0, 200, true)
            Wait(0)
        end
    end)

    -- 取り付けの維持・運ぶ人が見えなくなったときの保険
    CreateThread(function()
        local lostSince
        while escortedBy do
            Wait(500)
            if not escortedBy then break end
            local esPed = getEscorterPed()
            if esPed == 0 or not DoesEntityExist(esPed) then
                lostSince = lostSince or GetGameTimer()
                if GetGameTimer() - lostSince > 3000 then
                    TriggerServerEvent('ptech_mediora_escort:server:lost')
                    detachSelf()
                    break
                end
            else
                lostSince = nil
                if not IsEntityAttachedToEntity(cache.ped, esPed) then
                    attachToEscorter(esPed)
                end
            end
        end
    end)
end)

RegisterNetEvent('ptech_mediora_escort:client:released', function()
    if not escortedBy then return end
    detachSelf()
    lib.notify({ description = Config.Text.released, type = 'inform' })
end)

RegisterNetEvent('ptech_mediora_escort:client:autoBoardPlayer', function(escorter, netId, seat)
    if source ~= 65535 or escortedBy ~= escorter or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    local owner = getEscorterPed()
    if veh == 0 or owner == 0 or not DoesEntityExist(veh) or GetVehicleType(veh) ~= 'automobile'
        or GetVehiclePedIsIn(owner, false) ~= veh or not IsVehicleSeatFree(veh, seat) then return end
    DetachEntity(cache.ped, true, false)
    stopTargetAnims()
    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
    if GetVehiclePedIsIn(cache.ped, false) == veh then
        detachSelf()
    elseif escortedBy == escorter then
        attachToEscorter(owner)
    end
end)

RegisterNetEvent('ptech_mediora_escort:client:putInVehicle', function(netId, seat)
    if not NetworkDoesNetworkIdExist(netId) or GetVehicleType(NetworkGetEntityFromNetworkId(netId)) ~= 'automobile' then return end
    detachSelf()
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    seat = tonumber(seat) or 0
    if seat % 1 ~= 0 or seat < 0 or seat >= GetVehicleMaxNumberOfPassengers(veh) then
        lib.notify({ description = Config.Text.noSeat, type = 'error' })
        return
    end
    if not IsVehicleSeatFree(veh, seat) then
        local free = getFreeSeats(veh)
        seat = free[1]
        if not seat then
            lib.notify({ description = Config.Text.noSeat, type = 'error' })
            return
        end
    end
    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
end)

-- NPCs have no player client to run the target-side attachment logic.
-- Only their current network owner changes the ped; server claims are authoritative.
local npcEscorts = {}

local function releaseNPC(id, ticket)
    local info = npcEscorts[id]
    if not info or info.ticket ~= ticket then return end
    npcEscorts[id] = nil
    local ped = info.ped
    if not ped or not DoesEntityExist(ped) or NetworkGetEntityFromNetworkId(-id) ~= ped then return end
    if not NetworkHasControlOfEntity(ped) then return end
    local newerTicket = Entity(ped).state.emsEscortTicket
    if newerTicket and newerTicket ~= ticket then return end
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    local carry = getCarryType(info.carryType)
    if carry then StopAnimTask(ped, carry.target.dict, carry.target.anim, 1.0) end
    SetPedCanRagdoll(ped, info.canRagdoll ~= false)
    SetBlockingOfNonTemporaryEvents(ped, false)
end

RegisterNetEvent('ptech_mediora_escort:client:escortNPC', function(id, escorter, style, slot, carryType, ticket)
    if source ~= 65535 then return end
    local info = { ticket = ticket, carryType = carryType }
    npcEscorts[id] = info
    CreateThread(function()
        while npcEscorts[id] == info do
            local ped = NetworkGetEntityFromNetworkId(-id)
            local idx = GetPlayerFromServerId(escorter)
            local ownerPed = idx ~= -1 and GetPlayerPed(idx) or 0
            if ped ~= 0 and DoesEntityExist(ped) and not IsPedAPlayer(ped)
                and ownerPed ~= 0 and NetworkHasControlOfEntity(ped) then
                local state = Entity(ped).state
                if state.emsEscortTicket == ticket and state.emsEscortedBy == escorter then
                    if not info.ped then
                        info.ped = ped
                        info.canRagdoll = CanPedRagdoll(ped)
                        if not IsEntityDead(ped) then ClearPedTasksImmediately(ped) end
                        SetBlockingOfNonTemporaryEvents(ped, true)
                    end
                    if info.ped ~= ped then break end
                    local n = slot - 1
                    local carry = style == 'carry' and getCarryType(carryType) or nil
                    local x, y, z, rx, ry, rz
                    if carry then
                        x, y, z = table.unpack(carry.pos)
                        rx, ry, rz = table.unpack(carry.rot)
                    elseif style == 'dead' then
                        local d = Config.Dead
                        x, y, z, rx, ry, rz = d.x + d.stepX*n, d.y + d.stepY*n, d.z, 0.0, 0.0, d.heading
                    else
                        local d = Config.Side
                        x, y, z, rx, ry, rz = d.x + d.stepX*n, d.y, 0.0, 0.0, 0.0, 0.0
                    end
                    SetPedCanRagdoll(ped, false)
                    if IsPedInAnyVehicle(ped, false) then
                        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
                    elseif not IsEntityAttachedToEntity(ped, ownerPed) then
                        AttachEntityToEntity(ped, ownerPed, -1, x, y, z, rx, ry, rz, false, false, false, false, 2, true)
                    end
                    if carry and not IsEntityPlayingAnim(ped, carry.target.dict, carry.target.anim, 3) then
                        lib.requestAnimDict(carry.target.dict)
                        if npcEscorts[id] == info and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) then
                            TaskPlayAnim(ped, carry.target.dict, carry.target.anim, 8.0, -8.0, -1,
                                carry.target.flag or 33, 0.0, false, false, false)
                        end
                    end
                end
            end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('ptech_mediora_escort:client:releaseNPC', function(id, ticket)
    if source ~= 65535 then return end
    -- If ownership moved, use the current local entity for cleanup as well.
    local info = npcEscorts[id]
    if info and not info.ped then
        local ped = NetworkGetEntityFromNetworkId(-id)
        if ped ~= 0 and DoesEntityExist(ped) then info.ped = ped end
    end
    releaseNPC(id, ticket)
end)

RegisterNetEvent('ptech_mediora_escort:client:autoBoardNPC', function(id, ticket, escorter, netId, seat)
    if source ~= 65535 then return end
    local info = npcEscorts[id]
    if not info or info.ticket ~= ticket then return end
    local ped = NetworkGetEntityFromNetworkId(-id)
    local veh = NetworkGetEntityFromNetworkId(netId)
    local idx = GetPlayerFromServerId(escorter)
    local owner = idx ~= -1 and GetPlayerPed(idx) or 0
    if ped == 0 or veh == 0 or owner == 0 or not DoesEntityExist(ped) or not DoesEntityExist(veh)
        or IsPedAPlayer(ped) or not NetworkHasControlOfEntity(ped) or GetVehicleType(veh) ~= 'automobile'
        or GetVehiclePedIsIn(owner, false) ~= veh or not IsVehicleSeatFree(veh, seat) then return end
    if Entity(ped).state.emsEscortTicket ~= ticket or Entity(ped).state.emsEscortedBy ~= escorter then return end
    DetachEntity(ped, true, false)
    local carry = getCarryType(info.carryType)
    if carry then StopAnimTask(ped, carry.target.dict, carry.target.anim, 1.0) end
    TaskWarpPedIntoVehicle(ped, veh, seat)
    if GetVehiclePedIsIn(ped, false) == veh then
        info.ped = ped
        releaseNPC(id, ticket)
    end
    -- On failure the existing NPC loop keeps the patient attached.
end)

RegisterNetEvent('ptech_mediora_escort:client:putNPCInVehicle', function(id, ticket, vehicleId, seat)
    if source ~= 65535 then return end
    local info = npcEscorts[id]
    if not info or info.ticket ~= ticket then return end
    local ped = NetworkGetEntityFromNetworkId(-id)
    local veh = NetworkGetEntityFromNetworkId(vehicleId)
    releaseNPC(id, ticket)
    if ped == 0 or veh == 0 or not DoesEntityExist(ped) or not DoesEntityExist(veh)
        or IsPedAPlayer(ped) or not NetworkHasControlOfEntity(ped) then return end
    if seat < 0 or seat >= GetVehicleMaxNumberOfPassengers(veh) or not IsVehicleSeatFree(veh, seat) then return end
    TaskWarpPedIntoVehicle(ped, veh, seat)
end)


-- ───────────── キー・ox_target ─────────────

-- 医者用：キー設定で割り当てたキーでエスコートオプション（次の運び方の選択）を開く
lib.addKeybind({
    name = 'ems_escort_options',
    description = Config.Text.optionsKeybind,
    defaultKey = Config.KeyOptions,
    onPressed = function()
        if not isCarryJob() then return end
        openOptions()
    end,
})

lib.addKeybind({
    name = 'ems_escort',
    description = Config.Text.keybind,
    defaultKey = Config.Key,
    onPressed = onKey,
})



if Config.UseTarget then
    local pedOptions = {
        {
            name = 'ems_escort_player',
            icon = 'fa-solid fa-people-pulling',
            label = Config.Text.targetEscort,
            distance = math.max(EscortRules.distance('walkNormal'), EscortRules.distance('walkCarry')),
            canInteract = function(entity, distance)
                if not isEMS() or escortedBy or amIRestrained() or not canAddMore() then return false end
                if distance and distance > getStartDistance() then return false end
                local sid = serverIdFromPed(entity)
                if IsPedInAnyVehicle(entity, false) then return false end
                if sid then return not escorting[sid] and isServerIdEscortable(sid) and isFree(sid) end
                return npcEscortable(entity)
            end,
            onSelect = function(data)
                local sid = serverIdFromPed(data.entity) or npcId(data.entity) or { npcPed = data.entity }
                if sid then requestStart(sid) end
            end,
        },
        {
            name = 'ems_escort_release',
            icon = 'fa-solid fa-hand',
            label = Config.Text.targetRelease,
            distance = Config.BreakDistance,
            canInteract = function(entity)
                local sid = serverIdFromPed(entity)
                return isEMS() and escorting[sid or npcId(entity)] == true
            end,
            onSelect = function(data)
                local sid = serverIdFromPed(data.entity) or npcId(data.entity)
                if sid then TriggerServerEvent('ptech_mediora_escort:server:stopOne', sid) end
            end,
        },
    }
    exports.ox_target:addGlobalPlayer(pedOptions)
    if Config.Targets.npcs.enabled then
        local npcOptions = {}
        for i, option in ipairs(pedOptions) do
            npcOptions[i] = {}
            for key, value in pairs(option) do npcOptions[i][key] = value end
            npcOptions[i].name = option.name .. '_npc'
        end
        exports.ox_target:addGlobalPed(npcOptions)
    end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'ems_escort_putin',
            icon = 'fa-solid fa-car-side',
            label = Config.Text.targetPutIn,
            distance = math.max(EscortRules.distance('vehicleNormal'), EscortRules.distance('vehicleMedical')),
            canInteract = function(entity, distance)
                if not isEMS() or amIRestrained() or IsPedInAnyVehicle(cache.ped, false) or (distance and distance > vehicleDistance()) then return false end
                return escortingCount > 0 and NetworkGetEntityIsNetworked(entity) and #getFreeSeats(entity) > 0
            end,
            onSelect = function(data)
                if not isEMS() or escortingCount <= 0 then return end
                local seats = getFreeSeats(data.entity)
                if #seats == 0 then
                    lib.notify({ description = Config.Text.noSeat, type = 'error' })
                    return
                end
                TriggerServerEvent('ptech_mediora_escort:server:putInVehicle', NetworkGetNetworkIdFromEntity(data.entity), seats, selectedVehicleMode)
            end,
        },
        {
            name = 'ems_escort_takeout',
            icon = 'fa-solid fa-person-walking-arrow-right',
            label = Config.Text.targetTakeOut,
            distance = math.max(EscortRules.distance('vehicleNormal'), EscortRules.distance('vehicleMedical')),
            canInteract = function(entity, distance)
                if not isEMS() or (distance and distance > EscortRules.distance('vehicleNormal')) then return false end
                if escortedBy or amIRestrained() or not canAddMore() or IsPedInAnyVehicle(cache.ped, false) then return false end
                return getRestrainedPassenger(entity) ~= nil
            end,
            onSelect = function(data)
                local sid = getRestrainedPassenger(data.entity)
                if sid then requestStart(sid) end
            end,
        },
    })
end

-- ───────────── 後片付け ─────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if carryingTarget then
        stopCarryAnim()
        carryingTarget = nil
        carryingType = nil
    end
    if escortedBy then detachSelf() end
    for id, info in pairs(npcEscorts) do releaseNPC(id, info.ticket) end
end)

-- 他スクリプト用
exports('getEscorting', function()
    local result = {}
    for sid in pairs(escorting) do if sid > 0 then result[#result + 1] = sid end end
    return result
end)
exports('isEscorted', function() return escortedBy end)

exports('getEscortingNPCs', function()
    local result = {}
    for id in pairs(escorting) do if id < 0 then result[#result + 1] = -id end end
    return result
end)


RegisterNetEvent('ptech_mediora_escort:client:createTestBody', function(netId)
    if source ~= 65535 or not isEMS() then return end
    local deadline = GetGameTimer() + 2500
    local ped
    repeat
        if NetworkDoesNetworkIdExist(netId) then ped = NetworkGetEntityFromNetworkId(netId) end
        if ped and ped ~= 0 and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped)
            and Entity(ped).state.emsTestBodyOwner == GetPlayerServerId(cache.playerId) then break end
        if ped and ped ~= 0 then NetworkRequestControlOfEntity(ped) end
        Wait(0)
    until GetGameTimer() >= deadline
    if not ped or ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) or not NetworkHasControlOfEntity(ped)
        or Entity(ped).state.emsTestBodyOwner ~= GetPlayerServerId(cache.playerId) then
        lib.notify({ description = 'テスト用NPCの制御権を取得できませんでした', type = 'error' }); return
    end
    SetEntityHealth(ped, 200)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
    TriggerServerEvent('ptech_mediora_escort:server:dummyReady', netId)
    lib.notify({ description = '搬送テスト用のNPCダウン体を作成しました', type = 'success' })
end)

-- Maintain the living dummy's fallen pose on whichever client currently owns it.
CreateThread(function()
    while true do
        Wait(1000)
        for _, ped in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and NetworkHasControlOfEntity(ped)
                and GetEntityHealth(ped) > 0 then
                local state = Entity(ped).state
                if state.emsDownDummy == true and state.emsTestBodyOwner and not state.emsEscortedBy
                    and not state.emsVehicleBy and not IsPedInAnyVehicle(ped, false) then
                    SetPedCanRagdoll(ped, true)
                    SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
                end
            end
        end
    end
end)
