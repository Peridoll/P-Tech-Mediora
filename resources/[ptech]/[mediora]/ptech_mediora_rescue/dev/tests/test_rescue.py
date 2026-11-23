"""Execute Rescue's Lua 5.4 code with mocked FiveM services."""
from pathlib import Path
import re
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]

COMMON = """
clock, callbacks, events, threads = 0, {}, {}, {}
function vector3(x, y, z)
    return setmetatable({x=x, y=y, z=z}, {
        __sub=function(a,b) return vector3(a.x-b.x,a.y-b.y,a.z-b.z) end,
        __len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
    })
end
function vector4(x,y,z,w) local v=vector3(x,y,z);v.w=w;return v end
function GetGameTimer() return clock end
function GetCurrentResourceName() return 'ptech_mediora_rescue' end
function joaat(value) return value end
function AddEventHandler(name, fn) events[name]=fn end
RegisterNetEvent=AddEventHandler
function emit(name, ...) return events[name](...) end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=clock} end
function Wait(ms)
    if coroutine.isyieldable() then return coroutine.yield(math.max(1,ms)) end
    clock=clock+math.max(1,ms)
    if waitHook then waitHook() end
end
function runUntil(untilTime)
    local count=0
    while true do
        local nextThread
        for _,t in ipairs(threads) do
            if coroutine.status(t.co)~='dead' and t.wake<=untilTime
                and (not nextThread or t.wake<nextThread.wake) then nextThread=t end
        end
        if not nextThread then break end
        clock=math.max(clock,nextThread.wake)
        local ok,ms=coroutine.resume(nextThread.co)
        assert(ok,ms)
        if coroutine.status(nextThread.co)~='dead' then nextThread.wake=clock+(ms or 0) end
        count=count+1;assert(count<100000,'scheduler stuck')
    end
    clock=math.max(clock,untilTime)
end
"""

