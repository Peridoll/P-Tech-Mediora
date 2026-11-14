local namespace = 'ptech_mediora_hospital:'
local zones = {}
local current

local function onDuty()
    return Hospital.canWork(QBX.PlayerData, LocalPlayer.state.dead)
        and not IsEntityDead(PlayerPedId())
end

local function cancelWork()
    if not current or current.phase == 'finishing' then return false end
    current.cancelled = true
    return true
end

RegisterCommand('hospitalcancel', cancelWork, false)
exports('CancelWork', cancelWork)

local function performWork(job, task, activity)
    if job.cancelled or not onDuty() or lib.progressActive() then return false end
    local shown, progressId = exports.ptech_mediora_core:showProgress({
        duration = Hospital.duration,
        label = activity.label .. '（Xで中断）',
    })
    if not shown then
        lib.notify({ type = 'error', description = '進行表示の準備ができていません。もう一度お試しください。' })
        return false
    end
    job.progressId = progressId
    job.phase = 'working'
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, activity.scenario, 0, true)
    local startedAt = GetGameTimer()
    while not job.cancelled do
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 23, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 44, true)
        DisablePlayerFiring(PlayerId(), true)
        if not onDuty() or IsPedInAnyVehicle(ped, false) or lib.progressActive()
            or #(GetEntityCoords(ped) - task.coords) > Hospital.interactionDistance + 0.75
            or IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73)
            or GetResourceState('ptech_mediora_core') ~= 'started' then
            job.cancelled = true
        end
        if job.cancelled or GetGameTimer() - startedAt >= Hospital.duration then break end
        Wait(0)
    end
    return not job.cancelled
end

local function work(task, activity)
    if current or not onDuty() or lib.progressActive() then return end
    local job = { phase = 'starting' }
    current = job
    local connected, token = pcall(lib.callback.await, namespace .. 'start', false, task.id)
    if not connected or not token then
        current = nil
        lib.notify({ type = 'error', description = 'この作業を開始できませんでした。' })
        return
    end
    job.id = task.id
    job.token = token

    local worked, completed = pcall(performWork, job, task, activity)
    if job.progressId then
        pcall(function() exports.ptech_mediora_core:hideProgress(job.progressId) end)
        ClearPedTasks(PlayerPedId())
    end
    if worked and completed and not job.cancelled then
        job.phase = 'finishing'
        local responded, rewarded = pcall(lib.callback.await, namespace .. 'finish', false, task.id, token)
        lib.notify({
            type = responded and rewarded and 'success' or 'error',
            description = responded and rewarded and ('作業完了。Mediora Points +%d'):format(Hospital.points)
                or '作業を完了できませんでした。',
        })
    else
        TriggerServerEvent(namespace .. 'cancel', task.id, token)
    end
    current = nil
end

local function syncTasks(tasks)
    local seen = {}
    for _, task in ipairs(tasks) do
        seen[task.id] = true
        local zone = zones[task.id]
        if zone then
            zone.available = task.available
        else
            local activity = Hospital.activities[task.activity]
            zone = { available = task.available }
            zone.id = exports.ox_target:addSphereZone({
                coords = task.coords,
                radius = 0.6,
                options = {{
                    name = namespace .. task.id,
                    label = activity.label,
                    icon = 'fa-solid fa-clipboard-check',
                    distance = Hospital.interactionDistance,
                    canInteract = function()
                        return zone.available and not current and onDuty()
                    end,
                    onSelect = function() work(task, activity) end,
                }},
            })
            zones[task.id] = zone
        end
    end
    for id, zone in pairs(zones) do
        if not seen[id] then
            exports.ox_target:removeZone(zone.id)
            zones[id] = nil
        end
    end
end

CreateThread(function()
    while true do
        if onDuty() then
            local ok, tasks = pcall(lib.callback.await, namespace .. 'list', false)
            if ok then syncTasks(onDuty() and tasks or {}) end
        else
            cancelWork()
            syncTasks({})
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cancelWork()
    if current and current.token and current.phase ~= 'finishing' then
        TriggerServerEvent(namespace .. 'cancel', current.id, current.token)
    end
    if current and current.progressId then
        pcall(function() exports.ptech_mediora_core:hideProgress(current.progressId) end)
        ClearPedTasks(PlayerPedId())
    end
    syncTasks({})
end)
