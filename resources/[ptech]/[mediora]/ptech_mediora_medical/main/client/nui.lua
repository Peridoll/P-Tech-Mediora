-- カルテ画面は Medical、処置の進捗は起動中の Core に表示する。
function MedicalNuiSend(_, data)
    SendNUIMessage({ action = data.action, data = data.data })
end

MedicalProgress = {}
local P = MedicalProgress
local core = 'ptech_mediora_core'
local active

function P.coreAvailable()
    return GetResourceState(core) == 'started'
end

function P.start(duration, label, mode, tool, motion)
    P.stop(active)
    local progress = {}
    active = progress
    if P.coreAvailable() then
        local ok, shown, id = pcall(function()
            local animations = Config.ProgressAnimations or {}
            local animation = mode or 'examination'
            return exports[core]:showProgress({
                duration = duration, label = label,
                template = animations[motion] or animations[animation], style = Config.ProgressBarStyle,
                largeMotion = animation == 'examination',
            })
        end)
        progress.onCore = ok and shown == true
        progress.id = id
    end
    if not progress.onCore then
        SendNUIMessage({ action = 'exam-progress', duration = duration, label = label, mode = mode, tool = tool })
    end
    return progress
end

function P.stop(progress)
    if not progress or progress ~= active then return end
    active = nil
    if progress.onCore then
        pcall(function() exports[core]:hideProgress(progress.id) end)
    else
        SendNUIMessage({ action = 'exam-progress' })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then P.stop(active) end
end)
