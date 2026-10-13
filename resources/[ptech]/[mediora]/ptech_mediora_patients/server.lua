local sessions, lastStart = {}, {}
local function allowed(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData and player.PlayerData.job
    return job and Config.Jobs[job.name] and (not Config.RequireDuty or job.onduty == true)
end
local function closeTo(src, target)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - target) <= Config.InteractionDistance + 0.5
end
local function reply(ok, message, data)
    return { ok = ok, message = message, session = data }
end
lib.callback.register('ptech_mediora_patients:job', function(src, action, index)
    if not allowed(src) then return reply(false, '勤務中の医療職のみ利用できます') end
    if action == 'status' then return reply(true, '', sessions[src]) end
    if action == 'start' then
        if not closeTo(src, Config.Hospital) then return reply(false, '病院の受注地点にいません') end
        if sessions[src] then return reply(false, '進行中の診療依頼があります', sessions[src]) end
        local now = GetGameTimer()
        if lastStart[src] and now - lastStart[src] < Config.JobCooldownMs then
            return reply(false, '次の依頼まで少し待ってください')
        end
        local i = math.random(1, #Config.Patients)
        local entry = Config.Patients[i]
        if not entry or not Config.Cases[entry.case] then return reply(false, '患者設定を確認してください') end
        lastStart[src] = now
        sessions[src] = { index = i, stage = 'visit', started = now }
        return reply(true, entry.label .. 'の診療依頼を受注しました', sessions[src])
    end
    local session = sessions[src]
    if not session then return reply(false, '進行中の診療依頼がありません') end
    if action == 'cancel' then
        sessions[src] = nil
        return reply(true, '診療依頼をキャンセルしました')
    end
    local target = Config.Patients[session.index]
    if not target then sessions[src] = nil; return reply(false, '患者設定が変更されました') end
    if action == 'inspect' then
        if session.stage ~= 'visit' then return reply(false, '現在は診察できません') end
        if not closeTo(src, vec3(target.coords.x, target.coords.y, target.coords.z)) then
            return reply(false, '患者から離れています')
        end
        session.stage, session.inspected = 'return', GetGameTimer()
        return reply(true, '模擬診察が完了しました。病院に戻って報告してください', session)
    end
    if action == 'finish' then
        if session.stage ~= 'return' then return reply(false, '診察が完了していません') end
        if not closeTo(src, Config.Hospital) then return reply(false, '病院に戻ってください') end
        sessions[src] = nil
        return reply(true, '診療依頼を完了しました（v0.1.0では報酬なし）')
    end
    return reply(false, '無効な操作です')
end)
lib.callback.register('ptech_mediora_patients:testAccess', function(src)
    return allowed(src) == true
end)
AddEventHandler('playerDropped', function() sessions[source] = nil; lastStart[source] = nil end)
