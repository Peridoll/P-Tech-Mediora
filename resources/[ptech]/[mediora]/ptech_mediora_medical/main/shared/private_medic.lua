local Config = Config.PrivateMedic
PrivateMedic = {}
function PrivateMedic.validId(value)
    return type(value)=='number' and value==value and value>0 and value<math.huge and value%1==0
end
function PrivateMedic.allowed(data)
    local job=data and data.job
    return job and Config.Jobs[job.name]==true and (not Config.RequireDuty or job.onduty==true)
end
function PrivateMedic.down(state, metadata, health)
    state,metadata=state or {},metadata or {}
    local dead=state.dead
    return dead==true or dead=='dead' or dead=='laststand' or dead==1 or dead==2
        or state.isDead==true or state.laststand==true or state.inlaststand==true
        or metadata.isdead==true or metadata.inlaststand==true
        or (type(health)=='number' and health<=Config.HealthBase)
end
