local selectedStyle=Config.DefaultStyle
local denied={}
local accepting=false
local carriedBy=nil
local carriedTicket=nil
local carrying=nil
local currentStyle=nil
local busyTransfer=false
local pendingMenu=false
local activeAnimation=nil
local lastInVehicle=false

local function notify(msg,kind)
    lib.notify({description=msg,type=kind or 'error'})
end
local function pedOf(sid)
    local idx=GetPlayerFromServerId(sid)
    return idx~=-1 and GetPlayerPed(idx) or 0
end
local function data()
    local ok,p=pcall(function() return exports.qbx_core:GetPlayerData() end)
    return ok and p or nil
end
local function down(ped)
    if not ped or ped==0 then return false end
    local meta=data()
    return EscortRules.downOrDead(LocalPlayer.state,meta and meta.metadata,GetEntityHealth(ped))
end
local function canCarryMe()
    return EscortRules.eligible(LocalPlayer.state,data() and data().metadata,GetEntityHealth(cache.ped))
end
local function ems()
    local d=data();local j=d and d.job
    if not j or (Config.RequireDuty and not j.onduty) then return false end
    for _,name in ipairs(Config.EMSJobs) do if j.name==name then return true end end
    return false
end
local function loadAnim(dict)
    if not dict or dict=='' then return false end
    RequestAnimDict(dict)
    local limit=GetGameTimer()+2000
    while not HasAnimDictLoaded(dict) and GetGameTimer()<limit do Wait(0) end
    return HasAnimDictLoaded(dict)
end
local function stopAnim()
    if activeAnimation then
        StopAnimTask(cache.ped,activeAnimation.dict,activeAnimation.anim,1.0)
        activeAnimation=nil
    end
end
local function play(anim)
    local ped,carrySession,passengerTicket=cache.ped,carrying,carriedTicket
    if not anim or not loadAnim(anim.dict) then return end
    if cache.ped~=ped or carrying~=carrySession or carriedTicket~=passengerTicket then return end
    TaskPlayAnim(ped,anim.dict,anim.anim,8.0,-8.0,-1,anim.flag or 49,0,false,false,false)
    activeAnimation=anim
end
local function isPlaying(anim)
    return anim and IsEntityPlayingAnim(cache.ped,anim.dict,anim.anim,3)
end
local function clearAcceptance()
    if not accepting then return end
    accepting=false
    StopAnimTask(cache.ped,'missfam5_yoga','a2_pose',1.0)
    TriggerServerEvent('ptech_mediora_escort:server:accept',false)
end
local function toggleAccept()
    if accepting then clearAcceptance();return end
    if down(cache.ped) or carriedBy or IsPedInAnyVehicle(cache.ped,false) then return end
    accepting=true
    TriggerServerEvent('ptech_mediora_escort:server:accept',true)
    -- 上半身のみの待機姿勢。歩く・走る操作は維持。
    if loadAnim('missfam5_yoga') then TaskPlayAnim(cache.ped,'missfam5_yoga','a2_pose',8.0,-8.0,-1,49,0,false,false,false) end
end
local function vehicleStyle(s,v)
    if v~=0 and (s.vehicleAllowed==false
        or (s.vehicleAllowed=='bike' and not IsThisModelABike(GetEntityModel(v)))) then
        return EscortRules.style(Config.DefaultStyle)
    end
    return s
end
local function styleNow()
    local s=EscortRules.style(currentStyle or selectedStyle)
    local v=GetVehiclePedIsIn(cache.ped,false)
    return vehicleStyle(s,v)
end
local function applyCarryAnimation(replay)
    if not carrying then return end
    local ped=cache.ped
    if IsPedRagdoll(ped) or IsPedGettingUp(ped) or IsPedClimbing(ped) or IsPedVaulting(ped) then return end
    local s=styleNow()
    local v=GetVehiclePedIsIn(ped,false)
    if s.id=='fireman' and v~=0 and IsThisModelABike(GetEntityModel(v)) then return end
    if replay or not activeAnimation or activeAnimation.anim~=s.escorter.anim or activeAnimation.dict~=s.escorter.dict then
        stopAnim();play(s.escorter)
    elseif not isPlaying(activeAnimation) then
        play(s.escorter)
    end
