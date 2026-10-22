"""Lua behavior tests (requires lupa); not a FiveM physics/integration test."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MARINE = ROOT / 'resources' / '[ptech]' / '[mediora]' / 'ptech_mediora_marine'

HARNESS = r'''
callbacks, events, sent, threads, timeouts = {}, {}, {}, {}, {}
now, removed, failRemove = 1000, 0, false
local vector = {}
vector.__index = vector
function vec(x,y,z) return setmetatable({x=x,y=y,z=z}, vector) end
vector.__sub = function(a,b) return vec(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
players = {
 [1] = {ped=11, bucket=0, coords=vec(0,0,-10), count=3, state={},
        data={citizenid='a',job={name='ambulance',onduty=true},metadata={isdead=false,inlaststand=false}}},
 [2] = {ped=22, bucket=0, coords=vec(1,0,-10), count=0, state={dead='dead'},
        data={citizenid='b',job={name='unemployed',onduty=false},metadata={isdead=true,inlaststand=false}}}
}
exports = {
 qbx_core = {GetPlayer=function(_,id) return players[id] and {PlayerData=players[id].data} end},
 ox_inventory = {
   Search=function(_,id,kind,item) return players[id] and players[id].count or 0 end,
   RemoveItem=function(_,id,item,count)
     if failRemove or players[id].count < count then return false end
     players[id].count=players[id].count-count; removed=removed+count; return true
   end
 }
}
lib={callback={register=function(name,fn) callbacks[name]=fn end,
 await=function(name,id)
   if duringProbe then duringProbe() end
   local p=players[id]
   if not p then return nil end
   return observation or {water=true,x=p.coords.x,y=p.coords.y,z=p.coords.z,surface=0}
 end}}
function Player(id) return {state=players[id].state} end
function GetPlayerPed(id) return players[id] and players[id].ped or 0 end
function GetPlayerRoutingBucket(id) return players[id].bucket end
function GetPlayers()
 local ids = {}
 for id in pairs(players) do ids[#ids+1] = tostring(id) end
 return ids
end
function GetEntityCoords(ped)
 for _,p in pairs(players) do if p.ped==ped then return p.coords end end
 error('missing ped')
end
function GetVehiclePedIsIn(ped) return inVehicle and 123 or 0 end
function GetGameTimer() return now end
function TriggerClientEvent(name,id,...) sent[#sent+1]={name=name,id=id,args={...}} end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) coroutine.yield() end
function SetTimeout(ms,fn) timeouts[#timeouts+1]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function GetCurrentResourceName() return 'ptech_mediora_marine' end
function tick()
 now=now+1000
 for _,thread in ipairs(threads) do
   local ok,err=coroutine.resume(thread); if not ok then error(err) end
 end
end
function activate(src) return callbacks['ptech_mediora_marine:activateFlotation'](src) end
function fins(src) return callbacks['ptech_mediora_marine:toggleFins'](src) end
function snapshot(src) return callbacks['ptech_mediora_marine:snapshot'](src) end
'''


class MarineRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for rel in ('config/config.lua', 'main/shared/rules.lua', 'config/server.lua', 'main/server/server.lua'):
            self.lua.execute((MARINE / rel).read_text(encoding='utf-8'))

    def run_lua(self, code):
        self.lua.execute(code)

    def ready(self):
        self.run_lua('Config.Flotation.Countdown=3; tick(); tick(); for i=1,3 do tick() end')

    def test_all_marine_lua_compiles(self):
        for path in MARINE.rglob('*.lua'):
            with self.subTest(path=path.name):
                self.lua.execute('assert(load(...))', path.read_text(encoding='utf-8'))

    def test_fins_job_duty_inventory_and_revocation(self):
        self.run_lua('''
        assert(fins(1)); assert(snapshot(1).fins)
        players[1].data.job.onduty=false
        tick(); tick(); assert(not snapshot(1).fins)
        now=now+1000; assert(not fins(1))
        now=now+1000; players[1].data.job.onduty=true; players[1].count=0
        assert(not fins(1))
        now=now+1000; players[1].count=2; players[1].data.job.name='police'
        assert(not fins(1)); assert(removed==0)
        ''')

    def test_flotation_waits_for_death_countdown_and_needs_no_item(self):
        self.run_lua('''
        Config.Flotation.Countdown=3
        tick(); tick()
        assert(not activate(2)); assert(removed==0)
        for i=1,3 do tick() end
        assert(activate(2)); assert(snapshot(2).floats[2].x==1); assert(removed==0)
        ''')

    def test_countdown_runs_outside_water_and_activation_checks_current_water(self):
        self.ready()
        self.run_lua('''
        observation={water=false,x=1,y=0,z=-10,surface=0}
        assert(not activate(2)); assert(removed==0)
        now=now+1000; observation=nil
        assert(activate(2)); assert(removed==0)
        ''')

    def test_rejects_alive_busy_vehicle_and_disabled(self):
        for change in (
            "players[2].state.dead=false; players[2].data.metadata.isdead=false",
            'players[2].state.emsEscortedBy=1', 'inVehicle=true',
            'Config.Flotation.Enabled=false',
        ):
            with self.subTest(change=change):
                self.setUp()
                self.ready()
                self.run_lua(f'{change}; assert(not activate(2)); assert(removed==0)')

    def test_water_observation_validation_and_server_provider(self):
        for obs in (
            '{water=false,x=1,y=0,z=-10,surface=0}',
            '{water=true,x=100,y=0,z=-10,surface=0}',
            '{water=true,x=1,y=0,z=-10,surface=0/0}',
            '{water=true,x=1,y=0,z=-10,surface=1000}',
            '{water=true,x=1,y=0,z=-10,surface=-20}',
        ):
            with self.subTest(observation=obs):
                self.setUp()
                self.ready()
                self.run_lua(f'observation={obs}; assert(not activate(2)); assert(removed==0)')
        self.setUp()
        self.ready()
        self.run_lua('MarineServer.WaterHeight=function() return nil end; assert(not activate(2)); assert(removed==0)')

    def test_revalidation_after_water_observation(self):
        for change in (
            'players[2].state.emsEscortedBy=1', 'players[2].ped=33',
            "players[2].data.citizenid='replacement'", 'players[2].bucket=1',
            "players[2].state.dead=false; players[2].data.metadata.isdead=false", 'players[2]=nil',
        ):
            with self.subTest(change=change):
                self.setUp()
                self.ready()
                self.run_lua(f'duringProbe=function() {change} end; assert(not activate(2)); assert(removed==0)')

    def test_pending_request_and_repeat_activation_are_rejected(self):
        self.ready()
        self.run_lua('''
        duringProbe=function() assert(not activate(2)) end
        assert(activate(2)); assert(removed==0)
        now=now+1000; assert(not activate(2))
        ''')

    def test_escort_clears_float_and_next_death_resets_countdown(self):
        self.ready()
        self.run_lua('''
        assert(activate(2)); players[2].state.emsEscortedBy=1; tick()
        assert(not snapshot(2).floats[2])
        players[2].state.emsEscortedBy=nil; now=now+1000; assert(not activate(2))
        players[2].state.dead=false; players[2].data.metadata.isdead=false; tick()
        players[2].state.dead='dead'; players[2].data.metadata.isdead=true
        tick(); for i=1,2 do tick() end; assert(not activate(2))
        tick(); assert(activate(2)); assert(removed==0)
        ''')

    def test_revive_disconnect_ped_and_bucket_changes_clear_float(self):
        for change in (
            "players[2].state.dead=false; players[2].data.metadata.isdead=false",
            'players[2].bucket=3', 'players[2].ped=33',
            "players[2].data.citizenid='new'", 'inVehicle=true',
            'source=2; events.playerDropped()',
        ):
            with self.subTest(change=change):
                self.setUp()
                self.ready()
                self.run_lua(f'assert(activate(2)); {change}; tick(); assert(not snapshot(2).floats[2]); assert(removed==0)')


CLIENT_HARNESS = r'''
clientExports, movement, speed, componentWrites, markers, objects = {}, {}, {}, {}, {}, {}
propCreates, propDeletes, activationCalls = 0, 0, 0
source, ped, model, drawable, texture, palette = 65535, 11, 100, 4, 2, 1
swimming, attached, vehicle, localDead, inWater, keyHeld = false, false, false, true, true, false
ui, uiLog, activationResult = nil, {}, true
LocalPlayer = {state={dead='dead'}}
setmetatable(exports, {__call=function(_,name,fn) clientExports[name]=fn end})
lib.notify=function() end
lib.showTextUI=function(text) ui=text; uiLog[#uiLog+1]=text end
lib.hideTextUI=function() ui=nil end
lib.callback.await=function(name)
 if name=='ptech_mediora_marine:snapshot' then return {floats={},fins=false,revision=0} end
 if name=='ptech_mediora_marine:activateFlotation' then activationCalls=activationCalls+1; return activationResult end
end
function RegisterNetEvent(name,fn) events[name]=fn end
function PlayerPedId() return ped end
function PlayerId() return 1 end
function GetPlayerServerId(player) return player end
function GetPlayerFromServerId(id) return id==1 and 1 or -1 end
function GetPlayerPed(player) return ped end
function GetEntityModel(entity) return model end
function joaat(name) return 100 end
function GetPedDrawableVariation() return drawable end
function GetPedTextureVariation() return texture end
function GetPedPaletteVariation() return palette end
function GetNumberOfPedDrawableVariations() return 100 end
function GetNumberOfPedTextureVariations() return 10 end
function SetPedComponentVariation(p,c,d,t,pal)
 drawable,texture,palette=d,t,pal; componentWrites[#componentWrites+1]={d,t,pal}
end
function SetSwimMultiplierForPlayer(player,mult) speed[#speed+1]=mult end
function IsPedSwimming() return swimming end
function IsPedSwimmingUnderWater() return swimming end
function IsEntityAttached() return attached end
function IsPedInAnyVehicle() return vehicle end
function IsEntityDead() return localDead end
function IsEntityInWater() return inWater end
function IsControlPressed() return keyHeld end
function GetWaterHeightNoWaves() return true,0 end
function GetResourceState() return 'started' end
function GetFrameTime() return 0.05 end
function SetEntityVelocity() end
function SetEntityCoordsNoOffset(entity,x,y,z)
 movement[#movement+1]={x=x,y=y,z=z}; players[1].coords=vec(x,y,z)
end
function DrawMarker() markers[#markers+1]=true end
function DoesEntityExist(entity)
 for _,p in pairs(players) do if p.ped==entity then return true end end
 return objects[entity] ~= nil
end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function HasModelLoaded() return true end
function RequestModel() end
function CreateObjectNoOffset(model,x,y,z)
 propCreates=propCreates+1; local entity=1000+propCreates; objects[entity]={model=model,x=x,y=y,z=z}; return entity
end
function SetEntityCollision() end
function SetEntityInvincible() end
function SetEntityAsMissionEntity() end
function GetPedBoneIndex(_,bone) return bone end
function AttachEntityToEntity(entity,target) objects[entity].target=target end
function SetModelAsNoLongerNeeded() end
function DeleteEntity(entity) if objects[entity] then objects[entity]=nil; propDeletes=propDeletes+1 end end
function step(index)
 local ok,err=coroutine.resume(threads[index]); assert(ok,err)
end
function enableFins(rev) events['ptech_mediora_marine:fins'](true,rev or 1) end
function disableFins(rev) events['ptech_mediora_marine:fins'](false,rev or 2) end
function deploy()
 events['ptech_mediora_marine:flotation'](1,{x=0,y=0,z=-10,surface=-0.2,ticket=1},1)
end
'''


class MarineClientTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        self.lua.execute(CLIENT_HARNESS)
        for rel in ('config/config.lua', 'main/shared/rules.lua', 'main/client/client.lua'):
            self.lua.execute((MARINE / rel).read_text(encoding='utf-8'))

    def test_swim_only_speed_and_original_shoes_restored(self):
        self.lua.execute('''
        Config.Fins.Appearance={mp_m_freemode_01={drawable=20,texture=0}}
        enableFins(); assert(drawable==20)
        step(3); step(3); assert(#speed==0)
        swimming=true; step(3); assert(speed[#speed]==1.35)
        swimming=false; step(3); assert(speed[#speed]==1.0)
        disableFins(); assert(drawable==4 and texture==2 and palette==1)
        ''')

    def test_external_clothing_and_ped_changes_are_preserved(self):
        self.lua.execute('''
        Config.Fins.Appearance={mp_m_freemode_01={drawable=20}}
        enableFins(); drawable=35; disableFins(); assert(drawable==35)
        enableFins(3); ped=99; disableFins(4); assert(drawable==20)
        ''')

    def test_no_model_and_invalid_model_leave_shoes_intact(self):
        self.lua.execute('''
        enableFins(); assert(#componentWrites==0)
        disableFins()
        Config.Fins.Appearance={mp_m_freemode_01={drawable=500}}
        enableFins(3); assert(#componentWrites==0)
        ''')

    def test_countdown_is_shown_from_death_and_f_only_works_in_water(self):
        self.lua.execute('''
        Config.Flotation.Countdown=3
        step(2); step(2); assert(ui:find('0:03'))
        now=now+3000; inWater=false; step(2)
        assert(ui:find('水中でのみ'))
        keyHeld=true; now=now+1000; step(2); assert(activationCalls==0)
        inWater=true; step(2); now=now+1000; step(2); assert(activationCalls==1)
        ''')

    def test_f_long_press_waits_for_hold_duration(self):
        self.lua.execute('''
        Config.Flotation.Countdown=0; Config.Flotation.HoldDuration=1.0
        step(2); step(2); keyHeld=true; step(2)
        now=now+999; step(2); assert(activationCalls==0)
        now=now+1; step(2); assert(activationCalls==1)
        ''')

    def test_float_is_gradual_xy_fixed_and_stops_at_surface(self):
        self.lua.execute('''
        Config.Flotation.Marker=false
        deploy(); step(3); step(3)
        assert(#movement==1)
        assert(movement[1].z > -10 and movement[1].z < -9.9)
        players[1].coords=vec(100,200,-15)
        for i=1,500 do step(3) end
        local last=movement[#movement]
        assert(last.x==0 and last.y==0 and last.z==-0.2)
        assert(LocalPlayer.state.dead=='dead')
        ''')

    def test_float_visual_is_local_and_cleans_up_with_the_effect(self):
        self.lua.execute('''
        Config.Flotation.Marker=false
        deploy(); step(3); step(3)
        assert(propCreates==1)
        events['ptech_mediora_marine:flotation'](1,nil,2)
        assert(propDeletes==1)
        ''')

    def test_escort_attach_or_vehicle_yields_without_resuming_ticket(self):
        for condition in ('attached=true', 'vehicle=true', 'LocalPlayer.state.emsEscortedBy=2'):
            with self.subTest(condition=condition):
                self.setUp()
                self.lua.execute(f'''
                Config.Flotation.Marker=false
                deploy(); step(3); step(3); local count=#movement
                {condition}; step(3); assert(#movement==count)
                attached=false; vehicle=false; LocalPlayer.state.emsEscortedBy=nil
                step(3); assert(#movement==count)
                ''')

    def test_stop_and_server_release_leave_no_movement(self):
        self.lua.execute('''
        Config.Flotation.Marker=false
        enableFins(); deploy(); step(3); step(3)
        events['ptech_mediora_marine:flotation'](1,nil,2)
        step(3); local count=#movement
        step(3); assert(#movement==count)
        events.onResourceStop('ptech_mediora_marine')
        step(3); assert(#movement==count)
        ''')

    def test_local_events_and_stale_initial_snapshot_cannot_reenable(self):
        self.lua.execute('''
        source=1; enableFins(); assert(#componentWrites==0)
        source=65535; disableFins(2)
        events['ptech_mediora_marine:flotation'](1,nil,3)
        lib.callback.await=function()
          return {revision=1,fins=true,floats={[1]={x=0,y=0,z=-10,surface=0,ticket=1}}}
        end
        step(1); step(3); step(3)
        assert(#movement==0 and #speed==0)
        ''')


if __name__ == '__main__':
    unittest.main()
