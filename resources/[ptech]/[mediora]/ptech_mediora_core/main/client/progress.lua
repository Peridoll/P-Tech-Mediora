local active
local sequence = 0
local ready = false
local styles = { standard = true, slim = true, segmented = true }

RegisterNUICallback('progressReady', function(_, cb)
    ready = true
    cb({ ok = true })
end)

local function clearProgress()
    if not active then return false end
    local id = active.id
    active = nil
    SendNUIMessage({ action = 'progress:hide', id = id })
    return true
end

exports('showProgress', function(options)
    if not ready or type(options) ~= 'table' or type(options.duration) ~= 'number'
        or options.duration ~= options.duration or options.duration <= 0 or options.duration > 3600000
        or type(options.label) ~= 'string' or #options.label == 0 or #options.label > 240 then
        return false
    end

    sequence = sequence + 1
    local id = sequence
    local owner = GetInvokingResource() or GetCurrentResourceName()
    active = { id = id, owner = owner }
    local path = options.template
    local template, templateSvg
    if type(path) == 'string' and path:match('^main/ui/progress/[a-zA-Z0-9_-]+%.svg$') then
        template = ('https://cfx-nui-%s/%s'):format(owner, path)
        if not options.plain then
            local svg = LoadResourceFile(owner, path)
            if svg and #svg <= 32768 and svg:find('--mediora-progress-accent', 1, true) then
                templateSvg = svg
            end
        end
    end
    local style = type(options.style) == 'string' and styles[options.style] and options.style or 'segmented'
    SendNUIMessage({
        action = 'progress:show', id = id, label = options.label, duration = options.duration,
        template = template, templateSvg = templateSvg, plain = options.plain == true, style = style,
        largeMotion = options.largeMotion == true,
    })
    SetTimeout(math.ceil(options.duration) + 250, function()
        if active and active.id == id then clearProgress() end
    end)
    return true, id
end)

exports('hideProgress', function(id)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if not active or active.owner ~= owner or (id ~= nil and active.id ~= id) then return false end
    return clearProgress()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() or (active and resource == active.owner) then clearProgress() end
end)