end
local takeNearbyPatient, putInNearbyKeyedVehicle
local function startKey()
    if busyTransfer then return end
    if carrying then
        if not putInNearbyKeyedVehicle() then TriggerServerEvent('ptech_mediora_escort:server:stop') end
        return
    end
    if carriedBy then return end
    if IsPedInAnyVehicle(cache.ped,false) then
        if ems() then
            local vehicle=GetVehiclePedIsIn(cache.ped,false)
            TriggerServerEvent('ptech_mediora_escort:server:emsPickup',NetworkGetNetworkIdFromEntity(vehicle),GetVehicleMaxNumberOfPassengers(vehicle))
        end
        return
    end
    local nearest=nil;local dist=Config.NormalRange
    for _,id in ipairs(GetActivePlayers()) do
        if id~=PlayerId() then
            local ped=GetPlayerPed(id)
            local sid=GetPlayerServerId(id)
            local n=#(GetEntityCoords(cache.ped)-GetEntityCoords(ped))
            if n<dist and not IsPedInAnyVehicle(ped,false) and EscortRules.eligible(Player(sid).state,nil,GetEntityHealth(ped))
                and not Player(sid).state.emsEscortedBy then dist=n;nearest=sid end
        end
    end
    if nearest then TriggerServerEvent('ptech_mediora_escort:server:start',nearest);return end
    takeNearbyPatient()
end
lib.addKeybind({name='ptech_mediora_escort',description='担ぐ / 降ろす',defaultKey=Config.Key,onPressed=startKey})

local showCarryMenu, showDeniedMenu
showCarryMenu = function()
    local options={}
    for _,style in ipairs(Config.CarryModes.walk) do
        local id=style.id
        options[#options+1]={title=style.label,description=id==selectedStyle and '✓ 選択中' or '選択する',
            onSelect=function()
                selectedStyle=id
                TriggerServerEvent('ptech_mediora_escort:server:style',id)
            end}
    end
    lib.registerContext({id='ptech_escort_carry',title='担ぎ方',menu='ptech_escort_settings',options=options})
    lib.showContext('ptech_escort_carry')
end
showDeniedMenu = function()
    local options={}
    for _,style in ipairs(Config.CarryModes.walk) do
        local id=style.id
        options[#options+1]={title=style.label,description=denied[id] and '✕ NG' or '✓ 許可',
            onSelect=function()
                denied[id]=not denied[id] or nil
                TriggerServerEvent('ptech_mediora_escort:server:toggleDenied',id)
            end}
    end
    lib.registerContext({id='ptech_escort_denied',title='担がれ方',menu='ptech_escort_settings',options=options})
    lib.showContext('ptech_escort_denied')
end
local function showSettings()
    lib.registerContext({id='ptech_escort_settings',title='搬送設定',options={
        {title='担ぎ方',description='次回の搬送から反映',onSelect=showCarryMenu},
        {title='担がれ方',description='スタイルごとに許可 / NGを切替',onSelect=showDeniedMenu},
    }})
    lib.showContext('ptech_escort_settings')
end
local function setupRadial()
    if not lib.registerRadial then return end
    lib.registerRadial({id='ptech_escort_actions',items={
        {label='担ぐ / 降ろす',icon='people-carry',onSelect=startKey},
        {label='受け入れる',icon='hands-helping',onSelect=toggleAccept},
        {label='設定',icon='cog',onSelect=showSettings},
    }})
    pcall(lib.removeRadialItem,'medioraEscortCitizen')
    pcall(lib.removeRadialItem,'ptechEscortCitizen')
    pcall(lib.addRadialItem,{id='ptechEscortCitizen',label='搬送',icon='people-carry',menu='ptech_escort_actions'})
