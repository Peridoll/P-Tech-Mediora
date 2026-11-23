-- 死亡セッションと要請を別々に管理する。搭乗確認前の失敗では使用権を消費しない。
local sessions, lastRequest, aircraft = {}, {}, {}
local sequence = 0

local function removeAircraft(src, ticket)
    local a = aircraft[src]
    if not a or (ticket and a.ticket ~= ticket) then return end
    aircraft[src] = nil
    local p = exports.qbx_core:GetPlayer(src)
    -- 通信断・リソース停止でも、搭乗者を空中へ取り残さない。
    if not a.arrived and p and p.PlayerData.citizenid == a.citizenid
        and a.heli and DoesEntityExist(a.heli) and GetPlayerPed(src) == a.ped
        and GetPlayerRoutingBucket(src) == a.bucket and GetVehiclePedIsIn(a.ped) == a.heli then
        SetEntityCoords(a.ped, a.origin.x, a.origin.y, a.origin.z, false, false, false, false)
    end
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
    if not d or not d.citizenid then return false, d, ped, 'プレイヤー情報を確認できないため中断しました' end
    if not Rescue.allowed(d.job) then return false, d, ped, '対象職の勤務状態が終了したため中断しました' end
    if ped == 0 or not DoesEntityExist(ped) then return false, d, ped, 'プレイヤーの実体を確認できないため中断しました' end
    if not Rescue.down(Player(src).state, d.metadata) then return false, d, ped, '死亡・瀕死状態の終了を確認したため中断しました' end
    return true, d, ped
end

local function cancel(src, s, reason)
    if not s then return end
    if s.ticket then
        local d = data(src)
        local recover = d and d.citizenid == s.id and GetPlayerPed(src) == s.ped
            and GetPlayerRoutingBucket(src) == s.bucket
        reason = reason or '救助要請が取り消されました'
        print(('[ptech_mediora_rescue] 要請中断 src=%d ticket=%s reason=%s'):format(src, s.ticket, reason))
        TriggerClientEvent('ptech_mediora_rescue:cancel', src, s.ticket, recover == true, reason)
    end
    removeAircraft(src, s.ticket)
    s.pending, s.ticket, s.phase, s.requestId = false, nil, nil, nil
end

local function current(src, s)
    local ok, d, ped = valid(src)
    return sessions[src] == s and ok and s.id == d.citizenid and s.ped == ped
        and s.bucket == GetPlayerRoutingBucket(src)
end

local function session(src)
    local ok, d, ped, reason = valid(src)
    local s = sessions[src]
    if not ok then
        cancel(src, s, reason)
        sessions[src] = nil
        return nil
    end
    local bucket = GetPlayerRoutingBucket(src)
    if not s or s.id ~= d.citizenid or s.ped ~= ped or s.bucket ~= bucket then
        cancel(src, s, 'キャラクター・プレイヤー実体・バケットの変更により中断しました')
        s = { id = d.citizenid, ped = ped, bucket = bucket, started = GetGameTimer(), used = false }
        sessions[src] = s
    end
    return s
end

local function notifyEMS(src, stage)
    local bucket = GetPlayerRoutingBucket(src)
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local ed = data(target)
        if ed and ed.job and ed.job.name == Config.EMSJob and ed.job.onduty == true
            and GetPlayerRoutingBucket(target) == bucket then
            TriggerClientEvent('ptech_mediora_rescue:emsNotify', target, stage)
        end
    end
end

lib.callback.register('ptech_mediora_rescue:status', function(src)
    local s = session(src)
    if not s then return { eligible = false } end
    return { eligible = true, remaining = Rescue.remaining(s.started, GetGameTimer()), used = s.used or s.pending == true }
end)

