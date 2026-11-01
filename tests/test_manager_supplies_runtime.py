"""Read-only treatment inventory integration, using the Manager client callbacks."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'resources' / '[ptech]' / '[mediora]'


class ManagerSupplyRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((MODULE / 'ptech_mediora_medical/config/items.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
        Config={Home={Title='EMSManager'}}
        ManagerPatientView={stop=function() end}
        callbacks, events, api, messages = {}, {}, {}, {}
        slots = {
          [1]={name='ptech_mediora_icepack', count=2},
          [6]={name='ptech_mediora_icepack', count=3},
          [7]={name='ptech_mediora_tweezers', count=1},
          [8]={name='water', count=99},
          [9]={name='ptech_mediora_suturekit', count=0},
        }
        exports=setmetatable({
          ptech_mediora_medical={getTreatmentItems=function() return MedioraItems end},
          ox_inventory={GetPlayerItems=function()
            if failInventory then error('inventory not loaded') end
            return slots
          end},
        }, {__call=function(_, name, fn) api[name]=fn end})
        lib={notify=function() end, callback={await=function() return {name='Doctor'} end}}
        function GetResourceState() return 'started' end
        function RegisterNUICallback(name, fn) callbacks[name]=fn end
        function AddEventHandler(name, fn) events[name]=fn end
        function SetNuiFocus() end
        function SendNUIMessage(message) messages[#messages+1]=message end
        function readSupplies()
          local result
          callbacks.getTreatmentSupplies({}, function(data) result=data end)
          return result
        end
        ''')
        self.lua.execute((MODULE / 'ptech_mediora_manager/main/client/client.lua').read_text(encoding='utf-8'))

    def test_sums_matching_slots_and_excludes_other_or_unowned_items(self):
        self.lua.execute('''
        api.openCharts(2)
        local result=readSupplies()
        assert(#result.items == 2)
        assert(result.items[1].name == 'ptech_mediora_icepack' and result.items[1].count == 5)
        assert(result.items[2].count == 1)
        assert(slots[1].count == 2 and slots[6].count == 3)
        ''')

    def test_inventory_changes_refresh_only_while_open(self):
        self.lua.execute('''
        events['ox_inventory:updateInventory']()
        assert(#messages == 0)
        api.openCharts(2)
        slots[6]=nil
        events['ox_inventory:updateInventory']()
        local message=messages[#messages]
        assert(message.action == 'treatment:supplies')
        assert(message.data.items[1].count == 2)
        callbacks.close({}, function() end)
        local count=#messages
        events['ox_inventory:updateInventory']()
        assert(#messages == count)
        ''')

    def test_failure_is_reported_without_inventing_inventory(self):
        self.lua.execute('''
        api.openCharts(2)
        failInventory=true
        local result=readSupplies()
        assert(result.error and not result.items)
        ''')


if __name__ == '__main__':
    unittest.main()