end
RegisterNetEvent('ptech_mediora_escort:client:preferences',function(style,rejected)
    selectedStyle=type(style)=='string' and style or Config.DefaultStyle
    denied=type(rejected)=='table' and rejected or {}
end)
RegisterNetEvent('ptech_mediora_escort:client:addTarget',function(target,style,ticket)
    carrying={target=target,ticket=ticket}
    currentStyle=style
    applyCarryAnimation()
end)
RegisterNetEvent('ptech_mediora_escort:client:removeTarget',function(target,ticket)
    if carrying and carrying.target==target and carrying.ticket==ticket then
        carrying=nil;currentStyle=nil;stopAnim()
    end
end)
local function attachTo(owner,style)
    local s=EscortRules.style(style)
    s=vehicleStyle(s,GetVehiclePedIsIn(owner,false))
    local bone=(s.bone and s.bone~=-1) and GetPedBoneIndex(owner,s.bone) or -1
    local p=s.pos or {0.27,0.15,0.63};local r=s.rot or {0,0,180}
    AttachEntityToEntity(cache.ped,owner,bone,p[1],p[2],p[3],r[1],r[2],r[3],false,false,false,true,2,true)
    local anim=s.target
    if anim and down(cache.ped) then
        anim={dict=anim.dict,anim=anim.anim,flag=(anim.flag or 49) | 32}
    end
    play(anim)
end
RegisterNetEvent('ptech_mediora_escort:client:getEscorted',function(owner,style,ticket,fromVehicle)
    clearAcceptance()
    carriedBy=owner;carriedTicket=ticket
    local inVehicle=IsPedInAnyVehicle(cache.ped,false)
    local restoreAfterExit=fromVehicle or inVehicle
    if inVehicle then TaskLeaveVehicle(cache.ped,GetVehiclePedIsIn(cache.ped,false),16) end
    CreateThread(function()
        local priorMode=nil
        while carriedBy==owner and carriedTicket==ticket do
            local escorter=pedOf(owner)
            if escorter~=0 and DoesEntityExist(escorter) and not IsPedInAnyVehicle(cache.ped,false) then
                local mode=GetVehiclePedIsIn(escorter,false)~=0 and 'vehicle' or 'walk'
                if priorMode~=mode or not IsEntityAttachedToEntity(cache.ped,escorter) then
                    stopAnim();attachTo(escorter,style);priorMode=mode
                elseif not isPlaying(activeAnimation) and not IsPedRagdoll(cache.ped) then
                    if restoreAfterExit then
                        restoreAfterExit=false
                        DetachEntity(cache.ped,true,true)
                        stopAnim()
                        Wait(0)
                        if carriedBy==owner and carriedTicket==ticket and DoesEntityExist(escorter) then
                            attachTo(escorter,style)
                        end
                    elseif activeAnimation then
                        play(activeAnimation)
                    else
                        attachTo(escorter,style)
                    end
                end
            end
            Wait(Config.SyncInterval)
        end
    end)
end)
RegisterNetEvent('ptech_mediora_escort:client:released',function(ticket)
    if carriedTicket and carriedTicket~=ticket then return end
    carriedBy=nil;carriedTicket=nil
    if IsEntityAttached(cache.ped) then DetachEntity(cache.ped,true,true) end
    stopAnim()
end)
local function doorIndex(seat)
    if seat==0 then return 1 end
    if seat==1 then return 2 end
    if seat==2 then return 3 end
    return nil
end
RegisterNetEvent('ptech_mediora_escort:client:doorAction',function(netId,seat,action,ms)
    local vehicle=NetworkGetEntityFromNetworkId(netId)
    if vehicle==0 then return end
    busyTransfer=true
    local door=doorIndex(seat)
    if door~=nil and GetIsDoorValid(vehicle,door) then SetVehicleDoorOpen(vehicle,door,false,false) end
    CreateThread(function()
        local start=GetGameTimer()
        while GetGameTimer()-start<ms do
            DisableControlAction(0,24,true);DisableControlAction(0,25,true)
            DisableControlAction(0,30,true);DisableControlAction(0,31,true)
            DisableControlAction(0,75,true)
            Wait(0)
        end
        if DoesEntityExist(vehicle) and door~=nil and GetIsDoorValid(vehicle,door) then
            SetVehicleDoorShut(vehicle,door,false)
        end
        busyTransfer=false
    end)
end)
RegisterNetEvent('ptech_mediora_escort:client:seat',function(netId,seat)
    local vehicle=NetworkGetEntityFromNetworkId(netId)
    if vehicle==0 or not DoesEntityExist(vehicle) then return end
    if seat<0 or seat>=GetVehicleMaxNumberOfPassengers(vehicle) or not IsVehicleSeatFree(vehicle,seat) then return end
    if IsEntityAttached(cache.ped) then DetachEntity(cache.ped,true,true) end
    carriedBy=nil;carriedTicket=nil;stopAnim()
    SetPedIntoVehicle(cache.ped,vehicle,seat)
end)
RegisterNetEvent('ptech_mediora_escort:client:seatGone',function()
    if carriedBy or IsPedInAnyVehicle(cache.ped,false) then return end
    ClearPedTasks(cache.ped)
end)
local function seatPos(vehicle,seat)
    local bone=seat==0 and 'seat_pside_f' or ('seat_dside_r')
    if seat==2 then bone='seat_pside_r' end
    local b=GetEntityBoneIndexByName(vehicle,bone)
    return b~=-1 and GetWorldPositionOfEntityBone(vehicle,b) or GetEntityCoords(vehicle)