lib.callback.register('ptech_mediora_rescue:request', function(src, requestId)
    if requestId ~= nil and (type(requestId) ~= 'string' or #requestId == 0 or #requestId > 96) then
        return false, '救助要請の識別子が不正です'
    end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 500 then return false, '少し待ってから再度要請してください' end
    lastRequest[src] = now
    local s = session(src)
    if not s then return false, '勤務状態またはダウン状態を確認できません' end
    if s.used then return false, '今回のダウンでは救助要請を使用済みです' end
    if s.pending then return false, '前の救助要請を処理中です。少し待ってください' end
    if Rescue.remaining(s.started, now) > 0 then return false, '緊急離脱の待機時間が残っています' end

    -- Create/Waitの途中にも別のcallbackが入るため、生成前に予約する。
    sequence = sequence + 1
    local ticket = sequence
    s.pending, s.ticket, s.phase, s.requestedAt = true, ticket, 'preparing', now
    s.requestId = requestId
    print(('[ptech_mediora_rescue] 要請受理 src=%d ticket=%d request=%s'):format(src, ticket, tostring(requestId)))
    local origin = GetEntityCoords(s.ped)
    local a = { ticket = ticket, ped = s.ped, citizenid = s.id, origin = origin, created = now, bucket = s.bucket }
    aircraft[src] = a
    local function ready(entity)
        if not entity or entity == 0 then return false end
        local deadline = GetGameTimer() + Config.SpawnTimeout
        while not DoesEntityExist(entity) and GetGameTimer() < deadline do
            -- 中断済みでも返却済みハンドルが実体化するまで待ち、後段で生成物を削除する。
            Wait(50)
        end
        return DoesEntityExist(entity) and current(src, s) and s.ticket == ticket
    end
    local failure
    local ok, result = xpcall(function()
        local z = origin.z + Config.Helicopter.HoverOffset
        local heading = GetEntityHeading(s.ped)
        a.heli = CreateVehicleServerSetter(joaat(Config.Helicopter.Model), 'heli', origin.x, origin.y, z, heading)
        if not ready(a.heli) then failure = '救助ヘリを生成できませんでした'; return false end
        SetEntityOrphanMode(a.heli, 2)
        SetEntityRoutingBucket(a.heli, s.bucket)
        FreezeEntityPosition(a.heli, true)
        a.pilot = CreatePed(4, joaat(Config.Helicopter.Pilot), origin.x, origin.y, z, heading, true, true)
        if not ready(a.pilot) then failure = '救助ヘリの操縦士を生成できませんでした'; return false end
        SetEntityRoutingBucket(a.pilot, s.bucket)
        SetEntityOrphanMode(a.pilot, 2)
        FreezeEntityPosition(a.pilot, true)
        local netId, netPilot = NetworkGetNetworkIdFromEntity(a.heli), NetworkGetNetworkIdFromEntity(a.pilot)
        if netId == 0 or netPilot == 0 then failure = '救助機のネットワークIDを取得できませんでした'; return false end
        s.phase = 'requested'
        print(('[ptech_mediora_rescue] 機体準備完了 src=%d ticket=%d heliNet=%d pilotNet=%d')
            :format(src, ticket, netId, netPilot))
        return { ticket = ticket, heli = netId, pilot = netPilot, citizenid = s.id }
    end, debug.traceback)
    if not ok or not result then
        if s.ticket == ticket then cancel(src, s) end
        -- セッション破棄後にCreateが返った場合の生成物も回収する。
        if a.pilot and DoesEntityExist(a.pilot) then DeleteEntity(a.pilot) end
        if a.heli and DoesEntityExist(a.heli) then DeleteEntity(a.heli) end
        if not ok then print('[ptech_mediora_rescue] 機体生成エラー: ' .. tostring(result)) end
        return false, failure or '救助機の生成中にエラーが発生しました。サーバーログを確認してください'
    end
    return result
end)

-- 応答タイムアウト時も、同じ要請IDの未搭乗機体だけを破棄する。
RegisterNetEvent('ptech_mediora_rescue:cancelPending', function(requestId)
    local src = source
    local s = sessions[src]
    if type(requestId) ~= 'string' or not s or s.requestId ~= requestId or s.used
        or (s.phase ~= 'preparing' and s.phase ~= 'requested') then return end
    cancel(src, s)
end)

-- 搭乗・到着はサーバー上の座席と座標が同期されてから受理する。
lib.callback.register('ptech_mediora_rescue:phase', function(src, ticket, phase)
    local s = session(src)
    local a = aircraft[src]
    if not s or not a or s.ticket ~= ticket or a.ticket ~= ticket or not s.pending then return false end
    if not DoesEntityExist(a.heli) or not DoesEntityExist(a.pilot) then return false end
    if phase == 'transporting' then
        if s.phase == 'transporting' then return true end
        local elapsed = GetGameTimer() - s.requestedAt
        if s.phase ~= 'requested' or elapsed < Config.Helicopter.PickupSeconds * 1000
            or elapsed > Config.PreparationTimeout or GetVehiclePedIsIn(s.ped) ~= a.heli then return false end
        s.used, s.phase, s.transportAt = true, 'transporting', GetGameTimer()
        notifyEMS(src, '搬送開始')
        return true
    elseif phase == 'arrived' then
        if s.phase == 'arrived' then return true end
        if s.phase ~= 'transporting' or GetGameTimer() - s.transportAt < 1000 then return false end
        local coords, dest = GetEntityCoords(s.ped), Config.Hospital.Entrance
        local dx, dy, dz = coords.x - dest.x, coords.y - dest.y, coords.z - dest.z
        local h, pad = GetEntityCoords(a.heli), Config.Hospital.Helipad
        if dx * dx + dy * dy + dz * dz > 625 or (h.x - pad.x)^2 + (h.y - pad.y)^2 > 2500 then return false end
        s.phase = 'arrived'
        a.arrived = true
        notifyEMS(src, '病院到着')
        return true
    end
    return false
end)

RegisterNetEvent('ptech_mediora_rescue:finish', function(ticket)
    local src = source
    local s = sessions[src]
    if not s or not s.ticket or s.ticket ~= ticket then return end
    removeAircraft(src, ticket)
    s.pending, s.ticket, s.phase, s.requestId = false, nil, nil, nil
end)

lib.callback.register('ptech_mediora_rescue:aircraftSnapshot', function(src)
    local result = {}
    local bucket = GetPlayerRoutingBucket(src)
    for owner, a in pairs(aircraft) do
        if a.bucket == bucket and a.heli and a.pilot and DoesEntityExist(a.heli) and DoesEntityExist(a.pilot) then
            result[#result + 1] = {
                heli = NetworkGetNetworkIdFromEntity(a.heli), pilot = NetworkGetNetworkIdFromEntity(a.pilot), owner = owner,
                published = GetGameTimer() - a.created >= Config.Helicopter.PublishAfter * 1000,
            }
        end
    end
    return result
end)

CreateThread(function()
    while true do
        Wait(250)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local s = session(src)
            if s and s.pending then
                local a = aircraft[src]
                local preparing = s.phase == 'preparing' or s.phase == 'requested'
                local limit = preparing and Config.PreparationTimeout
                    or (Config.Helicopter.MaxFlightSeconds + Config.Helicopter.LandingTimeout + 30) * 1000
                local reason
                if GetGameTimer() - s.requestedAt > limit then
                    reason = '救助機の準備または搬送が制限時間を超えました'
                elseif not a then
                    reason = '救助機の登録を確認できないため中断しました'
                elseif s.phase ~= 'preparing' and not DoesEntityExist(a.heli) then
                    reason = '救助ヘリがサーバー上で消失したため中断しました'
                elseif s.phase ~= 'preparing' and not DoesEntityExist(a.pilot) then
                    reason = '操縦士がサーバー上で消失したため中断しました'
                end
                if reason then cancel(src, s, reason) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    removeAircraft(source)
    sessions[source], lastRequest[source] = nil, nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(aircraft) do removeAircraft(src) end
end)
