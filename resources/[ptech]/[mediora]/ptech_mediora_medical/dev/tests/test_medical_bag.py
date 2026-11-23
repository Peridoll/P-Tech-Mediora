from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime
import test_wounds

ROOT=Path(__file__).resolve().parents[2]

class MedicalBagTest(unittest.TestCase):
    def test_container_registration_and_inventory_restart(self):
        lua=LuaRuntime()
        lua.execute('''
        jobs={}; events={}; calls={}; attempts=0; fail=false
        function CreateThread(fn) jobs[#jobs+1]=fn end
        function AddEventHandler(name,fn) events[name]=fn end
        function Wait() end
        function GetResourceState() return 'started' end
        exports={ox_inventory={setContainerProperties=function(_,name,settings)
            attempts=attempts+1
            if fail then fail=false error('not ready') end
            assert(name=='pmediora_medicalbag')
            calls[#calls+1]=settings
        end,
        registerHook=function(_,event,fn,options)
            if event=='openInventory' then assert(options.typeFilter.container);return 'capacity-hook' end
            assert(event=='createItem' and options.itemFilter.pmediora_medicalbag)
            appearance=fn;return 'bag-hook'
        end,
        removeHooks=function(_,id) assert(id=='bag-hook' or id=='capacity-hook') end}}
        function GetConvar(_,default) return default end
        function PerformHttpRequest(url,callback,method) callback(404,'',{}) end
        function runJobs()
            while #jobs>0 do local fn=table.remove(jobs,1);fn() end
        end
        ''')
        lua.execute((ROOT/'config.lua').read_text(encoding='utf-8'))
        lua.execute((ROOT/'main/server/containers.lua').read_text(encoding='utf-8'))
        lua.execute('''
        runJobs()
        assert(#calls==1 and calls[1].slots==24 and calls[1].maxWeight==1000000)
        for name in pairs(Config.Wounds.Items) do assert(calls[1].whitelist[name]) end
        assert(not calls[1].whitelist.pmediora_tablet);assert(calls[1].whitelist.pmediora_supplybox and calls[1].whitelist.pmediora_specialbox and calls[1].whitelist.pmediora_phoenixkit)
        assert(not calls[1].whitelist.pmediora_medicalbag and not calls[1].whitelist.WEAPON_PISTOL)
        events.onResourceStart('unrelated');runJobs();assert(#calls==1)
        fail=true;events.onResourceStart('ox_inventory');runJobs()
        assert(#calls==2 and attempts==3,'retry inventory restart before exports are ready')
        ''')

    def test_install_item_is_nonstacking_nonconsumable_and_has_no_custom_use(self):
        lua=LuaRuntime()
        items=lua.execute('return {\n'+(ROOT/'install/ox_inventory/items.lua').read_text(encoding='utf-8')+'\n}')
        bag=items['pmediora_medicalbag']
        self.assertFalse(bag['stack'])
        self.assertEqual(bag['consume'],0)
        self.assertFalse(bag['close'])
        self.assertIsNone(bag['client']['export'])
        self.assertTrue(bag['client']['image'].startswith('https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/'))

    def test_medkit30_adds_only_one_missing_bag_and_never_duplicates(self):
        case=test_wounds.ServerTest()
        case.setUp()
        case.lua.execute('''
        local counts={pmediora_tablet=1,pmediora_phoenixkit=30};local added=0
        for name,item in pairs(Config.Wounds.Items) do
            if not item.suppressFracture and not item.suppressBleeding then counts[name]=30 end
        end
        exports.ox_inventory.GetInventoryItems=function()
            local items={};for name,count in pairs(counts) do items[#items+1]={name=name,count=count} end
            return items
        end
        exports.ox_inventory.CanCarryItem=function() return true end
        exports.ox_inventory.AddItem=function(_,src,name,count)
            assert(name=='pmediora_medicalbag' and count==1)
            counts[name]=(counts[name] or 0)+count;added=added+count;return true
        end
        commands.medkit30(1)
        assert(added==1 and counts.pmediora_medicalbag==1)
        commands.medkit30(1)
        assert(added==1,'existing bag is not added again')
        counts.pmediora_medicalbag=3
        commands.medkit30(1)
        assert(added==1 and counts.pmediora_medicalbag==3)
        ''')