end
local function freeSeat(vehicle)
    local pos=GetEntityCoords(cache.ped)
    local best=nil;local dist=math.huge
    for seat=0,GetVehicleMaxNumberOfPassengers(vehicle)-1 do
        if IsVehicleSeatFree(vehicle,seat) then
            local d=#(pos-seatPos(vehicle,seat))
            if d<dist then best=seat;dist=d end
        end
    end
    return best
end
putInNearbyKeyedVehicle = function()
    if IsPedInAnyVehicle(cache.ped,false) or GetResourceState('qbx_vehiclekeys')~='started' then return false end
    local pos=GetEntityCoords(cache.ped)
    local nearest,seat
    local dist=Config.TargetDistance
    for _,vehicle in ipairs(GetGamePool('CVehicle')) do
        local d=#(pos-GetEntityCoords(vehicle))
        if d<dist and NetworkGetEntityIsNetworked(vehicle) and GetEntitySpeed(vehicle)<=Config.VehicleStopSpeed
            and exports.qbx_vehiclekeys:HasKeys(vehicle) then
            local index=freeSeat(vehicle)
            if index then nearest,seat,dist=vehicle,index,d end
        end
    end
    if not nearest then return false end
    TriggerServerEvent('ptech_mediora_escort:server:putInVehicle',NetworkGetNetworkIdFromEntity(nearest),seat,'key')
    return true
end
local function patientSeat(vehicle)
    local pos=GetEntityCoords(cache.ped)
    local best,bestSeat;local dist=math.huge
    for seat=0,GetVehicleMaxNumberOfPassengers(vehicle)-1 do
        local ped=GetPedInVehicleSeat(vehicle,seat)
        if ped~=0 and IsPedAPlayer(ped) then
            local sid=GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
            if EscortRules.eligible(Player(sid).state,nil,GetEntityHealth(ped)) then
                local d=#(pos-seatPos(vehicle,seat))
                if d<dist then best=sid;bestSeat=seat;dist=d end
            end
        end
    end
    return best,bestSeat,dist
