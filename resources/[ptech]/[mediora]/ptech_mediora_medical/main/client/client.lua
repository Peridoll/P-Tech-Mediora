local busy = false

local function notify(message, kind)
    lib.notify({ title = '診察', description = message, type = kind or 'error' })
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

local function serverIdFromPed(ped)
    if not ped or ped == 0 or ped == PlayerPedId() or not IsPedAPlayer(ped) then return end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if not player or player == -1 then return end
    local serverId = GetPlayerServerId(player)
    if not serverId or serverId <= 0 or serverId == GetPlayerServerId(PlayerId()) then return end
    return serverId
end

local function cancelExamination(target)
    lib.callback.await('ptech_mediora_medical:cancel', false, target)
end

-- This is the single entrance for commands and ox_target. Never trust this
-- target alone: the server checks job, duty, target, range, and bucket twice.
local function startDiagnosis(target)
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

        local finished = lib.progressCircle({
            duration = Config.Examination.Duration,
            label = Config.Examination.Label,
            position = 'bottom',
            canCancel = true,
            useWhileDead = false,
            disable = { move = true, car = true, combat = true },
            anim = Config.Examination.Animation,
            prop = Config.Examination.Prop,
        })
        if not finished then
            cancelExamination(target)
            notify('診察を中止しました', 'inform')
            return
        end

        -- The patient can move, disconnect, or change buckets during the animation.
        local confirm = lib.callback.await('ptech_mediora_medical:confirm', false, target)
        if not confirm or confirm.error then notify(confirm and confirm.error or '対象を再確認できません'); return end
        local success, injuries = pcall(function()
            return exports.wasabi_ambulance:diagnosePlayer(target)
        end)

        local snapshot = {
            title = '診察 — ID ' .. target, success = success,
            death = confirm.death, injuries = injuries,
            refresh = function() startDiagnosis(target) end,
        }
        local chart = lib.callback.await('ptech_mediora_medical:createChart', false, target, injuries, success)
        local description = MedicalUI.describe(snapshot)
        if chart and chart.chart then
            if GetResourceState('ptech_mediora_manager') == 'started' then
                exports.ptech_mediora_manager:openCharts(target, chart.chart.chartId)
            else
                MedicalUI.show(snapshot)
                notify('EMSManagerが未起動のため、簡易結果画面を表示しています', 'inform')
            end
        elseif chart and chart.noChart then
            MedicalUI.show(snapshot)
            notify(chart.message or '確認できる負傷情報がないため、カルテは作成しませんでした', 'inform')
        elseif not chart or chart.error then
            MedicalUI.show(snapshot)
            notify(chart and chart.error or 'カルテを作成できませんでした')
        else
            MedicalUI.show(snapshot)
        end
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

local function commandUsage()
    local command = Config.Commands.Name
    notify(('使い方: /%s %s [ID]'):format(command, Config.Commands.Action), 'inform')
end

local function handleCommand(_, args)
    args = args or {}
    local action = type(args[1]) == 'string' and args[1]:lower() or ''
    if action ~= Config.Commands.Action then
        commandUsage()
        return
    end
    if args[3] ~= nil then commandUsage(); return end
    if args[2] == nil then startDiagnosis(); return end
    if type(args[2]) ~= 'string' or not args[2]:match('^%d+$') then
        notify('IDには対象プレイヤーの数字のサーバーIDを指定してください')
        return
    end
    startDiagnosis(tonumber(args[2]))
end

RegisterCommand(Config.Commands.Name, handleCommand, false)

if Config.Target.Enabled then
    exports.ox_target:addGlobalPlayer({
        {
            name = 'ptech_mediora_medical:diagnose',
            icon = Config.Target.Icon,
            label = Config.Target.Label,
            distance = math.min(Config.Target.Distance, Config.Distance),
            canInteract = function(entity)
                return not busy and serverIdFromPed(entity) ~= nil
                    and Medical.allowed(exports.qbx_core:GetPlayerData())
            end,
            onSelect = function(data)
                local target = data and serverIdFromPed(data.entity)
                if target then startDiagnosis(target) end
            end,
        },
        {
            name = 'ptech_mediora_medical:treat',
            icon = 'fa-solid fa-tablets',
            label = '治療する',
            distance = math.min(Config.Target.Distance, Config.Distance),
            canInteract = function(entity)
                return not busy and serverIdFromPed(entity) ~= nil
                    and Medical.allowed(exports.qbx_core:GetPlayerData())
            end,
            onSelect = function(data)
                local target = data and serverIdFromPed(data.entity)
                if not target then return end
                if GetResourceState('ptech_mediora_manager') ~= 'started' then
                    notify('EMSManagerが起動していません')
                    return
                end
                exports.ptech_mediora_manager:openCharts(target)
            end,
        },
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and Config.Target.Enabled then
        exports.ox_target:removeGlobalPlayer('ptech_mediora_medical:diagnose')
        exports.ox_target:removeGlobalPlayer('ptech_mediora_medical:treat')
    end
end)
