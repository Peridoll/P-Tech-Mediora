"""Test the active client pipeline, Core exports, timeouts and entity lifecycle in Lua."""
from pathlib import Path
import json
import shutil
import subprocess
import unittest

from lupa.lua54 import LuaRuntime
from test_rescue import COMMON

ROOT = Path(__file__).resolve().parents[2]

HARNESS = """
-- Render frames at 16ms; timers retain their actual requested interval.
function Wait(ms)
    ms=ms==0 and 16 or ms
    if coroutine.isyieldable() then return coroutine.yield(ms) end
    clock=clock+ms
end
ped,dead,paused,focused,keepInput=1,true,false,false,false
coreStarted,qbox=true,false
LocalPlayer={state={dead=false}}
metadata={};health=0
entities={[1]={pos=vector3(10,20,40)},[2]={pos=vector3(30,50,60)}}
seats,seatNumbers,models,released,logs,notices,panels,warps={},{},{},{},{},{},{},{}
nextEntity,createdHelis,createdPilots,panelUpdates=100,0,0,0
function print(value) logs[#logs+1]=value end
function PlayerPedId() return ped end
function IsEntityDead() return dead end
function GetResourceState(name)
    if name=='ptech_mediora_core' then return coreStarted and 'started' or 'stopped' end
    return qbox and 'started' or 'missing'
end
exports={
    qbx_core={GetPlayerData=function() return {metadata=metadata} end},
    ptech_mediora_core={
        setActionPanel=function(_,value) panels[value.id]=value;panelUpdates=panelUpdates+1;return true end,
        removeActionPanel=function(_,id) panels[id]=nil;return true end,
    },
}
function GetEntityCoords(id)
    assert(entities[id],'reading a deleted entity')
    return entities[seats[id] or id].pos
end
function GetEntityHeading() return 90 end
function GetVehiclePedIsIn(id) return seats[id] or 0 end
function GetPedInVehicleSeat(vehicle,seat)
    assert(entities[vehicle],'reading seats of deleted vehicle')
    for id,v in pairs(seats) do if v==vehicle and seatNumbers[id]==seat then return id end end
    return 0
end
function DoesEntityExist(id) return entities[id]~=nil end
function SetEntityCoordsNoOffset(id,x,y,z,tasks,ik,warp)
    assert(tasks and ik and warp)
    warps[#warps+1]={ped=id,z=z,time=clock}
    seats[id],seatNumbers[id]=nil,nil
    entities[id].pos=vector3(x,y,z)
end
function SetEntityHeading() end
function ClearPedTasksImmediately() end
function IsPauseMenuActive() return paused end
function IsNuiFocused() return focused end
function IsNuiFocusKeepingInput() return keepInput end
lib={
    addKeybind=function(opts)
        key=opts;key.isPressed=false;key.currentKey='R'
        key.isControlPressed=function(self) return self.isPressed end
        return key
    end,
    notify=function(value) notices[#notices+1]=value end,
}
function press() key.isPressed=true end
function release() key.isPressed=false;key.onReleased() end
function IsModelInCdimage() return not invalidModel end
function IsModelValid() return not invalidModel end
function IsThisModelAHeli(model) return model=='maverick' end
function IsModelAPed(model) return model=='s_m_m_pilot_02' end
function RequestModel(model) models[model]=true end
function HasModelLoaded(model) return models[model] and not modelTimeout and clock >= (modelReadyAt or 0) end
function SetModelAsNoLongerNeeded(model) released[model]=(released[model] or 0)+1 end
lib.callback={await=function(name,_,request)
    assert(name=='ptech_mediora_rescue:pickupTest:spawn')
    assert(HasModelLoaded(Config.Helicopter.Model) and HasModelLoaded(Config.Helicopter.Pilot))
    serverRequest=request
    if failHeli then return false end
    local pos=entities[1].pos
    local x,y,z=pos.x,pos.y,pos.z+Config.Helicopter.HoverOffset
    nextEntity=nextEntity+1;heli=nextEntity;createdHelis=createdHelis+1
    entities[heli]={pos=vector3(x,y,z)}
    if failPilot then DeleteEntity(heli);return false end
    nextEntity=nextEntity+1;pilot=nextEntity;createdPilots=createdPilots+1
    entities[pilot]={pos=entities[heli].pos}
    return {heli=heli,pilot=pilot}
end}
function NetworkDoesEntityExistWithNetworkId(id) return entities[id]~=nil end
function NetToVeh(id) return id end
function NetToPed(id) return id end
function NetworkHasControlOfEntity(id) return entities[id]~=nil end
function TriggerServerEvent(name,request)
    assert(request==serverRequest)
    if name=='ptech_mediora_rescue:pickupTest:cleanup' then
        DeleteEntity(pilot);DeleteEntity(heli)
    else
        assert(name=='ptech_mediora_rescue:pickupTest:boarded' and GetPedInVehicleSeat(heli,0)==1)
    end
end
function SetPedIntoVehicle(id,vehicle,seat)
    if id==pilot then assert(seat==-1);seats[id],seatNumbers[id]=vehicle,seat;return end
    assert(seat==0,'player must be a passenger')
    if failBoard then return end
    seats[id],seatNumbers[id],boardedAt=vehicle,seat,clock
end
function SetEntityAsMissionEntity(id) entities[id].mission=true end
function SetEntityInvincible(id,value) entities[id].invincible=value end
function SetEntityCollision(id,value) entities[id].collision=value end
function FreezeEntityPosition(id,value) entities[id].frozen=value end
function SetVehicleEngineOn(id,value) entities[id].engine=value end
function SetHeliBladesFullSpeed(id) entities[id].blades=true end
function SetBlockingOfNonTemporaryEvents(id,value) entities[id].blocksEvents=value end
function SetPedKeepTask(id,value) entities[id].keepTask=value end
function SetDriverAbility(id,value) entities[id].ability=value end
function TaskHeliMission(id,vehicle,_,_,x,y,z,mission)
    assert(GetPedInVehicleSeat(vehicle,-1)==id and not entities[vehicle].frozen and mission==4)
    assert(entities[vehicle].collision and entities[vehicle].engine and entities[vehicle].blades)
    local helipad=Config.Hospital.Helipad
    assert(x==helipad.x and y==helipad.y)
    assert(z==math.max(entities[vehicle].pos.z+30,helipad.z+Config.Helicopter.CruiseHeight))
    entities[id].flying=true
end
function DeleteEntity(id)
    if entities[id] then
        for occupant,vehicle in pairs(seats) do
            if vehicle==id then
                entities[occupant].pos=entities[id].pos
                seats[occupant],seatNumbers[occupant]=nil,nil
            end
        end
    end
    entities[id],seats[id],seatNumbers[id]=nil,nil,nil
end
"""


class PickupTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + HARNESS)
        self.lua.execute((ROOT / 'config.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT / 'main/client/client.lua').read_text(encoding='utf-8'))

    def check(self, value):
        self.lua.execute(value)

    def test_default_five_second_wait_does_not_count_early_hold(self):
        self.check("""
        assert(Config.Countdown==5 and Config.Helicopter.TestDuration==5)
        press();runUntil(4999)
        assert(createdHelis==0 and panels.rescue.state=='waiting')
        assert(panels.rescue.text:find('0:01'))
        runUntil(7999);assert(createdHelis==0)
        runUntil(8016);assert(createdHelis==1 and seats[1]==heli)
        assert(panelUpdates<800,'waiting UI must not flood Core every frame')
        """)

    def test_pilot_drives_and_passenger_is_returned_before_five_second_cleanup(self):
        self.check("""
        Config.Countdown=0;press();runUntil(2999);assert(createdHelis==0)
        runUntil(3040)
        assert(createdHelis==1 and createdPilots==1 and boardedAt>=3000)
        assert(GetPedInVehicleSeat(heli,-1)==pilot and GetPedInVehicleSeat(heli,0)==1)
        assert(entities[heli].pos.z==60 and entities[heli].engine and entities[heli].blades)
        assert(entities[pilot].flying and entities[pilot].keepTask and not entities[heli].frozen)
        assert(panels.rescue.state=='active')
        runUntil(boardedAt+4999);assert(entities[heli] and entities[pilot])
        runUntil(boardedAt+5000)
        assert(not entities[heli] and not entities[pilot] and not seats[1])
        assert(entities[1].pos.z==40 and health==0 and dead)
        assert(released.maverick==1 and released.s_m_m_pilot_02==1)
        runUntil(15000);assert(createdHelis==1,'a held key must not spawn repeatedly')
        release();runUntil(15016);press();runUntil(18032);assert(createdHelis==2)
        """)

    def test_alive_player_cannot_spawn_or_see_rescue_panel(self):
        self.check('dead=false;Config.Countdown=0;press();runUntil(4000);assert(createdHelis==0 and not panels.rescue)')

    def test_manifest_entry_runs_using_only_existing_tracked_runtime_paths(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(COMMON + HARNESS)
        lua.execute("""
        runtime={}
        function fx_version() end;function game() end;function lua54() end
        function author() end;function description() end;function version() end
        function shared_scripts(paths) for _,path in ipairs(paths) do runtime[#runtime+1]=path end end
        function client_scripts(paths) for _,path in ipairs(paths) do runtime[#runtime+1]=path end end
        function server_scripts(paths) serverRuntime=paths end
        function dependencies() end
        """)
        lua.execute((ROOT / 'fxmanifest.lua').read_text(encoding='utf-8'))
        scripts = list(lua.globals().runtime.values())
        self.assertEqual(scripts, ['@ox_lib/init.lua', 'config.lua', 'main/client/client.lua'])
        self.assertEqual(list(lua.globals().serverRuntime.values()), ['main/server/pickup_test.lua'])
        self.assertTrue((ROOT / 'main/server/pickup_test.lua').is_file())
        package = {name: (ROOT / name).read_text(encoding='utf-8')
                   for name in ('config.lua', 'main/client/client.lua')}
        for name in scripts:
            if not name.startswith('@'):
                lua.execute(package[name])
        lua.execute("""
        runUntil(16)
        assert(panels.rescue.state=='waiting' and panels.rescue.temporaryExpand)
        assert(logs[1]:find('entry%-v3 file=main/client/client.lua'))
        Config.Countdown=0;press();runUntil(3056)
        assert(createdHelis==1 and createdPilots==1 and seats[1]==heli)
        """)

    def test_death_opens_real_core_sidebar_and_keeps_ready_gauge_visible(self):
        self.check('Config.Countdown=1;runUntil(16)')
        waiting = dict(self.lua.globals().panels.rescue.items())
        self.check('runUntil(1024)')
        ready = dict(self.lua.globals().panels.rescue.items())
        self.assertEqual(waiting['state'], 'waiting')
        self.assertEqual(ready['state'], 'ready')
        node = shutil.which('node')
        self.assertIsNotNone(node, 'Node is required to exercise Core UI behavior')
        result = subprocess.run(
            [node, str(ROOT / 'dev/tests/check_rescue_sidebar.js'),
             str(ROOT.parent / 'ptech_mediora_core/main/ui/app.js')],
            input=json.dumps([waiting, ready]), text=True, encoding='utf-8', capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_release_restarts_hold_and_core_shows_progress(self):
        self.check("""
        Config.Countdown=0;press();runUntil(1504)
        assert(panels.rescue.state=='holding' and panels.rescue.progress>=50)
        release();runUntil(1600);assert(panels.rescue.state=='ready')
        press();runUntil(4600);assert(createdHelis==0)
        runUntil(4624);assert(createdHelis==1)
        """)

    def test_model_timeout_reports_error_and_releases_both_models(self):
        self.check("""
        Config.Countdown=0;modelTimeout=true;press();runUntil(8100)
        assert(createdHelis==0 and #notices==1 and panels.rescue.state=='error')
        assert(released.maverick==1 and released.s_m_m_pilot_02==1)
        """)

    def test_cold_model_load_does_not_consume_the_five_seconds(self):
        self.check("""
        Config.Countdown=0;modelReadyAt=6000;press();runUntil(5999);assert(createdHelis==0)
        runUntil(6032);assert(createdHelis==1 and boardedAt>=6000)
        runUntil(boardedAt+4999);assert(entities[heli])
        runUntil(boardedAt+5000);assert(not entities[heli] and not entities[pilot])
        """)

    def test_partial_spawn_or_failed_boarding_leaves_no_entities(self):
        for failure, until in (('failHeli', 8100), ('failPilot', 8100), ('failBoard', 5100)):
            with self.subTest(failure=failure):
                self.setUp()
                self.check(f"""
                Config.Countdown=0;{failure}=true;press();runUntil({until})
                assert(not entities[heli] and not entities[pilot] and #notices==1)
                assert(not seats[1] and entities[1].pos.z==40 and #warps==0)
                """)

    def test_external_death_end_and_resource_stop_clean_up_entities_and_panel(self):
        for action in ("dead=false", "emit('onClientResourceStop','ptech_mediora_rescue')"):
            with self.subTest(action=action):
                self.setUp()
                self.check(f"""
                Config.Countdown=0;press();runUntil(3100);assert(seats[1]==heli)
                {action}
                if dead==false then runUntil(3120) end
                assert(not entities[heli] and not entities[pilot] and not seats[1] and not panels.rescue)
                assert(entities[1].pos.z==40 and #warps==1)
                """)

    def test_ped_change_does_not_move_new_character(self):
        self.check("""
        Config.Countdown=0;press();runUntil(3100);ped=2;runUntil(3120)
        assert(not entities[heli] and not entities[pilot] and #warps==0)
        assert(entities[2].pos.x==30 and entities[2].pos.z==60)
        """)

    def test_disappeared_aircraft_returns_nearby_passenger(self):
        self.check("""
        Config.Countdown=0;press();runUntil(3100);DeleteEntity(heli);runUntil(3160)
        assert(not entities[pilot] and entities[1].pos.z==40 and #warps==1 and #notices==1)
        """)

    def test_external_patient_movement_is_not_rolled_back(self):
        self.check("""
        Config.Countdown=0;press();runUntil(3100)
        seats[1]=nil;seatNumbers[1]=nil;entities[1].pos=vector3(1000,2000,40)
        runUntil(3160)
        assert(not entities[heli] and not entities[pilot] and #warps==0 and entities[1].pos.x==1000)
        """)

    def test_core_restart_reinstates_the_panel(self):
        self.check("""
        runUntil(16);assert(panels.rescue.state=='waiting')
        coreStarted=false;panels={};emit('onClientResourceStop','ptech_mediora_core');runUntil(32)
        coreStarted=true;emit('onClientResourceStart','ptech_mediora_core');runUntil(48)
        assert(panels.rescue.state=='waiting')
        """)

    def test_pause_and_chat_focus_cancel_hold(self):
        for focus in ('paused=true', 'focused=true'):
            with self.subTest(focus=focus):
                self.setUp()
                self.check(f"""
                Config.Countdown=0;press();runUntil(2500);{focus};runUntil(2600)
                paused=false;focused=false;runUntil(6500);assert(createdHelis==0)
                press();runUntil(9532);assert(createdHelis==1)
                """)

    def test_medical_down_state_and_real_key_assignment_work(self):
        for state in ("LocalPlayer.state.dead='dead'", "qbox=true;metadata.inlaststand=true"):
            with self.subTest(state=state):
                self.setUp()
                self.check(f"""
                dead=false;{state};Config.Countdown=0;key.currentKey='G'
                press();runUntil(1504);assert(panels.rescue.icon=='G' and panels.rescue.progress>=50)
                runUntil(3040);assert(seats[1]==heli and createdPilots==1)
                """)


if __name__ == '__main__':
    unittest.main()
