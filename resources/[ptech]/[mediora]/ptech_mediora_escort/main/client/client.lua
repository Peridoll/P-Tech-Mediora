-- ems-escort / client

local escorting = {}        -- [運んでいる人のサーバーID] = true
local escortingCount = 0
local escortingOrder = {}   -- 搬送対象の記録（現行仕様では最大1人）
local escortedBy = nil      -- 自分を運んでいる人のサーバーID
local escortedGeneration = 0 -- 古い搬送スレッドの再実行を防ぐ
local escortedTicket = nil   -- 現在の搬送セッション識別子
local lastEscortedTicket = 0 -- 遅延した旧開始イベントを無視する
local escortedStyle = nil    -- 'carry'
local carryingTarget = nil   -- 自分がキャリーしている人のサーバーID
local carryingType = nil     -- 自分が使用するCarryModesスタイルのID
local escortedCarryType = nil -- 自分がキャリーされているときの種類

-- 設定が空でも救助できる内蔵の肩担ぎ。Config側の同名IDが優先。
local builtinFireman = {
    id = 'fireman', label = '肩に担ぐ', icon = 'person-carry-box',
    description = '標準の肩担ぎ',
    escorter = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
    target = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
    pos = { 0.27, 0.15, 0.63 }, rot = { 0.5, 0.5, 180.0 }, bone = -1,
}
-- スタイルIDは分類ごとに独立。IDだけ渡された場合は徒歩を参照する。
local function getCarryType(id, mode)
    mode = mode or 'walk'
    for _, t in ipairs((Config.CarryModes or {})[mode] or {}) do
        if t.id == id then return t end
    end
    if mode == 'walk' and id == 'fireman' then return builtinFireman end
    return nil
end

local function getActiveCarryType(id, mode)
    return getCarryType(id, mode) or getCarryType(id, 'walk') or getCarryType('fireman', 'walk')
end
local selectedCarry = GetResourceKvpString('escort_style') or 'fireman'
if not getCarryType(selectedCarry) then selectedCarry = 'fireman' end
local function saveCarryStyle(id)
    selectedCarry = id
    SetResourceKvp('escort_style', id)
end
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
    return escortingCount < 1
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
    if ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped)
        or IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end
    local id = npcId(ped)
    if id and escorting[id] then return false end
    local state = Entity(ped).state
    local validOwner = state[Config.NPCOwnerKey] == GetCurrentResourceName()
    for _, resource in ipairs(Config.NPCResources or {}) do
        if state[Config.NPCOwnerKey] == resource then validOwner = true end
    end
    if not validOwner or state[Config.NPCStatusKey] ~= 'down' then return false end
    if state.emsEscortedBy or state.emsVehicleBy then return false end
    for _, key in ipairs(Config.ExternalBusyKeys) do if stateValue(state[key]) then return false end end
    return EscortRules.allowed(EscortRules.npcStatus(state, GetEntityHealth(ped), IsEntityDead(ped) or IsPedDeadOrDying(ped, true)), true)
end

local function getClosestEscortable()
    local myCoords = GetEntityCoords(cache.ped)
    local range = getStartDistance()
    local bestSid, bestDist, bestSeatDist
    for _, idx in ipairs(GetActivePlayers()) do
        if idx ~= cache.playerId then
            local ped = GetPlayerPed(idx)
            if ped ~= 0 then
                local veh = GetVehiclePedIsIn(ped, false)
                local dist = #(GetEntityCoords(veh ~= 0 and veh or ped) - myCoords)
                local allowedRange = veh ~= 0 and Config.Distances.vehicleCarry or range
                local seatDist = #(GetEntityCoords(ped) - myCoords)
                if dist <= allowedRange and (not bestDist or dist < bestDist - 0.01
                    or (math.abs(dist - bestDist) <= 0.01 and seatDist < bestSeatDist)) then
                    local sid = GetPlayerServerId(idx)
                    if not escorting[sid] and isFree(sid) and isServerIdEscortable(sid) then
                        bestSid, bestDist, bestSeatDist = sid, dist, seatDist
                    end
                end
            end
        end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if npcEscortable(ped) then
            local veh = GetVehiclePedIsIn(ped, false)
            local dist = #(GetEntityCoords(veh ~= 0 and veh or ped) - myCoords)
            local allowedRange = veh ~= 0 and Config.Distances.vehicleCarry or range
            local seatDist = #(GetEntityCoords(ped) - myCoords)
            if dist <= allowedRange and (not bestDist or dist < bestDist - 0.01
                or (math.abs(dist - bestDist) <= 0.01 and seatDist < bestSeatDist)) then
                bestSid, bestDist, bestSeatDist = npcId(ped) or { npcPed = ped }, dist, seatDist
            end
        end
    end
    return bestSid
