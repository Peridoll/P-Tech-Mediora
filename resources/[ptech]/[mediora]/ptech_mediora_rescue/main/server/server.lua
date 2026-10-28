-- 要請の正当性・重複・死亡セッションをサーバー側で管理する。
local sessions, lastRequest = {}, {}
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
    s.used, s.phase = true, 'requested'
    -- 要請者だけが受信する。演出entityはネットワーク共有しない。
    TriggerClientEvent('ptech_mediora_rescue:dispatch', src)
    return true
end)
-- 完了通知はクライアントから受けても、サーバー上の予約状態と死亡を再確認する。
RegisterNetEvent('ptech_mediora_rescue:phase', function(phase)
    local src = source
    local s = sessions[src]
    if not s or not s.used or not valid(src) then return end
    if phase == 'transporting' and s.phase == 'requested' then
        s.phase = 'transporting'
        for _, id in ipairs(GetPlayers()) do
            local target = tonumber(id)
            local ed = data(target)
            if ed and ed.job and ed.job.name == Config.EMSJob and ed.job.onduty == true then
                TriggerClientEvent('ptech_mediora_rescue:emsNotify', target, '搬送開始')
            end
        end
    elseif phase == 'arrived' and s.phase == 'transporting' then
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
                    sessions[src] = nil
                else
                    session(src)
                end
            end
        end
        for src in pairs(sessions) do if not online[src] then sessions[src] = nil end end
    end
end)
AddEventHandler('playerDropped', function()
    sessions[source], lastRequest[source] = nil, nil
end)
