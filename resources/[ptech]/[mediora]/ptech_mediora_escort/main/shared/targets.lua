EscortRules = {}
function EscortRules.style(id)
    for _,style in ipairs(Config.CarryModes.walk) do
        if style.id==id then return style end
    end
    return Config.CarryModes.walk[1]
end
function EscortRules.downOrDead(state,metadata,health)
    metadata=metadata or {}
    local dead=state.dead
    return dead==true or dead=='dead' or dead=='laststand' or dead==1 or dead==2
        or metadata.isdead==true or metadata.inlaststand==true or (health~=nil and health<=0)
end
function EscortRules.eligible(state,metadata,health)
    if EscortRules.downOrDead(state,metadata,health) then return true end
    if state.ptechEscortAccept==true then return true end
    for _,key in ipairs(Config.CarryableTags) do if state[key]==true then return true end end
    return false
end
function EscortRules.allowedStyle(denied,id)
    return not denied or not denied[id]
end