end

-- 乗せる座席はEMSの位置から最も近い空席を優先。運転席(-1)は常に除外。
local function seatPosition(veh, seat)
    local names = {
        [0] = 'seat_pside_f',
        [1] = 'seat_dside_r',
        [2] = 'seat_pside_r',
        [3] = 'seat_dside_r1',
        [4] = 'seat_pside_r1',
    }
    local name = names[seat]
    local bone = name and GetEntityBoneIndexByName(veh, name) or -1
    if bone and bone >= 0 then return GetWorldPositionOfEntityBone(veh, bone) end
    return GetEntityCoords(veh)
end

local function getFreeSeats(veh)
    local seats, myCoords = {}, GetEntityCoords(cache.ped)
    local max = GetVehicleMaxNumberOfPassengers(veh)
    for seat = 0, max - 1 do
        if IsVehicleSeatFree(veh, seat) then
            seats[#seats + 1] = { seat = seat, dist = #(seatPosition(veh, seat) - myCoords) }
        end
    end
    table.sort(seats, function(a, b) return a.dist < b.dist end)
    local sorted = {}
    for _, entry in ipairs(seats) do sorted[#sorted + 1] = entry.seat end
    return sorted
end

local function getRestrainedPassenger(veh)
    local max, nearest, nearestDistance = GetVehicleMaxNumberOfPassengers(veh)
    local myCoords = GetEntityCoords(cache.ped)
    for seat = 0, max - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and ped ~= cache.ped then
            local sid = serverIdFromPed(ped)
            local valid = sid and isServerIdEscortable(sid) and isFree(sid)
                or not sid and npcEscortable(ped)
            if valid then
                local distance = #(seatPosition(veh, seat) - myCoords)
                if not nearestDistance or distance < nearestDistance then
                    nearest, nearestDistance = sid or npcId(ped), distance
                end
            end
        end
    end
    return nearest
end

-- ───────────── 運ぶ側 ─────────────

-- 自分が「エスコートオプション」を使えるジョブか（医者のみ）
local function isCarryJob()
    return isEMS()
end

-- 医者がオプションで選んだ運び方（nil = 通常のエスコート）。次にエスコートする人から使われる
local function requestStart(sid)
    if escortedBy then return end
    if amIRestrained() or IsPedInAnyVehicle(cache.ped, false) then
        lib.notify({ description = Config.Text.cannotNow, type = 'error' })
        return
    end
    if not canAddMore() then
        lib.notify({ description = Config.Text.tooMany, type = 'error' })
        return
    end
    local carryType = selectedCarry
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
    if escortedBy or amIRestrained() or IsPedInAnyVehicle(cache.ped, false) then return end
    TriggerServerEvent('ptech_mediora_escort:server:start', sid, carryType)
end

-- 医者用のオプション画面（運び方を選ぶだけ。近くの人をエスコートはしない）
local vehiclePatientTarget, vehiclePatientTicket

RegisterNetEvent('ptech_mediora_escort:client:vehiclePatient', function(target, ticket)
    if source ~= 65535 then return end
    vehiclePatientTarget, vehiclePatientTicket = target, ticket
end)

local function requestVehiclePickup()
    if not Config.VehiclePickup.Enabled or not isEMS() or escortedBy or amIRestrained() then return end
    local veh = GetVehiclePedIsIn(cache.ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= cache.ped then return end
    if escortingCount > 0 then return end
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

-- PD専用一括ピックアップ。サーバーから確保済みの座席・チケットのみ受け入れる。
RegisterNetEvent('ptech_mediora_escort:client:pdBatchSeat', function(escorter, netId, seat, ticket)
    if source ~= 65535 or not waitVehicleClaim(LocalPlayer.state, escorter, ticket) then return end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or not IsVehicleSeatFree(veh, seat) then return end
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local status = EscortRules.playerStatus(LocalPlayer.state,
        ok and data and data.metadata or nil, GetEntityHealth(cache.ped))
    if not (status.down or status.dead) or IsPedInAnyVehicle(cache.ped, false) then return end
    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
    Wait(100)
    TriggerServerEvent('ptech_mediora_escort:server:pdBatchSeatDone', ticket)
end)

RegisterNetEvent('ptech_mediora_escort:client:seatPickupPlayer', function(escorter, netId, seat, ticket)
    if source ~= 65535 or not waitVehicleClaim(LocalPlayer.state, escorter, ticket) then return end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli') or not IsVehicleSeatFree(veh, seat) then return end
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local status = EscortRules.playerStatus(LocalPlayer.state, ok and data and data.metadata or nil, GetEntityHealth(cache.ped))
    if not (status.dead or status.down) then return end
    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
end)

RegisterNetEvent('ptech_mediora_escort:client:seatPickupNPC', function(target, escorter, netId, seat, ticket)
    if source ~= 65535 or not claimNPCControl(target) then return end
    local ped = NetworkGetEntityFromNetworkId(-target)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) or not DoesEntityExist(veh) or (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli') or not IsVehicleSeatFree(veh, seat) then return end
    local state = Entity(ped).state
    if not waitVehicleClaim(state, escorter, ticket) or GetEntityHealth(ped) <= 100 or IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or state.emsDownDummy ~= true then return end
    SetPedCanRagdoll(ped, false)
    ClearPedTasksImmediately(ped)
    TaskWarpPedIntoVehicle(ped, veh, seat)
    if GetVehiclePedIsIn(ped, false) ~= veh then SetPedCanRagdoll(ped, true) end
end)

-- 降車時は患者を自動回収しない。通常搬送キーから車内患者を選択する。

local onCarryKey, onReleaseKey, onKey

-- Configの分類別リストを登録。未登録の分類は徒歩スタイルに戻す。
local carryModeNames = { walk = '徒歩', bike = 'バイク', swim = '水泳', action = 'アクション' }
local carryModeIcons = { walk = 'footprints', bike = 'bike', swim = 'waves', action = 'mountain' }
local carryModeOrder = { 'walk', 'bike', 'swim', 'action' }
local selectedModes = { walk = selectedCarry }
for _, mode in ipairs(carryModeOrder) do
    if mode ~= 'walk' then selectedModes[mode] = GetResourceKvpString('escort_style_' .. mode) end
end

-- 搬送開始時の4分類設定を固定し、搬送中のラジアル変更は次回から使う。
local activeModeStyles

local function resolveCarryMode()
    local ped = cache.ped
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetVehicleType(veh) == 'bike' then return 'bike' end
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then return 'swim' end
    if IsPedClimbing(ped) or IsPedVaulting(ped) then return 'action' end
    return 'walk'
end

local function effectiveCarryStyle()
    local mode = resolveCarryMode()
    local id = activeModeStyles and activeModeStyles[mode]
    if id and getCarryType(id, mode) then return id, mode end
    return activeModeStyles and activeModeStyles.walk or 'fireman', 'walk'
end

local function getModeOptions(mode)
    local options = {}
    if mode == 'walk' then
        local hasStandard = false
        for _, style in ipairs((Config.CarryModes and Config.CarryModes.walk or {})) do
            options[#options + 1] = style
            if style.id == 'fireman' then hasStandard = true end
        end
        if not hasStandard then table.insert(options, 1, builtinFireman) end
    else
        for _, style in ipairs((Config.CarryModes or {})[mode] or {}) do
            options[#options + 1] = style
        end
    end
    return options
end

local function refreshEscortRadial()
    local modeItems = {}
    for _, mode in ipairs(carryModeOrder) do
        local options = getModeOptions(mode)
        if mode == 'walk' or #options > 0 then
            local items = {}
            for _, style in ipairs(options) do
                local selectedStyle, currentMode = style, mode
                items[#items + 1] = {
                    label = (selectedModes[mode] == style.id and '✓ ' or '') .. style.label,
                    icon = style.icon or carryModeIcons[mode],
                    onSelect = function()
                        selectedModes[currentMode] = selectedStyle.id
                        if currentMode == 'walk' then
                            saveCarryStyle(selectedStyle.id)
                        else
                            SetResourceKvp('escort_style_' .. currentMode, selectedStyle.id)
                        end
                        refreshEscortRadial()
                    end
                }
            end
            local id = 'mediora_escort_style_' .. mode
            lib.registerRadial({ id = id, items = items })
            modeItems[#modeItems + 1] = {
                label = carryModeNames[mode], icon = carryModeIcons[mode], menu = id,
            }
        end
    end
    lib.registerRadial({ id = 'mediora_escort_styles', items = modeItems })
    lib.registerRadial({ id = 'mediora_escort_citizen', items = {
        { label = '担ぐ / おろす', icon = 'hand', onSelect = function() onKey() end },
        { label = '搬送スタイル', icon = 'person-carry-box', menu = 'mediora_escort_styles' },
    } })
end

local function syncEscortJobEntry()
    if not lib.registerRadial or not lib.addRadialItem then return end
    refreshEscortRadial()
    -- 市民タブが提供されている場合はそこへ。未登録ならグローバルへ。
    local entry = { id = 'medioraEscortCitizen', label = '患者搬送',
        icon = 'hand-heart', menu = 'mediora_escort_citizen' }
    local ok = pcall(lib.addRadialItem, entry, Config.CitizenRadialMenu or 'citizenMenu')
    if ok then
        -- 起動順によって一度ルートに置いた項目があれば取り除く。
        pcall(lib.removeRadialItem, 'medioraEscortCitizen')
    else
        -- 他のラジアル構成でも最低限の設定入口を確保する。
        pcall(lib.addRadialItem, entry)
    end
    -- 以前のEMS専用メニューが残らないようにする。
    pcall(lib.removeRadialItem, 'emsEscort', 'jobInteractionsMenu')
    pcall(lib.removeRadialItem, 'emsEscortStyles', 'jobInteractionsMenu')
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
    if escortedBy or escortingCount <= 0 then return end
    local last = escortingOrder[#escortingOrder]
    if last then
        TriggerServerEvent('ptech_mediora_escort:server:stopOne', last)
    else
        TriggerServerEvent('ptech_mediora_escort:server:stopAll')
    end
end

-- 運ぶ専用：相手がいなくても、運んでいる人は離さない。
onCarryKey = function()
    if escortedBy then return end
    if IsPedInAnyVehicle(cache.ped, false) then
        if isEMS() and GetPedInVehicleSeat(GetVehiclePedIsIn(cache.ped, false), -1) == cache.ped then requestVehiclePickup() end
        return
    end
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
onKey = function()
    if escortedBy then return end
    if escortingCount > 0 then onReleaseKey()
    elseif IsPedInAnyVehicle(cache.ped, false) then
        if isEMS() and GetPedInVehicleSeat(GetVehiclePedIsIn(cache.ped, false), -1) == cache.ped then requestVehiclePickup() end
    else onCarryKey() end
end

-- 搬送者の移動は維持し、攻撃・武器操作は搬送中に制限する。
-- 搬送者が行動不能になった場合は搬送を解除する。
local function stopCarryAnim()
    local t = getCarryType(carryingType)
    if not t then return end
    local c = { escorterDict = t.escorter.dict, escorterAnim = t.escorter.anim }
    if IsEntityPlayingAnim(cache.ped, c.escorterDict, c.escorterAnim, 3) then
        StopAnimTask(cache.ped, c.escorterDict, c.escorterAnim, 1.0)
    end
end

-- キャリー中は運ぶ側のアニメ（上半身）を維持する。
-- 搬送者の攻撃・武器操作を禁止。移動・ダッシュ・ジャンプは妨げない。
local function controlCarryActions()
    CreateThread(function()
        while carryingTarget do
            DisablePlayerFiring(cache.playerId, true)
            for _, control in ipairs({ 24, 25, 37, 140, 141, 142, 257, 263, 264 }) do
                DisableControlAction(0, control, true)
            end
            if GetSelectedPedWeapon(cache.ped) ~= GetHashKey('WEAPON_UNARMED') then
                SetCurrentPedWeapon(cache.ped, GetHashKey('WEAPON_UNARMED'), true)
            end
            Wait(0)
        end
    end)
end

local function startCarryLoop()
    CreateThread(function()
        local playing
        while carryingTarget do
            local ped = cache.ped
            local id, mode = effectiveCarryStyle()
            local style = getActiveCarryType(id, mode)
            if style then
                if playing and playing ~= style then
                    StopAnimTask(ped, playing.escorter.dict, playing.escorter.anim, 1.0)
                end
                if playing ~= style then
                    local ok = pcall(lib.requestAnimDict, style.escorter.dict)
                    if not ok then
                        style = getCarryType('fireman', 'walk')
                        pcall(lib.requestAnimDict, style.escorter.dict)
                    end
                    playing = style
                    LocalPlayer.state:set('medioraEscortStyle', style.id, true)
                    LocalPlayer.state:set('medioraEscortMode', mode, true)
                end
                if GetVehiclePedIsIn(ped, false) == 0
                    and not IsEntityPlayingAnim(ped, style.escorter.dict, style.escorter.anim, 3) then
                    TaskPlayAnim(ped, style.escorter.dict, style.escorter.anim,
                        8.0, -8.0, -1, style.escorter.flag or 49, 0.0, false, false, false)
                end
            end
            Wait(Config.Sync.Interval or 500)
        end
        if playing then
            StopAnimTask(cache.ped, playing.escorter.dict, playing.escorter.anim, 1.0)
        end
        LocalPlayer.state:set('medioraEscortStyle', nil, true)
        LocalPlayer.state:set('medioraEscortMode', nil, true)
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
                        if (GetVehicleType(veh) == 'automobile' or GetVehicleType(veh) == 'heli') then
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
        activeModeStyles = { walk = carryType }
        for _, mode in ipairs({ 'bike', 'swim', 'action' }) do
            activeModeStyles[mode] = selectedModes[mode]
        end
        startCarryLoop()
        controlCarryActions()
    end
    if not escorting[target] then
        escorting[target] = true
        escortingOrder[#escortingOrder + 1] = target
    end
    escortingCount = count
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
    local styleId = escortedCarryType
    if escortedBy then
        local index = GetPlayerFromServerId(escortedBy)
        if index ~= -1 then styleId = Player(escortedBy).state.medioraEscortStyle or styleId end
    end
    local mode = escortedBy and Player(escortedBy).state.medioraEscortMode or 'walk'
    local carry = getActiveCarryType(styleId, mode)
    return carry.pos[1], carry.pos[2], carry.pos[3],
        carry.rot[1], carry.rot[2], carry.rot[3]
end

-- どちらも運ぶ人の「本体の位置」に付ける（ボーン番号 -1）
-- 体の骨（ルート・骨盤など）に付けると、歩くアニメに合わせて骨が動くので運ばれている人が揺れる・傾く
local function attachToEscorter(escorterPed)
    local ped = cache.ped
    local x, y, z, rx, ry, rz = getOffset()
    SetPedCanRagdoll(ped, false)
    if IsPedRagdoll(ped) then
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
    for _, group in pairs(Config.CarryModes or {}) do
        for _, t in ipairs(group) do
            if IsEntityPlayingAnim(ped, t.target.dict, t.target.anim, 3) then
                StopAnimTask(ped, t.target.dict, t.target.anim, 1.0)
            end
        end
    end
end

local function detachSelf()
    escortedGeneration = escortedGeneration + 1
    escortedBy = nil
    escortedTicket = nil
    escortedStyle = nil
    escortedCarryType = nil
    local ped = cache.ped
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    stopTargetAnims()
    SetPedCanRagdoll(ped, true)
end

RegisterNetEvent('ptech_mediora_escort:client:getEscorted', function(escorter, style, slot, carryType, ticket)
    if type(ticket) ~= 'number' or ticket <= lastEscortedTicket then return end
    lastEscortedTicket = ticket
    if escortedBy and escortedBy ~= escorter then detachSelf() end
    escortedGeneration = escortedGeneration + 1
    local generation = escortedGeneration
    escortedTicket = ticket
    local ped = cache.ped
    escortedBy = escorter
    escortedStyle = 'carry'
    -- 未登録IDは廃止済みの旧搬送姿勢に戻さず、内蔵の肩担ぎを使う。
    escortedCarryType = getCarryType(carryType) and carryType or 'fireman'
    escortedSlot = tonumber(slot) or 1

    -- 車に乗っていたら降ろす
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        local timeout = GetGameTimer() + 1500
        while IsPedInAnyVehicle(ped, false) and escortedGeneration == generation and GetGameTimer() < timeout do Wait(0) end
    end

    local escorterPed = getEscorterPed()
    local deadline = GetGameTimer() + ((Config.Sync and Config.Sync.Timeout) or 3000)
    while escorterPed == 0 and escortedGeneration == generation and escortedBy == escorter and GetGameTimer() < deadline do
        Wait(50)
        escorterPed = getEscorterPed()
    end
    if escortedGeneration ~= generation or escortedBy ~= escorter then return end
    if escorterPed == 0 then
        TriggerServerEvent('ptech_mediora_escort:server:lost', ticket)
        detachSelf()
        return
    end


    stopTargetAnims()
    if escortedStyle == 'carry' then lib.requestAnimDict(getCarryType(escortedCarryType).target.dict) end
    attachToEscorter(escorterPed)

    -- 操作ロック・アニメ維持
    local activePatientStyle
    CreateThread(function()
        while escortedGeneration == generation and escortedBy == escorter do
            -- 現在の移動分類に対応する搬送姿勢を維持する。
            if escortedStyle == 'carry' then
                local current = Player(escortedBy).state.medioraEscortStyle or escortedCarryType
                local mode = Player(escortedBy).state.medioraEscortMode or 'walk'
                local ct = getActiveCarryType(current, mode)
                if ct and (ct ~= activePatientStyle) then
                    stopTargetAnims()
                    activePatientStyle = ct
                    escortedCarryType = current
                    local owner = getEscorterPed()
                    if owner ~= 0 then attachToEscorter(owner) end
                end
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
        while escortedGeneration == generation and escortedBy == escorter do
            Wait(500)
            if escortedGeneration ~= generation or escortedBy ~= escorter then break end
            local esPed = getEscorterPed()
            if esPed == 0 or not DoesEntityExist(esPed) then
                lostSince = lostSince or GetGameTimer()
                if GetGameTimer() - lostSince > ((Config.Sync and Config.Sync.Timeout) or 3000) then
                    TriggerServerEvent('ptech_mediora_escort:server:lost', ticket)
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

RegisterNetEvent('ptech_mediora_escort:client:released', function(ticket)
    if not escortedBy or ticket ~= escortedTicket then return end
    detachSelf()
end)

RegisterNetEvent('ptech_mediora_escort:client:autoBoardPlayer', function(escorter, netId, seat)
    if source ~= 65535 or escortedBy ~= escorter or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    local owner = getEscorterPed()
    if veh == 0 or owner == 0 or not DoesEntityExist(veh) or (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli')
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
    local carry = info.currentStyle or getCarryType(info.carryType)
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
                    local carrierState = Player(escorter).state
                    local displayId = carrierState.medioraEscortStyle or carryType
                    local mode = carrierState.medioraEscortMode or 'walk'
                    local carry = getActiveCarryType(displayId, mode)
                    local x, y, z = table.unpack(carry.pos)
                    local rx, ry, rz = table.unpack(carry.rot)
                    SetPedCanRagdoll(ped, false)
                    if IsPedInAnyVehicle(ped, false) then
                        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
                    elseif not IsEntityAttachedToEntity(ped, ownerPed) or info.currentStyle ~= carry then
                        -- 同じIDでもモードが変われば接続位置・角度を更新する。
                        AttachEntityToEntity(ped, ownerPed, -1, x, y, z, rx, ry, rz, false, false, false, false, 2, true)
                    end
                    if carry and not IsEntityPlayingAnim(ped, carry.target.dict, carry.target.anim, 3) then
                        if info.currentStyle and info.currentStyle ~= carry then
                            StopAnimTask(ped, info.currentStyle.target.dict, info.currentStyle.target.anim, 1.0)
                        end
                        info.currentStyle = carry
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
        or IsPedAPlayer(ped) or not NetworkHasControlOfEntity(ped) or (GetVehicleType(veh) ~= 'automobile' and GetVehicleType(veh) ~= 'heli')
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

-- 担ぐ/おろすの一つのキー。スタイル変更はラジアルで行う。
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
                if escortedBy or amIRestrained() or not canAddMore() then return false end
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
                return escorting[sid or npcId(entity)] == true
            end,
            onSelect = function(data)
                local sid = serverIdFromPed(data.entity) or npcId(data.entity)
                if sid then TriggerServerEvent('ptech_mediora_escort:server:stopOne', sid) end
            end,
        },
    }
    exports.ox_target:addGlobalPlayer(pedOptions)
    local npcOptions = {}
    for i, option in ipairs(pedOptions) do
        npcOptions[i] = {}
        for key, value in pairs(option) do npcOptions[i][key] = value end
        npcOptions[i].name = option.name .. '_npc'
    end
    exports.ox_target:addGlobalPed(npcOptions)

    exports.ox_target:addGlobalVehicle({
        {
            name = 'ems_escort_putin',
            icon = 'fa-solid fa-car-side',
            label = Config.Text.targetPutIn,
            distance = math.max(EscortRules.distance('vehicleNormal'), EscortRules.distance('vehicleMedical')),
            canInteract = function(entity, distance)
                if amIRestrained() or IsPedInAnyVehicle(cache.ped, false) or (distance and distance > vehicleDistance()) then return false end
                return escortingCount > 0 and NetworkGetEntityIsNetworked(entity)
            end,
            onSelect = function(data)
                if escortingCount <= 0 then return end
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
                if distance and distance > EscortRules.distance('vehicleNormal') then return false end
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
