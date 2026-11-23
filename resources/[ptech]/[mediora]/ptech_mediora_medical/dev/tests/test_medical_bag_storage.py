from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'fxmanifest.lua').exists():ROOT=ROOT.parent

class MedicalBagStorageTest(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute('''
        jobs={};events={};hooks={};slots={};metadataWrites=0;weightWrites=0
        bagContents={ {name='pmediora_supplybox',count=2,metadata={deliveryId='kept'}}, {name='pmediora_tablet',count=1} }
        slots[5]={name='pmediora_medicalbag',metadata={container='saved-bag',size={24,30000},medicalBagVariant=3,imageurl='kept.png',weight=42}}
        function CreateThread(fn)jobs[#jobs+1]=fn end
        function Wait()end
        function AddEventHandler(name,fn)events[name]=fn end
        function GetResourceState()return 'started'end
        function GetConvar(_,default)return default end
        function PerformHttpRequest(url,callback,method)callback(404,'',{})end
        exports={ox_inventory={
          setContainerProperties=function(_,name,settings)assert(name=='pmediora_medicalbag');properties=settings end,
          registerHook=function(_,event,fn,options)hooks[event]=fn;return event end,
          removeHooks=function()end,
          GetSlot=function(_,source,slot)assert(source==1);return slots[slot]end,
          SetMetadata=function(_,source,slot,metadata)metadataWrites=metadataWrites+1;slots[slot].metadata=metadata end,
          SetMaxWeight=function(_,id,weight)assert(id=='saved-bag');assert(weight==1000000);weightWrites=weightWrites+1 end,
        }}
        function runJobs()while #jobs>0 do table.remove(jobs,1)()end end
        function openBag(id)hooks.openInventory({source=1,slot=5,inventoryId=id or 'saved-bag',inventoryType='container'})end
        ''')
        config='config.lua' if (ROOT/'config.lua').exists()else 'config/config.lua'
        self.lua.execute((ROOT/config).read_text(encoding='utf-8'))
        self.lua.execute((ROOT/'main/server/containers.lua').read_text(encoding='utf-8'))
        self.lua.execute('runJobs()')
    def test_one_tonne_and_only_medical_tools_or_logistics_boxes(self):
        self.lua.execute("assert(properties.slots==24 and properties.maxWeight==1000000);for name in pairs(Config.Wounds.Items)do assert(properties.whitelist[name])end;for _,name in ipairs({'pmediora_phoenixkit','pmediora_supplybox','pmediora_specialbox','pmediora_iv','pmediora_ivdrip'})do assert(properties.whitelist[name])end;for _,name in ipairs({'pmediora_tablet','pmediora_medicalbag','WEAPON_PISTOL','water','burger','pmediora_herb'})do assert(not properties.whitelist[name])end")
    def test_existing_bag_updates_capacity_and_preserves_identity_and_contents(self):
        self.lua.execute("openBag();local m=slots[5].metadata;assert(m.size[1]==24 and m.size[2]==1000000);assert(m.container=='saved-bag' and m.medicalBagVariant==3 and m.imageurl=='kept.png' and m.weight==42);assert(bagContents[1].metadata.deliveryId=='kept' and bagContents[2].name=='pmediora_tablet');assert(metadataWrites==1 and weightWrites==1);openBag();assert(metadataWrites==1 and weightWrites==2)")
    def test_other_container_or_mismatched_id_is_not_modified(self):
        self.lua.execute("openBag('wrong');assert(metadataWrites==0 and weightWrites==0);slots[5].name='otherbag';openBag();assert(metadataWrites==0 and weightWrites==0)")
    def test_custom_existing_slot_count_is_preserved(self):
        self.lua.execute("slots[5].metadata.size[1]=40;openBag();assert(slots[5].metadata.size[1]==40)")