SERVER = """
serverLogs={}
function print(message) serverLogs[#serverLogs+1]=message end
players, entities, seats, buckets, notifications, deleted, moved = {}, {}, {}, {}, {}, {}, {}
commands, restrictedCommands, aces = {}, {}, {}
function RegisterCommand(name,fn,restricted) commands[name]=fn;restrictedCommands[name]=restricted end
function IsPlayerAceAllowed(src,ace) return aces[src] and aces[src][ace]==true or false end
function command(src,...)
    local savedPrint=print
    print=function() end
    commands.rescueskip(src,{...})
    print=savedPrint
end
nextEntity, failVehicle, failPilot, spawnDelay = 100, false, false, 0
for id=1,4 do
    players[id]={PlayerData={citizenid='char'..id,
        job={name=id==1 and 'police' or 'ambulance',onduty=true},metadata={isdead=id==1}},
        state={dead=id==1 and 'dead' or false},ped=id}
    entities[id]={coords=vector3(0,0,40),ready=0}
    buckets[id]=0
end
exports={qbx_core={GetPlayer=function(_,id) return players[id] end}}
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
function call(name,src,...) return callbacks['ptech_mediora_rescue:'..name](src,...) end
function GetPlayers()
    local result={};for id in pairs(players) do result[#result+1]=tostring(id) end;return result
end
function GetPlayerPed(id) return players[id] and players[id].ped or 0 end
function Player(id) return {state=players[id].state} end
function GetPlayerRoutingBucket(id) return buckets[id] or 0 end
function DoesEntityExist(id) return entities[id]~=nil and clock>=entities[id].ready end
function GetEntityCoords(id) return entities[id].coords end
function GetEntityHeading() return 15 end
function makeEntity(x,y,z)
    nextEntity=nextEntity+1
    entities[nextEntity]={coords=vector3(x,y,z),ready=clock+spawnDelay}
    return nextEntity
end
function CreateVehicleServerSetter(_,_,x,y,z)
    if failVehicle then return 0 end
    return makeEntity(x,y,z)
end
function CreatePed(_,_,x,y,z)
    if failPilot then return 0 end
    return makeEntity(x,y,z)
end
function DeleteEntity(id) deleted[#deleted+1]=id;entities[id]=nil end
function SetEntityOrphanMode() end
function SetEntityRoutingBucket(id,bucket) entities[id].bucket=bucket end
function FreezeEntityPosition(id,frozen) entities[id].frozen=frozen end
function NetworkGetNetworkIdFromEntity(id) return id end
function GetVehiclePedIsIn(ped) return seats[ped] or 0 end
function SetEntityCoords(ped,x,y,z)
    entities[ped].coords=vector3(x,y,z);seats[ped]=nil;moved[#moved+1]=ped
end
function TriggerClientEvent(name,target,...)
    notifications[#notifications+1]={name=name,target=target,args={...}}
end
function finish(ticket) source=1;emit('ptech_mediora_rescue:finish',ticket) end
function available()
    call('status',1);clock=clock+Config.Countdown*1000+1000
    return call('request',1)
end
function transporting(request)
    clock=clock+Config.Helicopter.PickupSeconds*1000
    seats[1]=request.heli
    assert(call('phase',1,request.ticket,'transporting'))
end
function notices(stage)
    local n=0
    for _,e in ipairs(notifications) do
        if e.name=='ptech_mediora_rescue:emsNotify' and e.args[1]==stage then n=n+1 end
    end
    return n
end
"""


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + SERVER)
        for path in ["config.lua", "main/shared/rules.lua", "main/server/server.lua"]:
            self.lua.execute((ROOT / path).read_text(encoding="utf-8"))

    def check(self, script):
        self.lua.execute(script)

    def test_countdown_job_duty_and_down_state_are_required(self):
        self.check("""
        assert(not call('status',2).eligible)
        assert(call('status',1).remaining==Config.Countdown*1000)
        assert(not call('request',1))
        clock=Config.Countdown*1000
        players[1].PlayerData.job.onduty=false
        assert(not call('status',1).eligible)
        players[1].PlayerData.job.onduty=true
        assert(call('status',1).remaining==Config.Countdown*1000)
        players[1].state.dead=false;players[1].PlayerData.metadata.isdead=false
        assert(not call('status',1).eligible)
        players[1].PlayerData.metadata.inlaststand=true
        assert(call('status',1).eligible)
        Config.AllowedJobs={};assert(not call('status',1).eligible)
        """)

    def test_skip_requires_ace_and_only_skips_callers_countdown(self):
        self.check("""
        assert(restrictedCommands.rescueskip==true)
        command(1)
        assert(call('status',1).remaining==Config.Countdown*1000 and #notifications==0)
        aces[1]={['command.rescueskip']=true}
        command(1)
        assert(call('status',1).remaining==0 and not call('status',1).used)
        assert(Config.Countdown==300 and nextEntity==100,'no global change or dispatch')
        assert(#notifications==1 and notifications[1].target==1)
        assert(notifications[1].name=='ox_lib:notify' and notifications[1].args[1].type=='success')
        assert(call('request',1),'normal request is now available')
        """)

    def test_skip_supports_explicit_target_and_console(self):
        self.check("""
        aces[2]={['command.rescueskip']=true}
        command(2,'1')
        assert(call('status',1).remaining==0 and #notifications==2)
        assert(notifications[1].target==1 and notifications[2].target==2)
        players[1].state.dead=false;players[1].PlayerData.metadata.isdead=false
        call('status',1)
        players[1].state.dead='dead'
        assert(call('status',1).remaining==Config.Countdown*1000)
        command(0,'1')
        assert(call('status',1).remaining==0)
        """)

    def test_skip_rejects_invalid_targets_wrong_eligibility_and_extra_arguments(self):
        self.check("""
        aces[1]={['command.rescueskip']=true}
        for _,id in ipairs({'invalid','0','-1','1.5','999','1e309','2'}) do
            command(1,id)
            assert(call('status',1).remaining==Config.Countdown*1000)
        end
        command(1,'1','extra');assert(call('status',1).remaining==Config.Countdown*1000)
        command(0);assert(call('status',1).remaining==Config.Countdown*1000)
        players[1].PlayerData.job.onduty=false
        command(1);assert(not call('status',1).eligible)
        players[1].PlayerData.job.onduty=true
        players[1].state.dead=false;players[1].PlayerData.metadata.isdead=false
        command(1);assert(not call('status',1).eligible)
        """)

    def test_skip_does_not_reset_pending_or_used_rescue(self):
        self.check("""
        aces[1]={['command.rescueskip']=true}
        local request=available()
        local before=#notifications
        command(1)
        assert(#notifications==before+1 and notifications[#notifications].args[1].type=='error')
        assert(entities[request.heli] and call('status',1).used)
        transporting(request);finish(request.ticket)
        command(1)
        assert(call('status',1).used and notifications[#notifications].args[1].type=='error')
        clock=clock+600;assert(not call('request',1))
        """)

    def test_spawn_failure_rolls_back_and_can_be_retried(self):
        self.check("""
        failPilot=true
        assert(not available())
        assert(not entities[101] and not call('status',1).used)
        failPilot=false;clock=clock+600
        local request=call('request',1)
        assert(request.ticket and entities[request.heli] and entities[request.pilot])
        assert(not call('request',1))
        finish(request.ticket)
        assert(not entities[request.heli] and not call('status',1).used)
        """)

    def test_request_reports_waiting_and_spawn_failure_reasons(self):
        self.check("""
        call('status',1)
        local accepted,reason=call('request',1,'waiting')
        assert(accepted==false and reason:find('待機時間'))
        clock=clock+Config.Countdown*1000+600;failPilot=true
        accepted,reason=call('request',1,'failed-pilot')
        assert(accepted==false and reason:find('操縦士'))
        assert(not call('status',1).used and not entities[101])
        """)

    def test_pending_cancel_matches_request_and_never_cancels_boarded_rescue(self):
        self.check("""
        call('status',1);clock=Config.Countdown*1000+1000
        local first=call('request',1,'first')
        source=1;emit('ptech_mediora_rescue:cancelPending','wrong')
        assert(entities[first.heli])
        emit('ptech_mediora_rescue:cancelPending','first')
        assert(not entities[first.heli] and not call('status',1).used)
        clock=clock+600
        local next=call('request',1,'next')
        emit('ptech_mediora_rescue:cancelPending','first')
        assert(entities[next.heli],'stale cancel must not delete the next request')
        source=2;emit('ptech_mediora_rescue:cancelPending','next')
        assert(entities[next.heli],'another player cannot cancel this request')
        transporting(next)
        source=1;emit('ptech_mediora_rescue:cancelPending','next')
        assert(entities[next.heli] and call('status',1).used,'boarded rescue remains protected')
        """)

    def test_cancel_during_spawn_removes_entity_after_it_materializes(self):
        self.check("""
        call('status',1);clock=Config.Countdown*1000+1000;spawnDelay=800
        waitHook=function()
            waitHook=nil;source=1
            emit('ptech_mediora_rescue:cancelPending','spawning')
        end
        local result=call('request',1,'spawning')
        assert(not result and not entities[101] and not call('status',1).used)
        """)

    def test_spawn_wait_reserves_request_and_awaits_entities(self):
        self.check("""
        spawnDelay=800
        local attempts=0
        waitHook=function()
            if attempts==0 and clock>=Config.Countdown*1000+1500 then
                attempts=attempts+1
                assert(not call('request',1),'duplicate while spawning')
            end
        end
        local request=available()
        assert(request and attempts==1 and nextEntity==102)
        assert(entities[request.heli].bucket==0)
        assert(entities[request.heli].frozen and entities[request.pilot].frozen,'hold aircraft until client is ready')
        assert(call('status',1).used)
        """)

    def test_stale_finish_and_phase_do_not_affect_next_request(self):
        self.check("""
        local old=available();finish(old.ticket)
        clock=clock+600
        local new=call('request',1)
        assert(new.ticket~=old.ticket)
        finish(old.ticket)
        assert(entities[new.heli] and entities[new.pilot])
        assert(not call('phase',1,old.ticket,'transporting'))
        finish(nil);assert(entities[new.heli])
        """)

    def test_session_replaced_during_spawn_keeps_new_aircraft(self):
        self.check("""
        Config.Countdown=0;spawnDelay=100
        local replacement
        waitHook=function()
            waitHook=nil
            players[1].PlayerData.citizenid='newchar'
            assert(call('status',1).remaining==0)
            clock=clock+600;spawnDelay=0
            replacement=call('request',1)
            assert(replacement)
        end
        assert(not available(),'old spawn must fail after character change')
        assert(replacement and entities[replacement.heli] and entities[replacement.pilot])
        local snapshot=call('aircraftSnapshot',1)
        assert(#snapshot==1 and snapshot[1].heli==replacement.heli)
        assert(not entities[101],'old aircraft cleaned up')
        """)

    def test_transport_and_arrival_are_verified_and_notify_once_per_stage(self):
        self.check("""
        buckets[3]=42;players[4].PlayerData.job.onduty=false
        local request=available()
        assert(not call('phase',1,request.ticket,'arrived'))
        clock=clock+1000
        assert(not call('phase',1,request.ticket,'transporting'),'not seated')
        transporting(request)
        assert(call('phase',1,request.ticket,'transporting'))
        assert(notices('搬送開始')==1)
        clock=clock+1000
        assert(not call('phase',1,request.ticket,'arrived'),'wrong location')
        entities[1].coords=Config.Hospital.Entrance
        assert(not call('phase',1,request.ticket,'arrived'),'aircraft far from hospital')
        entities[request.heli].coords=Config.Hospital.Helipad
        assert(call('phase',1,request.ticket,'arrived'))
        assert(call('phase',1,request.ticket,'arrived'))
        assert(notices('病院到着')==1)
        -- 車両の座席情報だけが遅延していても、到着済み患者を元の場所へ戻さない。
        finish(request.ticket)
        assert(#moved==0 and call('status',1).used)
        clock=clock+600;assert(not call('request',1))
        """)

    def test_revive_resets_session_immediately_and_deletes_aircraft(self):
        self.check("""
        local request=available();transporting(request)
        players[1].state.dead=false;players[1].PlayerData.metadata.isdead=false
        assert(not call('status',1).eligible)
        assert(not entities[request.heli] and not entities[request.pilot])
        assert(#moved==1 and entities[1].coords.x==0)
        players[1].state.dead='dead'
        assert(call('status',1).remaining==Config.Countdown*1000)
        """)

    def test_ped_character_and_bucket_changes_invalidate_previous_session(self):
        for change in ["players[1].PlayerData.citizenid='newchar'",
                       "players[1].ped=2", "buckets[1]=17"]:
            with self.subTest(change=change):
                self.setUp()
                self.check(f"""
                local request=available();transporting(request)
                {change}
                assert(call('status',1).remaining==Config.Countdown*1000)
                assert(not entities[request.heli] and #moved==0)
                """)

    def test_watchdog_cancels_unclaimed_and_missing_aircraft(self):
        self.check("""
        local request=available()
        runUntil(clock+Config.PreparationTimeout+500)
        assert(not entities[request.heli] and not call('status',1).used)
        clock=clock+600
        request=call('request',1);transporting(request)
        DeleteEntity(request.pilot)
        runUntil(clock+500)
        assert(not entities[request.heli] and call('status',1).used)
        assert(#moved==1)
        local found=false
        for _,e in ipairs(notifications) do
            if e.name=='ptech_mediora_rescue:cancel' and e.args[1]==request.ticket then
                found=e.args[3]:find('操縦士')~=nil
            end
        end
        assert(found,'server must report which entity disappeared')
        """)

    def test_spawn_exception_disconnect_and_resource_stop_clean_up(self):
        self.check("""
        local createPed=CreatePed
        local savedPrint,message=print,nil
        print=function(value) message=value end
        CreatePed=function() error('mock spawn error') end
        assert(not available() and not entities[101] and not call('status',1).used)
        assert(message:find('mock spawn error'));print=savedPrint
        CreatePed=createPed;clock=clock+600
        local request=call('request',1)
        source=1;players[1]=nil;emit('playerDropped')
        assert(not entities[request.heli] and not entities[request.pilot])
        players[1]={PlayerData={citizenid='char1',job={name='police',onduty=true},metadata={isdead=true}},
            state={dead='dead'},ped=1}
        request=available();transporting(request)
        emit('onResourceStop','ptech_mediora_rescue')
        assert(not entities[request.heli] and not entities[request.pilot] and #moved==1)
        """)

    def test_visibility_is_scoped_to_bucket_and_published_after_delay(self):
        self.check("""
        local request=available()
        assert(not call('aircraftSnapshot',2)[1].published)
        buckets[3]=42;assert(#call('aircraftSnapshot',3)==0)
        clock=clock+Config.Helicopter.PublishAfter*1000
        assert(call('aircraftSnapshot',2)[1].published)
        finish(request.ticket);assert(#call('aircraftSnapshot',2)==0)
        """)


