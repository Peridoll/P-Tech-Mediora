Marine = {}

function Marine.finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

function Marine.validId(value)
    return Marine.finite(value) and value > 0 and value % 1 == 0
end

-- Wasabi v1 の dead/laststand と Qbox metadata。医療状態は変更しない。
function Marine.down(state, metadata)
    metadata = metadata or {}
    return state.dead == 'dead' or state.dead == 'laststand'
        or metadata.isdead == true or metadata.inlaststand == true
end

function Marine.busy(state)
    return state.emsEscortedBy ~= nil and state.emsEscortedBy ~= false
        or state.emsVehicleBy ~= nil and state.emsVehicleBy ~= false
end

function Marine.finsAllowed(job)
    if not job or job.onduty ~= true then return false end
    for _, name in ipairs(Config.Fins.Jobs) do
        if job.name == name then return true end
    end
    return false
end

function Marine.validSurface(coords, observation)
    if type(observation) ~= 'table' or observation.water ~= true then return false end
    for _, key in ipairs({ 'x', 'y', 'z', 'surface' }) do
        if not Marine.finite(observation[key]) then return false end
    end
    local dx, dy, dz = coords.x - observation.x, coords.y - observation.y, coords.z - observation.z
    return dx * dx + dy * dy + dz * dz <= Config.Flotation.ObservationTolerance ^ 2
        and observation.surface >= coords.z - Config.Flotation.SurfaceTolerance
        and observation.surface - coords.z <= Config.Flotation.MaxDepth
end
