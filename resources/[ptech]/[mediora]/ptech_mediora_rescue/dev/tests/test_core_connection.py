"""Connect Rescue to Core's actual Lua exports, then feed the result to Core's actual UI."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

from lupa.lua54 import LuaRuntime
from test_rescue import COMMON
from test_pickup import HARNESS

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT.parent / 'ptech_mediora_core'

BRIDGE = """
coreExports,nuiCallbacks,nuiMessages={},{},{}
setmetatable(exports,{__call=function(_,name,fn) coreExports[name]=fn end})
function RegisterNUICallback(name,fn) nuiCallbacks[name]=fn end
function SendNUIMessage(value) nuiMessages[#nuiMessages+1]=value end
function GetResourceKvpString() return nil end
function DisableControlAction() end
function IsDisabledControlJustPressed() return false end
function SetTimeout(ms,fn) CreateThread(function() Wait(ms);fn() end) end
coreEnv=setmetatable({Config={},GetCurrentResourceName=function() return 'ptech_mediora_core' end},{__index=_G})
function loadCore(code) return assert(load(code,'@ptech_mediora_core/main/client/action_panel.lua','t',coreEnv))() end
function connectCore()
    exports.ptech_mediora_core={
        setActionPanel=function(_,value) return coreExports.setActionPanel(value) end,
        removeActionPanel=function(_,id) return coreExports.removeActionPanel(id) end,
    }
end
function ready()
    nuiMessages={}
    nuiCallbacks.actionPanelReady({},function(value) readyReply=value end)
    assert(readyReply.ok)
end
function rescuePanel()
    for _,message in ipairs(nuiMessages) do
        if message.action=='setPanel' and message.id=='rescue' then return message.panel end
    end
end
"""


class CoreConnectionTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(COMMON + HARNESS + BRIDGE)
        self.lua.globals().loadCore((CORE / 'main/client/action_panel.lua').read_text(encoding='utf-8'))
        self.lua.execute('connectCore()')
        self.lua.execute((ROOT / 'config.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT / 'main/client/client.lua').read_text(encoding='utf-8'))

    def test_browser_ready_retries_until_core_callback_is_registered(self):
        result = subprocess.run(
            [shutil.which('node'), str(ROOT / 'dev/tests/check_core_ready.js'), str(CORE / 'main/ui/app.js')],
            text=True, encoding='utf-8', capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_death_panel_registered_before_ui_ready_is_replayed_and_visible(self):
        self.lua.execute("""
        runUntil(16);ready()
        local panel=rescuePanel()
        assert(panel and panel.state=='waiting' and panel.text:find('5:00'),
            'Core must replay the registered death panel when its UI becomes ready')
        assert(panel.temporaryExpand and panel.progress==0)
        """)
        panel = dict(self.lua.globals().rescuePanel().items())
        result = subprocess.run(
            [shutil.which('node'), str(ROOT / 'dev/tests/check_rescue_sidebar.js'), str(CORE / 'main/ui/app.js')],
            input=json.dumps([panel]), text=True, encoding='utf-8', capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ui_reload_replays_even_without_any_new_rescue_update(self):
        self.lua.execute("""
        ready();runUntil(16);ready()
        assert(rescuePanel(),'first UI reload must restore the death panel')
        ready()
        assert(rescuePanel(),'replay cannot depend on a new countdown value')
        """)

    def test_patient_recovery_before_ui_ready_does_not_replay_stale_panel(self):
        self.lua.execute("""
        runUntil(16);dead=false;runUntil(32);ready()
        assert(not rescuePanel(),'a removed patient panel must not return on UI ready')
        """)

    def test_panel_registration_order_and_latest_value_are_preserved(self):
        self.lua.execute("""
        coreExports.setActionPanel({id='first',text='first'})
        coreExports.setActionPanel({id='second',text='second'})
        coreExports.setActionPanel({id='first',text='updated'})
        ready()
        local received={}
        for _,message in ipairs(nuiMessages) do
            if message.action=='setPanel' then received[#received+1]=message end
        end
        assert(#received==2 and received[1].id=='first' and received[1].panel.text=='updated')
        assert(received[2].id=='second')
        """)

    def test_removed_panel_can_be_registered_again(self):
        self.lua.execute("""
        coreExports.setActionPanel({id='first',text='old'})
        coreExports.removeActionPanel('first')
        coreExports.setActionPanel({id='second',text='second'})
        coreExports.setActionPanel({id='first',text='new'})
        ready()
        local received={}
        for _,message in ipairs(nuiMessages) do
            if message.action=='setPanel' then received[#received+1]=message end
        end
        assert(#received==2 and received[1].id=='second' and received[2].panel.text=='new')
        """)


if __name__ == '__main__':
    unittest.main()