CLIENT = """
logs, frozen, cancelledRequests = {}, {}, {}
function print(message) logs[#logs+1]=message end
positions, seats, exists = {[1]=vector3(0,0,40),[101]=vector3(0,0,60),[102]=vector3(0,0,60)}, {}, {[1]=true,[101]=true,[102]=true}
panels, notices, teleports, finishes, phaseCalls, hidden, alphas = {}, {}, {}, {}, {}, {}, {}
coreState, pressed, control, mode = 'started', false, true, 'success'
claimed, consumed, requested, phaseRejects, phaseAttempts, hints = false, false, 0, 0, 0, 0
player={citizenid='char1',job={name='police',onduty=true},metadata={isdead=true}}
LocalPlayer={state={dead=false}} -- metadataだけでダウンしているケースも動作させる。
function PlayerPedId() return 1 end
function PlayerId() return 0 end
function GetPlayerServerId() return 1 end
function GetResourceState(name) return name=='ptech_mediora_core' and coreState or 'missing' end
exports={qbx_core={GetPlayerData=function() return player end},ptech_mediora_core={
    setActionPanel=function(_,panel) panels[panel.id]=panel;return true end,
    removeActionPanel=function(_,id) panels[id]=nil;return true end
}}
lib={notify=function(notice) notices[#notices+1]=notice end,callback={await=function(name,_,ticket,phase)
    if name:find(':status$') then return {eligible=player.metadata.isdead,used=claimed or consumed,remaining=0} end
    if name:find(':request$') then
        requested=requested+1;claimed=true;pressed=false
        return {ticket=requested,heli=101,pilot=102}
    end
    if name:find(':aircraftSnapshot$') then return snapshot or {} end
    assert(name:find(':phase$'))
    phaseCalls[#phaseCalls+1]={ticket=ticket,phase=phase}
    if phase=='transporting' then
        phaseAttempts=phaseAttempts+1
        if phaseAttempts<=phaseRejects then return false end
        consumed=true
    end
    return true
end}}
function lib.addKeybind(options)
    registeredKeybind=options
    options.currentKey=options.defaultKey
    function options:isControlPressed()
        if self.isPressed~=nil then return self.isPressed end
        return pressed
    end
    return options
end
function DoesEntityExist(id) return exists[id]==true end
function NetworkDoesEntityExistWithNetworkId(id)
    return exists[id]==true and clock>=((netReadyAt or {})[id] or 0)
end
function NetworkGetEntityFromNetworkId(id)
    assert(NetworkDoesEntityExistWithNetworkId(id),'GetNetworkObject: no object by ID '..tostring(id))
    return id
end
function NetworkHasControlOfEntity() return control end
function NetworkRequestControlOfEntity() end
function GetEntityCoords(id) return positions[seats[id] or id] end
function GetEntityHeading() return 15 end
function IsEntityDead() return false end
function IsPauseMenuActive() return paused==true end
function IsNuiFocused() return focused==true end
function IsNuiFocusKeepingInput() return keepInput==true end
function SetEntityCoordsNoOffset(id,x,y,z)
    positions[id]=vector3(x,y,z);seats[id]=nil
    teleports[#teleports+1]={id=id,x=x,y=y,z=z}
end
function SetEntityHeading() end
function ClearPedTasksImmediately(id) seats[id]=nil end
function SetPedIntoVehicle(ped,vehicle) seats[ped]=vehicle end
TaskWarpPedIntoVehicle=SetPedIntoVehicle
function GetVehiclePedIsIn(id) return seats[id] or 0 end
function IsPedInVehicle(ped,vehicle) return seats[ped]==vehicle end
function StartShapeTestLosProbe() return 1 end
function GetShapeTestResult() return 2,true,vector3(0,0,100) end
function GetEntityHeightAboveGround() return 1 end
function TaskHeliMission(_,heli,_,_,x,y,z,mission)
    assert(control,'mission without entity control')
    if mode=='success' then positions[heli]=vector3(x,y,z) end
end
function TriggerServerEvent(name,ticket)
    if name=='ptech_mediora_rescue:cancelPending' then
        assert(type(ticket)=='string')
        cancelledRequests[#cancelledRequests+1]=ticket
        return
    end
    assert(name=='ptech_mediora_rescue:finish' and type(ticket)=='number')
    finishes[#finishes+1]=ticket;claimed=false
end
function IsControlPressed() return pressed and normalInput==true end
function IsDisabledControlPressed() return pressed and normalInput~=true end
function SetEntityLocallyInvisible(id) hidden[id]=true end
function SetEntityAlpha(id,alpha) alphas[id]=alpha end
function ResetEntityAlpha(id) alphas[id]=255 end
function EndTextCommandDisplayText() hints=hints+1 end
for _,name in ipairs({'SetEntityCollision','SetEntityCompletelyDisableCollision','SetEntityInvincible',
    'FreezeEntityPosition','SetVehicleEngineOn','SetHeliBladesFullSpeed','SetBlockingOfNonTemporaryEvents',
    'SetPedKeepTask','SetDriverAbility','SetDriverAggressiveness','DisableControlAction','SetTextFont',
    'SetTextScale','SetTextColour','SetTextOutline','BeginTextCommandDisplayText','AddTextComponentSubstringPlayerName'}) do
    _G[name]=function() end
end
function FreezeEntityPosition(id,value) frozen[id]=value end
"""


class ClientTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + CLIENT)
        for path in ["config.lua", "main/shared/rules.lua"]:
            self.lua.execute((ROOT / path).read_text(encoding="utf-8"))
        self.lua.execute("Config.HoldDuration=0.05;Config.Helicopter.MaxFlightSeconds=1")
        self.lua.execute((ROOT / "dev/legacy/full_flow_client.lua").read_text(encoding="utf-8"))

    def check(self, script):
        self.lua.execute(script)

    def test_rescue_keybind_works_when_native_reload_input_is_unavailable(self):
        self.check("""
        Config.HoldDuration=3
        IsControlPressed=function() return false end
        IsDisabledControlPressed=function() return false end
        pressed=true;runUntil(1600)
        assert(panels.rescue and panels.rescue.state=='holding' and panels.rescue.progress>=50)
        assert(panels.rescue.text:find('%%') and panels.rescue.temporaryExpand)
        runUntil(3300)
        assert(requested==1,'mapped key must work independently of disabled GTA reload input')
        """)

    def test_rebound_key_label_and_release_reset_the_hold(self):
        self.check("""
        Config.HoldDuration=3
        assert(registeredKeybind and registeredKeybind.defaultKey=='R')
        registeredKeybind.currentKey='X'
        pressed=true;runUntil(1500)
        assert(panels.rescue.state=='holding' and panels.rescue.text:find('X'))
        pressed=false;runUntil(1600)
        assert(panels.rescue.state=='ready' and panels.rescue.progress==0)
        pressed=true;runUntil(4500)
        assert(requested==0)
        runUntil(4800)
        assert(requested==1)
        """)

    def test_request_wait_replaces_hold_prompt_before_server_reply(self):
        self.check("""
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':request$') then Wait(2000) end
            return await(name,...)
        end
        pressed=true;runUntil(1000)
        assert(panels.rescue.state=='active' and panels.rescue.text:find('送信'))
        assert(panels.rescue.temporaryExpand)
        runUntil(2500)
        assert(requested==1)
        """)

    def test_request_timeout_unblocks_ui_and_requires_release_before_retry(self):
        self.check("""
        Config.RequestTimeout=1000
        local await,calls=lib.callback.await,0
        lib.callback.await=function(name,...)
            if name:find(':request$') then calls=calls+1;Wait(30000) end
            return await(name,...)
        end
        pressed=true;runUntil(1500)
        assert(panels.rescue.state=='error' and panels.rescue.text:find('応答がありません'))
        assert(panels.rescue.temporaryExpand and #cancelledRequests==1)
        runUntil(6000)
        assert(calls==1 and not consumed,'holding the key cannot resubmit a failed request')
        pressed=false;runUntil(6100);pressed=true;runUntil(6300)
        assert(calls==2,'a new hold can retry without restarting the resource')
        """)

    def test_late_request_reply_is_finished_without_starting_flight(self):
        self.check("""
        Config.RequestTimeout=1000
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':request$') then Wait(2000) end
            return await(name,...)
        end
        pressed=true;runUntil(3000)
        assert(#cancelledRequests==1 and #finishes==1 and requested==1)
        assert(not consumed and #teleports==0 and not seats[1])
        assert(panels.rescue.state=='error')
        """)

    def test_server_rejection_reason_is_visible_after_full_hold(self):
        self.check("""
        local await,calls=lib.callback.await,0
        lib.callback.await=function(name,...)
            if name:find(':request$') then
                calls=calls+1
                return false,'救助ヘリの操縦士を生成できませんでした'
            end
            return await(name,...)
        end
        pressed=true;runUntil(1000)
        assert(panels.rescue.state=='error' and panels.rescue.text:find('操縦士'))
        assert(notices[#notices].description==panels.rescue.text)
        assert(logs[#logs]:find('操縦士') and #cancelledRequests==1)
        runUntil(6000);assert(calls==1)
        """)

    def test_resource_stop_cancels_request_awaiting_reply(self):
        self.check("""
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':request$') then Wait(10000) end
            return await(name,...)
        end
        pressed=true;runUntil(1000)
        emit('onClientResourceStop','ptech_mediora_rescue')
        assert(#cancelledRequests==1 and not panels.rescue)
        """)

    def test_menu_or_exclusive_nui_focus_clears_mapped_hold_until_new_press(self):
        for change in ["paused=true", "focused=true;keepInput=false"]:
            with self.subTest(change=change):
                self.setUp()
                self.check(f"""
                Config.HoldDuration=3
                registeredKeybind.isPressed=true;runUntil(1500)
                {change};runUntil(1700)
                assert(panels.rescue.state=='ready' and panels.rescue.progress==0)
                paused=false;focused=false;runUntil(5000)
                assert(requested==0,'a missed key-up event must not trigger rescue after closing UI')
                registeredKeybind.isPressed=true;runUntil(8200)
                assert(requested==1)
                """)

    def test_snapshot_skips_aircraft_outside_local_scope(self):
        self.check("""
        snapshot={{heli=65528,pilot=65527,owner=2,published=true}}
        runUntil(1500)
        assert(not hidden[65528] and not alphas[65528],'do not resolve unstreamed entities')
        """)

    def test_pickup_waits_for_each_entity_to_stream_in(self):
        self.check("""
        netReadyAt={[101]=800,[102]=1600}
        pressed=true;runUntil(1500)
        assert(requested==1 and not consumed and not seats[1])
        assert(frozen[101] and panels.rescue.text:find('操縦士'),'hold helicopter while waiting for pilot')
        runUntil(5000)
        assert(consumed and #finishes==1 and positions[1].x==Config.Hospital.Entrance.x)
        assert(frozen[101]==false and frozen[102]==false,'release pilot and helicopter before flying')
        """)

    def test_incomplete_local_player_snapshot_does_not_abort_server_approved_pickup(self):
        self.check("""
        netReadyAt={[101]=800,[102]=1600}
        local getData=exports.qbx_core.GetPlayerData
        exports.qbx_core.GetPlayerData=function(...)
            if clock>=200 and clock<600 then return {} end
            return getData(...)
        end
        pressed=true;runUntil(5000)
        assert(consumed and #finishes==1 and positions[1].x==Config.Hospital.Entrance.x)
        """)

    def test_delayed_local_job_and_death_flags_do_not_abort_authorized_pickup(self):
        self.check("""
        netReadyAt={[101]=800,[102]=1600}
        pressed=true
        CreateThread(function()
            Wait(200);player.job.onduty=false;player.metadata.isdead=false
            Wait(400);player.job.onduty=true;player.metadata.isdead=true
        end)
        runUntil(5000)
        assert(consumed and #finishes==1 and positions[1].x==Config.Hospital.Entrance.x)
        """)

    def test_server_cancel_during_streaming_keeps_reason_visible(self):
        self.check("""
        netReadyAt={[101]=8000}
        pressed=true
        CreateThread(function()
            Wait(500);source=65535
            emit('ptech_mediora_rescue:cancel',1,true,'救助ヘリがサーバー上で消失したため中断しました')
        end)
        runUntil(2000)
        assert(#finishes==1 and not consumed and panels.rescue.state=='error')
        assert(panels.rescue.text:find('ヘリ') and panels.rescue.temporaryExpand)
        assert(logs[#logs]:find('搬送中断') and logs[#logs]:find('消失'))
        runUntil(5000);assert(panels.rescue.state=='ready')
        """)

    def test_missing_pilot_times_out_without_invalid_network_lookups(self):
        self.check("""
        exists[102]=false;pressed=true
        runUntil(11000)
        assert(requested==1 and not consumed and #finishes==1 and positions[1].z==40)
        assert(notices[#notices].type=='error' and notices[#notices].description:find('操縦士'))
        assert(logs[#logs]:find('配信待ちタイムアウト') and logs[#logs]:find('pilotNet=102'))
        assert(panels.rescue and panels.rescue.state=='ready')
        """)

    def test_three_second_hold_completes_across_delayed_status_polls(self):
        self.check("""
        Config.HoldDuration=3
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':status$') then Wait(150) end
            return await(name,...)
        end
        pressed=true;runUntil(3600)
        assert(requested==1,'status latency must not restart the three-second hold')
        """)

    def test_release_is_detected_while_status_poll_is_waiting(self):
        self.check("""
        Config.HoldDuration=3
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':status$') then Wait(800) end
            return await(name,...)
        end
        pressed=true
        CreateThread(function() Wait(1400);pressed=false;Wait(100);pressed=true end)
        runUntil(4499)
        assert(requested==0,'releasing the key must reset the actual continuous hold')
        runUntil(4900)
        assert(requested==1,'the new hold must complete after three continuous seconds')
        """)

    def test_hold_survives_enabled_and_disabled_input_switches(self):
        self.check("""
        Config.HoldDuration=3
        IsControlPressed=function() return pressed and clock%400<200 end
        IsDisabledControlPressed=function() return pressed and clock%400>=200 end
        pressed=true;runUntil(3300)
        assert(requested==1,'other resources toggling control state must not reset the hold')
        """)

    def test_one_failed_status_poll_does_not_clear_hold(self):
        self.check("""
        Config.HoldDuration=3
        local await,count=lib.callback.await,0
        lib.callback.await=function(name,...)
            if name:find(':status$') then
                count=count+1
                if count==2 then error('temporary status failure') end
            end
            return await(name,...)
        end
        pressed=true;runUntil(3300)
        assert(requested==1,'one transient failure must not reset a valid hold')
        """)

    def test_prolonged_status_outage_expires_cached_eligibility(self):
        self.check("""
        Config.HoldDuration=10
        local await,count=lib.callback.await,0
        lib.callback.await=function(name,...)
            if name:find(':status$') then
                count=count+1
                if count>1 then Wait(10000) end
            end
            return await(name,...)
        end
        pressed=true;runUntil(6200)
        assert(requested==0 and not panels.rescue,'stale eligibility must expire during an outage')
        """)

    def test_explicit_ineligible_status_cancels_hold_immediately(self):
        self.check("""
        Config.HoldDuration=3
        local await=lib.callback.await
        lib.callback.await=function(name,...)
            if name:find(':status$') and clock>=1000 then return {eligible=false} end
            return await(name,...)
        end
        pressed=true;runUntil(3300)
        assert(requested==0 and not panels.rescue)
        """)

    def test_late_pre_request_status_does_not_restore_ready_after_transport(self):
        self.check("""
        Config.HoldDuration=1.5;mode='stalled'
        local await,count=lib.callback.await,0
        lib.callback.await=function(name,...)
            if name:find(':status$') then
                count=count+1
                local reply=await(name,...)
                if count==2 then Wait(3500) end
                return reply
            end
            return await(name,...)
        end
        pressed=true;runUntil(4510)
        assert(requested==1 and consumed and #finishes==1)
        assert(not panels.rescue,'a delayed pre-request reply must not restore ready status')
        """)

    def test_core_panel_works_without_marine_and_recovers_after_core_restart(self):
        self.check("""
        runUntil(10)
        assert(panels.rescue and panels.rescue.state=='ready')
        coreState='missing';emit('onClientResourceStop','ptech_mediora_core')
        runUntil(20);assert(hints>0)
        panels={};coreState='started';emit('onClientResourceStart','ptech_mediora_core')
        assert(panels.rescue and panels.rescue.state=='ready')
        """)

    def test_success_preserves_death_and_finishes_at_hospital(self):
        self.check("""
        phaseRejects=2;pressed=true
        runUntil(5000)
        assert(requested==1 and consumed and #finishes==1 and finishes[1]==1)
        assert(phaseAttempts==3,'retry while seat data is synchronizing')
        assert(positions[1].x==Config.Hospital.Entrance.x and not seats[1])
        assert(teleports[1].id==101 and teleports[1].z==120,'roof clearance')
        assert(player.metadata.isdead and LocalPlayer.state.dead==false)
        assert(not panels.rescue)
        assert(notices[#notices].type=='success')
        """)

    def test_control_failure_cleans_up_without_moving_patient(self):
        self.check("""
        control=false;pressed=true;runUntil(5000)
        assert(#finishes==1 and not consumed and #teleports==0 and not seats[1])
        assert(panels.rescue and panels.rescue.state=='ready')
        """)

    def test_transport_timeout_returns_patient_to_pickup_without_reviving(self):
        self.check("""
        mode='stalled';pressed=true;runUntil(5000)
        assert(consumed and #finishes==1 and not seats[1])
        assert(positions[1].x==0 and positions[1].z==40 and player.metadata.isdead)
        assert(notices[#notices].type=='error')
        """)

    def test_stale_or_local_cancel_does_not_cancel_current_transport(self):
        self.check("""
        pressed=true
        CreateThread(function()
            Wait(500);source=65535;emit('ptech_mediora_rescue:cancel',999,true)
            source=1;emit('ptech_mediora_rescue:cancel',1,true)
        end)
        runUntil(5000)
        assert(consumed and positions[1].x==Config.Hospital.Entrance.x and #finishes==1)
        """)

    def test_server_cancellation_during_pickup_allows_retry(self):
        self.check("""
        pressed=true
        CreateThread(function()
            Wait(500);source=65535;emit('ptech_mediora_rescue:cancel',1,true)
        end)
        runUntil(2000)
        assert(not consumed and #finishes==1 and positions[1].z==40)
        assert(panels.rescue and panels.rescue.state=='error')
        runUntil(5000)
        assert(panels.rescue.state=='ready')
        """)

    def test_disappearing_aircraft_recovers_patient_from_last_known_position(self):
        self.check("""
        mode='stalled';Config.Helicopter.MaxFlightSeconds=10;pressed=true
        CreateThread(function()
            Wait(1400)
            positions[1]=GetEntityCoords(1);seats[1]=nil;exists[101]=false
            source=65535;emit('ptech_mediora_rescue:cancel',1,true)
        end)
        runUntil(2500)
        assert(consumed and #finishes==1 and positions[1].z==40)
        """)

    def test_external_teleport_is_not_overridden_after_aircraft_disappears(self):
        self.check("""
        mode='stalled';Config.Helicopter.MaxFlightSeconds=10;pressed=true
        CreateThread(function()
            Wait(1400)
            positions[1]=vector3(1000,1000,50);seats[1]=nil;exists[101]=false
            source=65535;emit('ptech_mediora_rescue:cancel',1,true)
        end)
        runUntil(2500)
        assert(#finishes==1 and positions[1].x==1000 and positions[1].z==50)
        """)

    def test_revive_interrupts_flight_and_returns_passenger_without_changing_health(self):
        self.check("""
        mode='stalled';Config.Helicopter.MaxFlightSeconds=10;pressed=true
        CreateThread(function()
            Wait(1400);player.metadata.isdead=false
            source=65535;emit('ptech_mediora_rescue:cancel',1,true,'死亡・瀕死状態が終了しました')
        end)
        runUntil(2000)
        assert(#finishes==1 and positions[1].z==40 and not player.metadata.isdead)
        assert(panels.rescue.state=='error' and panels.rescue.text:find('死亡'))
        runUntil(6000);assert(not panels.rescue)
        """)

    def test_bucket_change_cancel_does_not_relocate_patient(self):
        self.check("""
        mode='stalled';Config.Helicopter.MaxFlightSeconds=10;pressed=true
        CreateThread(function()
            Wait(1400);source=65535;emit('ptech_mediora_rescue:cancel',1,false)
        end)
        runUntil(2000)
        assert(#finishes==1 and #teleports==1,'no rollback after bucket change')
        """)

    def test_resource_stop_recovers_passenger_and_removes_panel(self):
        self.check("""
        mode='stalled';Config.Helicopter.MaxFlightSeconds=10;pressed=true
        runUntil(1400)
        assert(consumed and seats[1]==101)
        emit('onClientResourceStop','ptech_mediora_rescue')
        assert(#finishes==1 and positions[1].z==40 and not seats[1] and not panels.rescue)
        """)

    def test_visibility_hides_other_patients_aircraft_until_publication(self):
        self.check("""
        snapshot={{heli=101,pilot=102,owner=2,published=false}}
        runUntil(10)
        assert(hidden[101] and hidden[102])
        snapshot[1].owner=1;runUntil(20)
        assert(alphas[101]==Config.Helicopter.Transparency)
        snapshot[1].published=true;runUntil(30)
        assert(alphas[101]==255 and alphas[102]==255)
        """)


class CommandHelpTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + SERVER)
        self.lua.execute("""
        states={ptech_mediora_core='started',chat='started',ptech_mediora_rescue='stopped'}
        suggestions,messages={},{}
        function GetCurrentResourceName() return 'ptech_mediora_core' end
        function GetResourceState(name) return states[name] or 'missing' end
        function SetTimeout(ms,fn) CreateThread(function() Wait(ms);fn() end) end
        lib.callback.await=function(name) return callbacks[name](1) end
        function TriggerEvent(name,...)
            local args={...}
            if name=='chat:addSuggestion' then suggestions[args[1]]={help=args[2],params=args[3]}
            elseif name=='chat:removeSuggestion' then suggestions[args[1]]=nil
            elseif name=='chat:addMessage' then messages[#messages+1]=args[1] end
        end
        """)
        core = ROOT.parent / "ptech_mediora_core"
        for path in ["config/config.lua", "config/command_help.lua",
                     "main/server/command_help.lua", "main/client/command_help.lua"]:
            self.lua.execute((core / path).read_text(encoding="utf-8"))
            if path == "config/command_help.lua":
                # Archived Rescue commands are absent from the live configuration.
                self.lua.execute("""
                table.insert(Config.CommandHelp.commands, {
                    name='rescueskip',resource='ptech_mediora_rescue',ace='command.rescueskip',
                    help='待機時間の試験用コマンド',usage='/rescueskip [プレイヤーID]',
                    params={{name='プレイヤーID',help='省略すると自分'}},
                })
                """)

    def check(self, script):
        self.lua.execute(script)

    def test_authorized_player_sees_suggestion_and_detailed_help(self):
        self.check("""
        aces[1]={['command.rescueskip']=true}
        states.ptech_mediora_rescue='started'
        emit('onClientResourceStart','ptech_mediora_core');runUntil(1100)
        local suggestion=suggestions['/rescueskip']
        assert(suggestion and suggestion.help:find('待機時間') and #suggestion.params==1)
        commands.mediorahelp(0,{'rescueskip'});runUntil(1200)
        local text=messages[#messages].args[2]
        assert(text:find('/rescueskip %[プレイヤーID%]') and text:find('省略すると自分'))
        """)

    def test_help_hides_command_without_ace_or_running_rescue(self):
        self.check("""
        local function visible()
            for _,c in ipairs(callbacks['ptech_mediora_core:commandHelp'](1).commands) do
                if c.name=='rescueskip' then return true end
            end
            return false
        end
        states.ptech_mediora_rescue='started';assert(not visible())
        aces[1]={['command.rescueskip']=true};assert(visible())
        states.ptech_mediora_rescue='stopped';assert(not visible())
        """)

    def test_rescue_start_and_stop_refresh_suggestions_without_core_restart(self):
        self.check("""
        aces[1]={['command.rescueskip']=true}
        emit('onClientResourceStart','ptech_mediora_core');runUntil(1100)
        assert(not suggestions['/rescueskip'])
        states.ptech_mediora_rescue='started'
        emit('onClientResourceStart','ptech_mediora_rescue');runUntil(2200)
        assert(suggestions['/rescueskip'])
        states.ptech_mediora_rescue='stopped'
        emit('onClientResourceStop','ptech_mediora_rescue');runUntil(3300)
        assert(not suggestions['/rescueskip'])
        """)


class ManifestTest(unittest.TestCase):
    def test_all_declared_local_scripts_exist_and_lua_compiles(self):
        manifest = (ROOT / "fxmanifest.lua").read_text(encoding="utf-8")
        for name in re.findall(r"'([^']+\.lua)'", manifest):
            if not name.startswith("@"):
                self.assertTrue((ROOT / name).is_file(), name)
        lua = LuaRuntime()
        for path in ROOT.rglob("*.lua"):
            lua.execute("assert(load(...))", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
