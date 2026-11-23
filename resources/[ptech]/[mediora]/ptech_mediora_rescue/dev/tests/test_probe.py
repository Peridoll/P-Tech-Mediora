"""Run the isolated probe's real client/server scripts over a mocked event bus."""
from pathlib import Path
import re
import unittest

from lupa.lua54 import LuaRuntime
from test_rescue import COMMON

PROBE = Path(__file__).resolve().parents[2]

HARNESS = """
local prefix='ptech_mediora_rescue:boarding:'
serverEvents,clientEvents,commands,clientCommands,logs,notices={},{},{},{},{},{}
entities,seats = {[1]={coords=vector3(10,20,40),bucket=0}},{}
nextEntity,allowed,modelValid,modelReadyAt,streamAt,canBoard,hasControl=100,true,true,0,0,true,true
health,localCreates,serverCreates,boardAttempts=100,0,0,0
function log(value) logs[#logs+1]=value end
function SetTimeout(ms,fn) CreateThread(function() Wait(ms);fn() end) end
function send(events,env,sourceId,name,...)
    local args={...}
    CreateThread(function() env.source=sourceId;assert(events[name],name);events[name](table.unpack(args)) end)
end
function entityExists(id) return entities[id]~=nil and clock>=(entities[id].ready or 0) end
function clientExists(id)
    return entityExists(id) and (not entities[id].server or clock>=streamAt)
end
function position(id) return entities[seats[id] or id].coords end
function makeEntity(x,y,z,server)
    nextEntity=nextEntity+1
    entities[nextEntity]={coords=vector3(x,y,z),server=server,bucket=0,ready=clock+(spawnDelay or 0)}
    return nextEntity
end
function delete(id) entities[id]=nil end
function teleport(id,x,y,z) seats[id]=nil;entities[id].coords=vector3(x,y,z) end
local shared={
    GetGameTimer=GetGameTimer,Wait=Wait,CreateThread=CreateThread,SetTimeout=SetTimeout,
    joaat=joaat,print=log,GetCurrentResourceName=function() return 'ptech_mediora_rescue' end,
    GetEntityCoords=position,GetEntityHeading=function() return 90 end,
    GetVehiclePedIsIn=function(id) return seats[id] or 0 end,
    FreezeEntityPosition=function(id,value) entities[id].frozen=value end,
    DeleteEntity=delete,
}
server=setmetatable({}, {__index=function(_,key) return shared[key] or _G[key] end})
client=setmetatable({}, {__index=function(_,key) return shared[key] or _G[key] end})
server.RegisterCommand=function(name,fn) commands[name]=fn end
server.RegisterNetEvent=function(name,fn) serverEvents[name]=fn end
server.AddEventHandler=server.RegisterNetEvent
server.DoesEntityExist=entityExists
server.IsPlayerAceAllowed=function() return allowed end
server.GetPlayerPed=function() return 1 end
server.GetPlayerRoutingBucket=function() return playerBucket or 0 end
server.GetEntityRoutingBucket=function(id) return entities[id].bucket end
server.SetEntityRoutingBucket=function(id,bucket) entities[id].bucket=bucket end
server.SetEntityOrphanMode=function(id,mode) entities[id].orphan=mode end
server.NetworkGetEntityOwner=function(id) return clock>=streamAt and 1 or -1 end
server.NetworkGetNetworkIdFromEntity=function(id) return id+5000 end
server.CreateVehicleServerSetter=function(_,_,x,y,z)
    serverCreates=serverCreates+1
    return makeEntity(x,y,z,true)
end
server.SetEntityCoords=teleport
server.TriggerClientEvent=function(name,target,...)
    if name=='ox_lib:notify' then notices[#notices+1]=(...);return end
    send(clientEvents,client,65535,name,...)
end
client.RegisterCommand=function(name,fn) clientCommands[name]=fn end
client.RegisterNetEvent=function(name,fn) clientEvents[name]=fn end
client.AddEventHandler=client.RegisterNetEvent
client.TriggerServerEvent=function(name,...)
    if dropClientRequests then return end
    send(serverEvents,server,1,name,...)
end
client.PlayerPedId=function() return 1 end
client.DoesEntityExist=clientExists
client.IsModelInCdimage=function() return modelValid end
client.IsModelValid=function() return modelValid end
client.IsThisModelAHeli=function() return modelValid end
client.RequestModel=function() modelRequested=true end
client.HasModelLoaded=function() return modelRequested and clock>=modelReadyAt end
client.SetModelAsNoLongerNeeded=function() released=(released or 0)+1 end
client.CreateVehicle=function(_,x,y,z,_,networked)
    assert(not networked,'local test must not create a network vehicle')
    assert(modelRequested and clock>=modelReadyAt,'model must be loaded first')
    localCreates=localCreates+1
    return makeEntity(x,y,z,false)
end
client.NetworkDoesEntityExistWithNetworkId=function(net) return clientExists(net-5000) end
client.NetworkGetEntityFromNetworkId=function(net)
    assert(clientExists(net-5000),'unstreamed network lookup');return net-5000
end
client.NetworkHasControlOfEntity=function() return hasControl end
client.NetworkRequestControlOfEntity=function() end
client.SetEntityAsMissionEntity=function(id) entities[id].mission=true end
client.SetEntityCollision=function(id,value) entities[id].collision=value end
client.SetEntityInvincible=function(id,value) entities[id].invincible=value end
client.SetPedIntoVehicle=function(ped,vehicle,seat)
    boardAttempts=boardAttempts+1;assert(seat==0)
    if canBoard then seats[ped]=vehicle end
end
client.GetEntityHealth=function() return health end
client.ClearPedTasksImmediately=function(id) seats[id]=nil end
client.SetEntityCoordsNoOffset=teleport
client.SetEntityHeading=function() end
client.lib={notify=function(notice) notices[#notices+1]=notice end}
function command(mode) commands.rescueheli(1,mode and {mode} or {}) end
function hasLog(text)
    for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end
    return false
end
function emitClient(name,...) send(clientEvents,client,65535,prefix..name,...) end
function emitServer(name,...) send(serverEvents,server,1,prefix..name,...) end
"""


class ProbeTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + HARNESS)
        for side in ["server", "client"]:
            for name in ["config.lua", "main/shared/boarding.lua", f"main/{side}/boarding.lua"]:
                self.lua.execute("assert(load(..., 'probe', 't', " + side + "))()",
                                 (PROBE / name).read_text(encoding="utf-8"))

    def check(self, script):
        self.lua.execute(script)

    def test_local_model_load_board_and_hold_without_flight(self):
        self.check("""
        modelReadyAt=500;command('local');runUntil(400)
        assert(localCreates==0 and serverCreates==0 and not seats[1])
        runUntil(3000)
        assert(localCreates==1 and serverCreates==0 and boardAttempts==1 and seats[1]==101)
        assert(entities[101].frozen and entities[101].mission and health==100)
        assert(hasLog('MODEL_OK') and hasLog('ENTITY_OK') and hasLog('BOARD_STABLE'))
        command('clear');runUntil(3200)
        assert(not entities[101] and not seats[1] and position(1).z==40 and health==100)
        """)

    def test_server_mode_uses_same_loading_and_boarding_after_replication(self):
        self.check("""
        streamAt=1500;command('server');runUntil(1000)
        assert(serverCreates==1 and localCreates==0 and not seats[1])
        runUntil(4000)
        assert(seats[1]==101 and hasLog('SERVER_SNAPSHOT') and hasLog('BOARD_STABLE'))
        command('clear');runUntil(4200)
        assert(not entities[101] and position(1).z==40)
        """)

    def test_replication_failure_keeps_server_entity_for_inspection(self):
        self.check("""
        streamAt=100000;command('server');runUntil(12000)
        assert(entities[101] and not seats[1] and boardAttempts==0)
        assert(hasLog('MODEL_OK') and hasLog('ENTITY_MISSING') and hasLog('exists=true owner=-1'))
        assert(not hasLog('BOARD_OK'))
        command('clear');runUntil(12200);assert(not entities[101])
        """)

    def test_seat_loss_is_reported_without_deleting_heli_or_reviving(self):
        self.check("""
        health=0;command('local');runUntil(500)
        entities[1].coords=position(1);seats[1]=nil
        runUntil(800)
        assert(hasLog('SEAT_LOST') and entities[101] and not seats[1])
        assert(position(1).z==40 and health==0)
        """)

    def test_invalid_or_unloaded_model_never_creates_vehicle(self):
        for change, label in [("modelValid=false", "MODEL_INVALID"),
                              ("modelReadyAt=100000", "MODEL_TIMEOUT")]:
            with self.subTest(label=label):
                self.setUp()
                self.check(f"""
                {change};command('local');runUntil(6000)
                assert(hasLog('{label}') and localCreates==0 and serverCreates==0)
                command('clear');runUntil(6200)
                """)

    def test_failed_board_keeps_heli_and_reports_actual_stage(self):
        self.check("""
        canBoard=false;command('local');runUntil(3000)
        assert(entities[101] and hasLog('BOARD_FAIL') and not hasLog('BOARD_OK'))
        assert(boardAttempts==1 and position(1).z==40)
        """)

    def test_command_permissions_and_duplicate_runs(self):
        self.check("""
        allowed=false;command('local');runUntil(100)
        assert(localCreates==0 and serverCreates==0)
        allowed=true;command();runUntil(500)
        command('server');runUntil(800)
        assert(localCreates==1 and serverCreates==0,'clear must be explicit before next run')
        allowed=false;command('clear');runUntil(1000)
        assert(not entities[101],'own cleanup must remain available after permission changes')
        """)

    def test_clearing_during_model_loading_cancels_creation(self):
        self.check("""
        modelReadyAt=2000;command('local');runUntil(500)
        command('clear');runUntil(3000)
        assert(localCreates==0 and serverCreates==0 and released==1)
        """)

    def test_clear_during_server_creation_removes_late_entity(self):
        self.check("""
        spawnDelay=800;command('server');runUntil(200)
        command('clear');runUntil(1500)
        assert(not entities[101] and not seats[1])
        assert(not hasLog('BOARD_OK'))
        """)

    def test_cleanup_does_not_override_external_teleport(self):
        self.check("""
        command('local');runUntil(500)
        seats[1]=nil;entities[1].coords=vector3(1000,1000,50)
        command('clear');runUntil(800)
        assert(not entities[101] and position(1).x==1000 and position(1).z==50)
        """)

    def test_resource_stop_returns_passenger_and_deletes_local_heli(self):
        self.check("""
        command('local');runUntil(500)
        clientEvents.onClientResourceStop('ptech_mediora_rescue');runUntil(800)
        assert(not entities[101] and not seats[1] and position(1).z==40)
        """)

    def test_client_command_reaches_server_and_boards_player(self):
        self.check("""
        clientCommands.rescueheli(0,{'local'});runUntil(2500)
        assert(hasLog('CLIENT_READY') and hasLog('SERVER_READY'))
        assert(hasLog('COMMAND mode=local') and hasLog('SERVER_ACK') and hasLog('START_RECEIVED'))
        assert(hasLog('BOARD_STABLE') and seats[1]==101)
        clientCommands.rescueheli(0,{'clear'});runUntil(2800)
        assert(not entities[101] and not seats[1])
        """)

    def test_client_command_reports_missing_server_handler(self):
        self.check("""
        dropClientRequests=true
        clientCommands.rescueheli(0,{'local'});runUntil(5500)
        assert(hasLog('COMMAND mode=local') and hasLog('NO_SERVER_REPLY'))
        assert(localCreates==0 and serverCreates==0)
        assert(notices[#notices].type=='error')
        """)

    def test_client_command_does_not_bypass_server_permission(self):
        self.check("""
        allowed=false
        clientCommands.rescueheli(0,{'local'});runUntil(1000)
        assert(hasLog('SERVER_ACK') and hasLog('SERVER_FEEDBACK kind=error'))
        assert(localCreates==0 and serverCreates==0)
        """)

    def test_probe_manifest_paths_and_lua_syntax(self):
        manifest = (PROBE / "fxmanifest.lua").read_text(encoding="utf-8")
        active = "\n".join(line for line in manifest.splitlines() if not line.lstrip().startswith("--"))
        self.assertIn("client_scripts { 'main/client/client.lua' }", active)
        self.assertNotIn("boarding.lua", active)
        self.assertIn("server_scripts { 'main/server/pickup_test.lua' }", active)
        for name in re.findall(r"'([^']+\.lua)'", manifest):
            if not name.startswith("@"):
                self.assertTrue((PROBE / name).is_file(), name)
        for path in PROBE.rglob("*.lua"):
            self.lua.execute("assert(load(...))", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
