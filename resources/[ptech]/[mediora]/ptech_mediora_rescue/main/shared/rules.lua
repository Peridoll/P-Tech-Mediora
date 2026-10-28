Rescue = {}

-- Wasabi v1の死亡状態とQbox metadataを読み取る。状態の書き換えはしない。
function Rescue.down(state, metadata)
    state = state or {}
    metadata = metadata or {}
    return state.dead == 'dead' or state.dead == 'laststand'
        or metadata.isdead == true or metadata.inlaststand == true
end

function Rescue.allowed(job)
    if not job or job.onduty ~= true then return false end
    for _, name in ipairs(Config.AllowedJobs or {}) do
        if job.name == name then return true end
    end
    return false
end

function Rescue.remaining(started, now)
    if type(started) ~= 'number' then return nil end
    return math.max(0, (Config.Countdown * 1000) - math.max(0, now - started))
end
