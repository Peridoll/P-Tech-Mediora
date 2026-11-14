local downStates = { [true] = true, [1] = true, [2] = true, dead = true, laststand = true }

function Hospital.canWork(data, state)
    local job = data and data.job
    local metadata = data and data.metadata or {}
    return job ~= nil and Hospital.jobs[job.name] == true and job.onduty == true
        and metadata.isdead ~= true and metadata.inlaststand ~= true
        and downStates[state] ~= true
end
