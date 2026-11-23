"""Exercise the active teleport script with the real Lua scheduler and mocked natives."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime
from test_rescue import COMMON

ROOT = Path(__file__).resolve().parents[2]

HARNESS = """
ped,dead,paused,focused,keepInput=1,false,false,false,false
positions={[1]=vector3(10,20,40),[2]=vector3(30,50,60)}
LocalPlayer={state={dead=false}}
metadata={};qbox=false;health=0
warps,logs={},{}
function print(value) logs[#logs+1]=value end
function PlayerPedId() return ped end
function IsEntityDead() return dead end
function GetResourceState() return qbox and 'started' or 'missing' end
exports={qbx_core={GetPlayerData=function() return {metadata=metadata} end}}
function GetEntityCoords(id) return positions[id] end
function SetEntityCoordsNoOffset(id,x,y,z,tasks,ik,warp)
    assert(tasks and ik and warp,'preserve tasks and use direct warp')
    warps[#warps+1]={ped=id,x=x,y=y,z=z,time=clock}
    positions[id]=vector3(x,y,z)
end
function IsPauseMenuActive() return paused end
function IsNuiFocused() return focused end
function IsNuiFocusKeepingInput() return keepInput end
lib={addKeybind=function(opts)
    key=opts;key.isPressed=false;key.currentKey='R'
    key.isControlPressed=function(self) return self.isPressed end
    return key
end}
function press() key.isPressed=true end
function release() key.isPressed=false;key.onReleased() end
function SetTextFont() end
function SetTextScale() end
function SetTextColour() end
function SetTextOutline() end
function BeginTextCommandDisplayText() end
function AddTextComponentSubstringPlayerName(value) hint=value end
function EndTextCommandDisplayText() end
function DrawRect() end
"""


class TeleportTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + HARNESS)
        self.lua.execute((ROOT / 'main/client/teleport.lua').read_text(encoding='utf-8'))

    def test_alive_cannot_teleport(self):
        self.lua.execute('press();runUntil(4000);assert(#warps==0 and hint==nil)')

    def test_dead_hold_completes_at_three_seconds_and_keeps_death_state(self):
        self.lua.execute("""
        dead=true;LocalPlayer.state.dead='dead';press()
        runUntil(2999);assert(#warps==0)
        runUntil(3000);assert(#warps==1)
        assert(positions[1].x==10 and positions[1].y==20 and positions[1].z==60)
        assert(dead and LocalPlayer.state.dead=='dead' and health==0)
        assert(logs[1]:find('READY') and logs[2]:find('TELEPORT'))
        runUntil(12000);assert(#warps==1,'holding must not repeat')
        release();press();runUntil(15001);assert(#warps==2 and positions[1].z==80)
        """)

    def test_releasing_restarts_the_full_hold(self):
        self.lua.execute("""
        dead=true;press();runUntil(2000);release();runUntil(2100);press()
        runUntil(5100);assert(#warps==0)
        runUntil(5101);assert(#warps==1)
        """)

    def test_ped_change_restarts_the_full_hold(self):
        self.lua.execute("""
        dead=true;press();runUntil(2000);ped=2
        runUntil(5000);assert(#warps==0)
        runUntil(5001);assert(#warps==1 and warps[1].ped==2 and positions[2].z==80)
        """)

    def test_death_ending_cancels_the_hold(self):
        self.lua.execute("""
        dead=true;press();runUntil(2000);dead=false;runUntil(5000)
        assert(#warps==0)
        dead=true;runUntil(7999);assert(#warps==0)
        runUntil(8001);assert(#warps==1)
        """)

    def test_local_state_and_qbox_metadata_support_medical_down_state(self):
        for signal in ('true', '1', '2', "'dead'", "'laststand'"):
            with self.subTest(signal=signal):
                self.setUp()
                self.lua.execute(f'LocalPlayer.state.dead={signal};press();runUntil(3000);assert(#warps==1)')
        for flag in ('isdead', 'inlaststand'):
            with self.subTest(metadata=flag):
                self.setUp()
                self.lua.execute(f'qbox=true;metadata.{flag}=true;press();runUntil(3000);assert(#warps==1)')

    def test_menu_and_chat_focus_cancel_hold_without_phantom_keypress(self):
        for focus in ('paused=true', 'focused=true'):
            with self.subTest(focus=focus):
                self.setUp()
                self.lua.execute(f"""
                dead=true;press();runUntil(2500);{focus};runUntil(2600)
                paused=false;focused=false;runUntil(6500);assert(#warps==0)
                press();runUntil(9501);assert(#warps==1)
                """)

    def test_manifest_loads_only_pickup_config_and_old_help_commands_are_disabled(self):
        self.lua.execute("""
        loaded={};servers={};deps={}
        function fx_version() end;function game() end;function lua54() end
        function author() end;function description() end;function version() end
        function shared_script(value) loaded[#loaded+1]=value end
        function client_script(value) loaded[#loaded+1]=value end
        function server_script(value) servers[#servers+1]=value end
        function shared_scripts(values) for _,v in ipairs(values) do shared_script(v) end end
        function client_scripts(values) for _,v in ipairs(values) do client_script(v) end end
        function server_scripts(values) for _,v in ipairs(values) do server_script(v) end end
        function dependency(value) deps[#deps+1]=value end
        function dependencies(values) for _,v in ipairs(values) do dependency(v) end end
        Config={Points={manualGrantCommand='mpgrant',maxChangePerTransaction=1000}}
        """)
        self.lua.execute((ROOT / 'fxmanifest.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT.parent / 'ptech_mediora_core/config/command_help.lua').read_text(encoding='utf-8'))
        self.lua.execute("""
        assert(#loaded==3 and loaded[1]=='@ox_lib/init.lua' and loaded[2]=='config.lua' and loaded[3]=='main/client/client.lua')
        assert(#servers==1 and servers[1]=='main/server/pickup_test.lua')
        assert(#deps==4 and deps[1]=='ox_lib' and deps[2]=='ptech_mediora_core' and deps[3]=='qbx_core' and deps[4]=='/onesync')
        for _,cmd in ipairs(Config.CommandHelp.commands) do
            assert(cmd.name~='rescueheli' and cmd.name~='rescueskip')
        end
        """)


if __name__ == '__main__':
    unittest.main()