end
takeNearbyPatient = function()
    local pos=GetEntityCoords(cache.ped)
    local nearest,target,seat
    local dist=Config.TargetDistance
    for _,vehicle in ipairs(GetGamePool('CVehicle')) do
        if #(pos-GetEntityCoords(vehicle))<=Config.TargetDistance+2 and GetEntitySpeed(vehicle)<=Config.VehicleStopSpeed then
            local sid,patientIndex,d=patientSeat(vehicle)
            if sid then
                local min=GetModelDimensions(GetEntityModel(vehicle))
                local rear=GetOffsetFromEntityInWorldCoords(vehicle,0.0,min.y,0.0)
                d=math.min(d,#(pos-rear))
                if d<dist then nearest,target,seat,dist=vehicle,sid,patientIndex,d end
            end
        end
    end
    if nearest then
        TriggerServerEvent('ptech_mediora_escort:server:takeOut',NetworkGetNetworkIdFromEntity(nearest),target,seat)
    end
end
if Config.UseTarget then
    exports.ox_target:addGlobalPlayer({
        {name='ptech_escort_carry',label='担ぐ',icon='fa-solid fa-hand',distance=Config.NormalRange,
            canInteract=function(entity)
                if carrying or carriedBy then return false end
                local idx=NetworkGetPlayerIndexFromPed(entity)
                if idx==-1 then return false end
                local sid=GetPlayerServerId(idx)
                return EscortRules.eligible(Player(sid).state,nil,GetEntityHealth(entity))
                    and not Player(sid).state.emsEscortedBy
            end,
            onSelect=function(data)
                local idx=NetworkGetPlayerIndexFromPed(data.entity)
                if idx~=-1 then TriggerServerEvent('ptech_mediora_escort:server:start',GetPlayerServerId(idx)) end
            end},
    })
    exports.ox_target:addGlobalVehicle({
        {name='ptech_escort_put',label='患者を乗せる',icon='fa-solid fa-car',distance=Config.TargetDistance,
            canInteract=function(vehicle)
                return carrying~=nil and not busyTransfer and not IsPedInAnyVehicle(cache.ped,false)
                    and GetEntitySpeed(vehicle)<=Config.VehicleStopSpeed
            end,
            onSelect=function(data)
                local vehicle=data.entity;local seat=freeSeat(vehicle)
                if seat==nil then notify(Config.Text.noSeat);return end
                TriggerServerEvent('ptech_mediora_escort:server:putInVehicle',NetworkGetNetworkIdFromEntity(vehicle),seat)
            end},
        {name='ptech_escort_take',label='患者を降ろす',icon='fa-solid fa-person-walking-arrow-right',distance=Config.TargetDistance,
            canInteract=function(vehicle)
                return not carrying and not carriedBy and not busyTransfer
                    and not IsPedInAnyVehicle(cache.ped,false)
                    and GetEntitySpeed(vehicle)<=Config.VehicleStopSpeed and patientSeat(vehicle)~=nil
            end,
            onSelect=function(data)
                local sid,seat=patientSeat(data.entity)
                if sid then TriggerServerEvent('ptech_mediora_escort:server:takeOut',NetworkGetNetworkIdFromEntity(data.entity),sid,seat) end
            end},
    })
end
CreateThread(function()
    while true do
        Wait(100)
        if accepting then
            local ped=cache.ped
            if down(ped) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
                or IsPedInAnyVehicle(ped,false) or IsPedJumping(ped) or IsPedClimbing(ped)
                or IsPedVaulting(ped) or IsPedInMeleeCombat(ped) or IsPedShooting(ped)
                or IsPlayerFreeAiming(PlayerId()) or carriedBy then clearAcceptance() end
        end
        if carriedBy and not down(cache.ped) and IsControlJustPressed(0,Config.AcceptKey) then
            TriggerServerEvent('ptech_mediora_escort:server:escape')
        elseif accepting and IsControlJustPressed(0,Config.AcceptKey) then clearAcceptance() end
        if carrying then
            local carrySession=carrying
            local v=IsPedInAnyVehicle(cache.ped,false)
            applyCarryAnimation(lastInVehicle and not v)
            if carrying==carrySession then
                if v and not lastInVehicle then
                    local vehicle=GetVehiclePedIsIn(cache.ped,false)
                    if vehicle~=0 and not IsThisModelABike(GetEntityModel(vehicle)) then
                        local seat=freeSeat(vehicle)
                        if seat then
                            TriggerServerEvent('ptech_mediora_escort:server:putInVehicle',NetworkGetNetworkIdFromEntity(vehicle),seat,true)
                        end
                    end
                end
                lastInVehicle=v
            end
        else
            lastInVehicle=false
        end
    end
end)
AddEventHandler('onClientResourceStart',function(name)
    if name==GetCurrentResourceName() then
        TriggerServerEvent('ptech_mediora_escort:server:preferences')
        setupRadial()
    elseif name=='qbx_radialmenu' then setupRadial() end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded',function()
    TriggerServerEvent('ptech_mediora_escort:server:preferences')
    setupRadial()
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    if IsEntityAttached(cache.ped) then DetachEntity(cache.ped,true,true) end
    stopAnim()
    pcall(lib.removeRadialItem,'ptechEscortCitizen')
end)
