local activeExamination

-- 患者向けの表示だけを更新する。操作権や死亡・負傷状態は変更しない。
RegisterNetEvent('ptech_mediora_medical:examinationStatus', function(active)
    MedicalNuiSend('clinical', { action = 'examination:status', data = { active = active == true } })
end)

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

local function clearExaminationProgress(examination)
    if not examination.progressing then return end
    examination.progressing = false
    SendNUIMessage({ action = 'exam-progress' })
    if examination.animation then
        local animation = examination.animation
        StopAnimTask(examination.ped, animation.dict, animation.clip, 2.0)
    end
    if examination.prop then DeleteEntity(examination.prop) end
end

local function cancelActiveExamination()
    local examination = activeExamination
    activeExamination = nil
    if examination then
        clearExaminationProgress(examination)
        if examination.target then
            TriggerServerEvent('ptech_mediora_medical:cancelExamination', examination.target)
        end
    end
    MedicalNuiSend('clinical', { action = 'examination:status', data = { active = false } })
end

AddEventHandler('QBCore:Client:OnPlayerUnload', cancelActiveExamination)

-- This is the single entrance for commands and ox_target. Never trust this
-- target alone: the server checks permissions, identity and range at each stage.
local function startDiagnosis(target)
    if activeExamination then return end
    local examination = {}
    activeExamination = examination
    local authorizedTarget
    local ok, err = pcall(function()
        if not Medical.allowed(exports.qbx_core:GetPlayerData()) then
            notify('勤務中の医療職のみ利用できます'); return
        end
        if not target then target = nearby() end
        if not target then notify(('%.1fm以内に対象がいません'):format(Config.Distance)); return end
        examination.target = target
        local auth = lib.callback.await('ptech_mediora_medical:inspect', false, target)
        if activeExamination ~= examination then return end
        if not auth or auth.error then notify(auth and auth.error or '診察許可を取得できません'); return end
        authorizedTarget = target

        -- 先に観察し、部位数からサーバーが演出時間を決める。取得失敗を無傷と混同しない。
        local success, injuries = pcall(function()
            return exports.wasabi_ambulance:diagnosePlayer(target)
        end)
        if activeExamination ~= examination then return end
        if Config.Debug then
            print(('[ptech_mediora_medical] serverId=%s success=%s returnType=%s\n%s')
                :format(target, tostring(success), type(injuries), Medical.describe(injuries)))
        end
        local confirm = lib.callback.await('ptech_mediora_medical:confirm', false, target, injuries, success)
        if activeExamination ~= examination then return end
        if not confirm or confirm.error then
            notify(confirm and confirm.error or '診察情報を確認できません'); return
        end
        if Config.Debug then
            print(('[ptech_mediora_medical] serverId=%s examinationDuration=%sms')
                :format(target, tostring(confirm.duration)))
        end

        local ped = PlayerPedId()
        examination.ped = ped
        examination.progressing = true
        SendNUIMessage({ action = 'exam-progress', duration = confirm.duration })
        local deadline = GetGameTimer() + confirm.duration
        local animation = Config.Examination.Animation
        local prop = Config.Examination.Prop
        local model = prop and joaat(prop.model)
        local hasAnimation = animation and DoesAnimDictExist(animation.dict)
        local hasProp = model and IsModelValid(model)
        if hasAnimation then RequestAnimDict(animation.dict) end
        if hasProp then RequestModel(model) end

        local finished = false
        while activeExamination == examination and PlayerPedId() == ped and not IsEntityDead(ped) do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            if IsDisabledControlJustPressed(0, 73) then break end
            if GetGameTimer() >= deadline then
                finished = true
                break
            end
            if hasAnimation and not examination.animation and HasAnimDictLoaded(animation.dict) then
                TaskPlayAnim(ped, animation.dict, animation.clip, 3.0, -3.0, -1, animation.flag or 49, 0.0, false, false, false)
                examination.animation = animation
            end
            if hasProp and not examination.prop and HasModelLoaded(model) then
                local coords = GetEntityCoords(ped)
                local object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
                if object ~= 0 then
                    examination.prop = object
                    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, prop.bone or 60309),
                        prop.pos.x, prop.pos.y, prop.pos.z, prop.rot.x, prop.rot.y, prop.rot.z,
                        true, true, false, true, 1, true)
                end
            end
            Wait(0)
        end
        if hasAnimation then RemoveAnimDict(animation.dict) end
        if hasProp then SetModelAsNoLongerNeeded(model) end
        clearExaminationProgress(examination)
        if activeExamination ~= examination then return end
        if not finished then
            notify('診察を中止しました', 'inform')
            return
        end

        local snapshot = {
            title = '診察 — ID ' .. target, targetId = target, success = success,
            death = confirm.death, injuries = injuries, observedInjuries = confirm.injuries,
            refresh = function() startDiagnosis(target) end,
        }
        -- 保存前の患者・距離確認と、患者側の表示解除はサーバーが行う。
        local chart = lib.callback.await('ptech_mediora_medical:createChart', false, target)
        if activeExamination ~= examination then return end
        if chart and chart.chart then
            if GetResourceState('ptech_mediora_manager') == 'started' then
                local shown, opened = pcall(function()
                    return exports.ptech_mediora_manager:openCharts(target, chart.chart.chartId)
                end)
                if activeExamination ~= examination then return end
                if not shown or opened == false then
                    local displayed = MedicalUI.openCharts(target, chart.chart.chartId)
                    if activeExamination == examination and displayed == false then MedicalUI.show(snapshot) end
                end
            else
                local displayed = MedicalUI.openCharts(target, chart.chart.chartId)
                if activeExamination == examination and displayed == false then MedicalUI.show(snapshot) end
            end
        elseif chart and chart.noChart then
            notify(chart.message or '診察が完了しました。確認できる傷はないようです。', 'inform')
        elseif not chart or chart.error then
            MedicalUI.show(snapshot)
            notify(chart and chart.error or 'カルテを作成できませんでした')
        else
            MedicalUI.show(snapshot)
        end
    end)
    -- 中止・コールバック例外・演出失敗でも、患者向け表示と開始許可を片付ける。
    local current = activeExamination == examination
    clearExaminationProgress(examination)
    if current then
        if authorizedTarget then pcall(cancelExamination, authorizedTarget) end
        if activeExamination == examination then activeExamination = nil end
    end
    if not ok and current then
        print('[ptech_mediora_medical] examination failed: ' .. tostring(err))
        notify('診察に失敗しました。詳細は F8 コンソールを確認してください')
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

-- 仮アイテムは廃止。Logiのアイテムを取り込むまでは空のカタログを返す。
-- EMSManagerの一覧取得口は残すが、Logiへの依存・自動取り込みはまだ追加しない。
exports('getTreatmentItems', function()
    return {}
end)

-- 将来のタブレット等からも、同じ権限確認付きのカルテ画面を開く。
exports('openCharts', function(targetId, chartId)
    return MedicalUI.openCharts(targetId, chartId)
end)

if Config.Target.Enabled then
    exports.ox_target:addGlobalPlayer({
        {
            name = 'ptech_mediora_medical:diagnose',
            icon = Config.Target.Icon,
            label = Config.Target.Label,
            distance = math.min(Config.Target.Distance, Config.Distance),
            canInteract = function(entity)
                return not activeExamination and serverIdFromPed(entity) ~= nil
                    and Medical.allowed(exports.qbx_core:GetPlayerData())
            end,
            onSelect = function(data)
                local target = data and serverIdFromPed(data.entity)
                if target then startDiagnosis(target) end
            end,
        },
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cancelActiveExamination()
    if Config.Target.Enabled then
        exports.ox_target:removeGlobalPlayer('ptech_mediora_medical:diagnose')
    end
end)

