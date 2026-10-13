local busy = false

local function notify(message)
    lib.notify({ title = '診察', description = message, type = 'error' })
end

local function nearby()
    local origin, closest, distance = GetEntityCoords(PlayerPedId()), nil, Config.Distance
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if ped ~= 0 then
                local d = #(origin - GetEntityCoords(ped))
                if d <= distance then closest, distance = GetPlayerServerId(player), d end
            end
        end
    end
    return closest, distance
end

local function diagnose(target)
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        if not Medical.allowed(exports.qbx_core:GetPlayerData()) then
            notify('勤務中の医療職のみ利用できます'); return
        end
        if not target then target = nearby() end
        if not target then notify(('%.1fm以内に対象がいません'):format(Config.Distance)); return end
        local auth = lib.callback.await('ptech_mediora_medical:inspect', false, target)
        if not auth or auth.error then notify(auth and auth.error or '診察許可を取得できません'); return end
        local success, injuries = pcall(function()
            return exports.wasabi_ambulance:diagnosePlayer(target)
        end)
        local confirm = lib.callback.await('ptech_mediora_medical:confirm', false, target)
        if not confirm or confirm.error then notify(confirm and confirm.error or '対象を再確認できません'); return end
        local report = lib.callback.await('ptech_mediora_medical:createReport', false, target, injuries, success)
        if not report or report.error then
            notify(report and report.error or '診断書を作成できませんでした')
        else
            lib.notify({ title = '診断書', description = '診断書を所持品に追加しました。診療番号: ' .. report.reportId, type = 'success' })
        end
        local description = MedicalUI.show({
            title = '診察 — ID ' .. target, success = success,
            death = confirm.death, injuries = injuries,
            refresh = function() diagnose(target) end,
        })
        if Config.Debug then
            print(('[ptech_mediora_medical] serverId=%s success=%s returnType=%s\n%s')
                :format(target, tostring(success), type(injuries), description))
        end
    end)
    busy = false
    if not ok then
        if Config.Debug then print('[ptech_mediora_medical] ' .. tostring(err)) end
        notify('診察に失敗しました。依存リソースの起動を確認してください')
    end
end

RegisterCommand(Config.Command, function() diagnose() end, false)
