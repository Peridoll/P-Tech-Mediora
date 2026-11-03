local active = {} -- [carrier] = { target, style, ticket }
local held = {} -- [target] = carrier
local vehicleBound = {} -- [target] = { vehicle, seat }
local prefs = {} -- [citizenid] = { style, denied }
local npcRegistry = {} -- [netId] = invokingResource
local ticket = 0

local function playerData(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p and p.PlayerData or nil
end
local function cid(src)
    local data = playerData(src)
    return data and data.citizenid
end
local function preference(src)
    local id = cid(src)
    if not id then return nil end
    if not prefs[id] then
        local raw = GetResourceKvpString('character_'..id)
        local parsed = raw and json.decode(raw) or nil
        prefs[id] = type(parsed)=='table' and parsed or {style=Config.DefaultStyle,denied={}}
        if type(prefs[id].denied)~='table' then prefs[id].denied={} end
    end
    return prefs[id]
end
local function save(src)
    local id = cid(src)
    if id and prefs[id] then SetResourceKvp('character_'..id, json.encode(prefs[id])) end
end
local function notify(src, text, kind)
    TriggerClientEvent('ox_lib:notify',src,{description=text,type=kind or 'error'})
end
local function living(src)
    local ped = GetPlayerPed(src)
    if ped==0 or not DoesEntityExist(ped) then return false end
    local data=playerData(src)
    return not EscortRules.downOrDead(Player(src).state,data and data.metadata,GetEntityHealth(ped))
end
local function ems(src)
    local d=playerData(src)
    local j=d and d.job
    if not j or (Config.RequireDuty and j.onduty~=true) then return false end
    for _,name in ipairs(Config.EMSJobs) do if name==j.name then return true end end
    return false
end
local function isPD(src)
    local d=playerData(src); local j=d and d.job
    for _,name in ipairs(Config.PDJobs) do if j and j.name==name then return true end end
    return false
end
local function validPed(src)
    return GetPlayerPing(src)>0 and GetPlayerPed(src)~=0
end
local function sameBucket(a,b)
    return GetPlayerRoutingBucket(a)==GetPlayerRoutingBucket(b)
end
local function nearPed(a,b,range)
    return #(GetEntityCoords(GetPlayerPed(a))-GetEntityCoords(GetPlayerPed(b)))<=range
end
local function sendPreferences(src)
    local p=preference(src)
    if p then TriggerClientEvent('ptech_mediora_escort:client:preferences',src,p.style,p.denied) end
end
RegisterNetEvent('ptech_mediora_escort:server:preferences',function() sendPreferences(source) end)
RegisterNetEvent('ptech_mediora_escort:server:style',function(id)
    local p=preference(source)
    if not p or type(id)~='string' or #id>50 then return end
    for _,style in ipairs(Config.CarryModes.walk) do
        if style.id==id then p.style=id; save(source); sendPreferences(source); return end
    end
end)
RegisterNetEvent('ptech_mediora_escort:server:toggleDenied',function(id)
    local p=preference(source)
    if not p or type(id)~='string' then return end
    for _,style in ipairs(Config.CarryModes.walk) do
        if style.id==id then
            p.denied[id]=not p.denied[id] or nil
            save(source); sendPreferences(source); return
        end
    end
end)
RegisterNetEvent('ptech_mediora_escort:server:accept',function(enabled)
    local src=source
    if type(enabled)~='boolean' or not validPed(src) then return end
    if enabled and (not living(src) or held[src] or active[src] or GetVehiclePedIsIn(GetPlayerPed(src),false)~=0) then return end
    Player(src).state:set('ptechEscortAccept',enabled or nil,true)
end)
local function release(carrier)
    local rec=active[carrier]
    if not rec then return end
    active[carrier]=nil
    held[rec.target]=nil
    if validPed(rec.target) then
        Player(rec.target).state:set('emsEscortedBy',nil,true)
        TriggerClientEvent('ptech_mediora_escort:client:released',rec.target,rec.ticket)
    end
    if validPed(carrier) then
        Player(carrier).state:set('emsEscorting',nil,true)
        TriggerClientEvent('ptech_mediora_escort:client:removeTarget',carrier,rec.target,rec.ticket)
    end
end
local function start(carrier,target,fromVehicle)
    target=tonumber(target)
    if not target or target==carrier or not validPed(carrier) or not validPed(target) or active[carrier] or held[target] or active[target] or held[carrier] then return end
    if not living(carrier) or not sameBucket(carrier,target) or not nearPed(carrier,target,fromVehicle and Config.TargetDistance+2 or Config.NormalRange) then return end
    if GetVehiclePedIsIn(GetPlayerPed(carrier),false)~=0 then return end
    local ped=GetPlayerPed(target)
    local data=playerData(target)
    if not EscortRules.eligible(Player(target).state,data and data.metadata,GetEntityHealth(ped)) then return end
    if GetVehiclePedIsIn(ped,false)~=0 and not fromVehicle then return end
    for _,key in ipairs(Config.ExternalBusyKeys) do
        if Player(carrier).state[key] or Player(target).state[key] then return end
    end
    local cp=preference(carrier)
    local tp=preference(target)
    local chosen=cp and cp.style or Config.DefaultStyle
    if tp and tp.denied[chosen] then chosen=Config.DefaultStyle end
    ticket=ticket+1
    local t=ticket
    active[carrier]={target=target,style=chosen,ticket=t}
    held[target]=carrier
    Player(carrier).state:set('emsEscorting',target,true)
    Player(target).state:set('emsEscortedBy',carrier,true)
    Player(target).state:set('ptechEscortAccept',nil,true)
    TriggerClientEvent('ptech_mediora_escort:client:addTarget',carrier,target,chosen,t)
    TriggerClientEvent('ptech_mediora_escort:client:getEscorted',target,carrier,chosen,t)
end
RegisterNetEvent('ptech_mediora_escort:server:start',function(target) start(source,target,false) end)
RegisterNetEvent('ptech_mediora_escort:server:stop',function()
    release(source)
end)
RegisterNetEvent('ptech_mediora_escort:server:escape',function()
    local src=source;local carrier=held[src]
    if carrier and living(src) then release(carrier) end
end)
local function veh(netId)
    if type(netId)~='number' or netId<1 or netId>65535 then return 0 end
    local entity=NetworkGetEntityFromNetworkId(netId)
    return entity and entity~=0 and DoesEntityExist(entity) and GetEntityType(entity)==2 and entity or 0
end
local function stopped(entity)
    return GetEntitySpeed(entity)<=Config.VehicleStopSpeed
end
local function verifyVehicle(src,vehicle)
    return vehicle~=0 and GetEntityRoutingBucket(vehicle)==GetPlayerRoutingBucket(src)
        and #(GetEntityCoords(GetPlayerPed(src))-GetEntityCoords(vehicle))<=Config.TargetDistance+2
end
-- 操作開始から約1秒後に再確認してコミット。動いた車両/失踪した操作者は移動させない。
RegisterNetEvent('ptech_mediora_escort:server:putInVehicle',function(netId,seat)
    local src=source;local rec=active[src];local vehicle=veh(netId)
    if not rec or not living(src) or not verifyVehicle(src,vehicle) or not stopped(vehicle) then return end
    if type(seat)~='number' or seat%1~=0 or seat<0 or seat>=GetVehicleMaxNumberOfPassengers(vehicle) then return end
    if GetPedInVehicleSeat(vehicle,seat)~=0 then notify(src,Config.Text.noSeat);return end
    local t=rec.ticket
    TriggerClientEvent('ptech_mediora_escort:client:doorAction',src,netId,seat,'put',Config.VehicleTransferMs)
    Wait(Config.VehicleTransferMs)
    if not active[src] or active[src].ticket~=t or not living(src) or not validPed(rec.target)
        or not verifyVehicle(src,vehicle) or not stopped(vehicle)
        or GetPedInVehicleSeat(vehicle,seat)~=0 or GetVehiclePedIsIn(GetPlayerPed(rec.target),false)~=0 then
        notify(src,Config.Text.cancelled);return
    end
    release(src)
    vehicleBound[rec.target]={vehicle=vehicle,seat=seat}
    TriggerClientEvent('ptech_mediora_escort:client:seat',rec.target,netId,seat)
end)
RegisterNetEvent('ptech_mediora_escort:server:takeOut',function(netId,target)
    local src=source;local vehicle=veh(netId);target=tonumber(target)
    if not target or not validPed(target) or not living(src) or active[src] or held[src]
        or not verifyVehicle(src,vehicle) or not stopped(vehicle) then return end
    local patient=GetPlayerPed(target)
    if GetVehiclePedIsIn(patient,false)~=vehicle then return end
    local seat=nil
    for s=0,GetVehicleMaxNumberOfPassengers(vehicle)-1 do if GetPedInVehicleSeat(vehicle,s)==patient then seat=s;break end end
    if seat==nil then return end
    local state=Player(target).state;local data=playerData(target)
    if not EscortRules.eligible(state,data and data.metadata,GetEntityHealth(patient)) then return end
    TriggerClientEvent('ptech_mediora_escort:client:doorAction',src,netId,seat,'take',Config.VehicleTransferMs)
    Wait(Config.VehicleTransferMs)
    if not living(src) or not validPed(target) or GetVehiclePedIsIn(patient,false)~=vehicle
        or not verifyVehicle(src,vehicle) or not stopped(vehicle) then notify(src,Config.Text.cancelled);return end
    start(src,target,true)
    vehicleBound[target]=nil
end)
-- EMS車内からの近隣ダウン患者回収。運転席のみ。座席に空きがある時は後部/助手席に配置。
RegisterNetEvent('ptech_mediora_escort:server:emsPickup',function()
    local src=source;if not ems(src) or not living(src) then return end
    local ped=GetPlayerPed(src);local vehicle=GetVehiclePedIsIn(ped,false)
    if vehicle==0 or GetPedInVehicleSeat(vehicle,-1)~=ped or not stopped(vehicle) then return end
    local free={}
    for s=0,GetVehicleMaxNumberOfPassengers(vehicle)-1 do
        if GetPedInVehicleSeat(vehicle,s)==0 then free[#free+1]=s end
    end
    if #free==0 then notify(src,Config.Text.noSeat);return end
    local patients={}
    for _,id in ipairs(GetPlayers()) do
        local target=tonumber(id)
        if target~=src and validPed(target) and sameBucket(src,target) and not held[target] and not active[target]
            and GetVehiclePedIsIn(GetPlayerPed(target),false)==0
            and nearPed(src,target,Config.VehicleRange) then
            local data=playerData(target)
            if EscortRules.downOrDead(Player(target).state,data and data.metadata,GetEntityHealth(GetPlayerPed(target))) then
                patients[#patients+1]={id=target,dist=#(GetEntityCoords(ped)-GetEntityCoords(GetPlayerPed(target))),pd=isPD(target)}
            end
        end
    end
    table.sort(patients,function(a,b) return a.dist<b.dist end)
    local pdOnly=false
    for _,p in ipairs(patients) do if p.pd then pdOnly=true;break end end
    local n=0
    for _,p in ipairs(patients) do
        if n>=#free then break end
        if not pdOnly or p.pd then
            n=n+1
            local seat=free[n]
            vehicleBound[p.id]={vehicle=vehicle,seat=seat}
            TriggerClientEvent('ptech_mediora_escort:client:seat',p.id,NetworkGetNetworkIdFromEntity(vehicle),seat)
        end
    end
end)
-- Dead/Down targets remain attached even if tags clear; healthy consent expires on lift.
CreateThread(function()
    while true do
        Wait(750)
        for carrier,rec in pairs(active) do
            if not validPed(carrier) or not validPed(rec.target) or not living(carrier)
                or not sameBucket(carrier,rec.target)
                or not nearPed(carrier,rec.target,Config.BreakDistance) then release(carrier)
            end
        end
        for target,rec in pairs(vehicleBound) do
            if not validPed(target) or not DoesEntityExist(rec.vehicle) then
                vehicleBound[target]=nil
                if validPed(target) then TriggerClientEvent('ptech_mediora_escort:client:seatGone',target) end
            end
        end
    end
end)
AddEventHandler('playerDropped',function()
    local src=source
    if active[src] then release(src) end
    if held[src] then release(held[src]) end
    vehicleBound[src]=nil
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for src in pairs(active) do release(src) end
end)
