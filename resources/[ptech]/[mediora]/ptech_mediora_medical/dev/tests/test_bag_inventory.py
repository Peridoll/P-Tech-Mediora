from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime
import test_wounds
import test_private_medic
ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'fxmanifest.lua').exists():ROOT=ROOT.parent

FIXTURE='''
exports=exports or {};exports.qbx_core=exports.qbx_core or {}
exports.qbx_core.GetPlayer=exports.qbx_core.GetPlayer or function(_,src)return {PlayerData={citizenid='owner-'..src}}end
inventories={
 [1]={id=1,type='player',items={
  [1]={name='pmediora_bandage',count=2,slot=1,metadata={batch='root'}},
  [5]={name='pmediora_medicalbag',count=1,slot=5,metadata={container='bag-a',size={24,1000000},medicalBagVariant=2,imageurl='saved.png',weight=700}},
  [6]={name='pmediora_medicalbag',count=1,slot=6,metadata={container='bag-b',size={24,1000000},weight=800}},
  [7]={name='otherbag',count=1,slot=7,metadata={container='not-medical'}}}},
 ['bag-a']={id='bag-a',type='container',items={
  [1]={name='pmediora_bandage',count=3,slot=1,metadata={batch='bag-a'}},
  [2]={name='pmediora_icepack',count=4,slot=2,metadata={batch='cold'}}}},
 ['bag-b']={id='bag-b',type='container',items={
  [1]={name='pmediora_bandage',count=7,slot=1,metadata={batch='bag-b'}},
  [2]={name='pmediora_phoenixkit',count=1,slot=2,metadata={batch='kit'}}}},
 ['not-medical']={id='not-medical',type='container',items={
  [1]={name='pmediora_phoenixkit',count=99,slot=1,metadata={}}}},
 ['foreign']={id='foreign',type='container',items={
  [1]={name='pmediora_bandage',count=999,slot=1,metadata={}}}},
}
removeCalls=0;failAt=nil;addCount=0;detachOnHydrate=false
local function get(inv)return inventories[inv]end
local function weight(inv)
 local value=0;for _,item in pairs(inv.items)do value=value+item.count*100 end;inv.weight=value;return inv
end
exports.ox_inventory={
 GetInventory=function(_,id)return get(id)end,
 GetInventoryItems=function(_,id)return get(id)and get(id).items end,
 GetSlot=function(_,id,slot)return get(id)and get(id).items[slot]end,
 GetContainerFromSlot=function(_,id,slot)
  local bag=get(id).items[slot];if not bag then return end
  local container=get(bag.metadata.container)
  if detachOnHydrate and slot==5 then get(id).items[slot]=nil end
  return container and weight(container)
 end,
 Search=function(_,id,kind,name)
  local count=0;for _,item in pairs(get(id).items)do if item.name==name then count=count+item.count end end;return count
 end,
 GetItemCount=function(_,id,name)
  local count=0;for _,item in pairs(get(id).items)do if item.name==name then count=count+item.count end end;return count
 end,
 CanCarryItem=function()return true end,
 RemoveItem=function(_,id,name,count,metadata,slot,ignoreTotal,strict)
  removeCalls=removeCalls+1;if failAt==removeCalls then return false end
  assert(strict==true and ignoreTotal==false)
  local item=get(id).items[slot]
  assert(item and item.name==name and item.count>=count and item.metadata.batch==metadata.batch)
  item.count=item.count-count;if item.count==0 then get(id).items[slot]=nil end
  weight(get(id));return true
 end,
 AddItem=function(_,id,name,count,metadata,slot)
  local inv=get(id);if not inv then return false end
  if not slot then slot=1;while inv.items[slot]do slot=slot+1 end end
  local item=inv.items[slot]
  if item and item.name~=name then return false end
  if not item then item={name=name,count=0,metadata=metadata or {},slot=slot};inv.items[slot]=item end
  item.count=item.count+count;addCount=addCount+count;weight(inv);return true
 end,
 SetMetadata=function(_,id,slot,metadata)get(id).items[slot].metadata=metadata end,
}
if not lib then lib={callback={register=function()end}}end
if not AddEventHandler then function AddEventHandler()end end
if not GetResourceState then function GetResourceState()return 'started'end end
'''

class BagInventoryTest(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime();self.lua.execute(FIXTURE)
        self.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
    def check(self,code):self.lua.execute(code)
    def test_counts_only_owned_medical_bags_and_main_inventory(self):
        self.check("assert(MedicalInventory.count(1,'pmediora_bandage')==12);assert(MedicalInventory.count(1,'pmediora_phoenixkit')==1)")
    def test_split_consumption_weight_metadata_and_idempotent_refund(self):
        self.check("local ok,r=MedicalInventory.remove(1,'pmediora_bandage',5);assert(ok and #r.entries==2);assert(not inventories[1].items[1]);assert(not inventories['bag-a'].items[1]);assert(MedicalInventory.count(1,'pmediora_bandage')==7);local m=inventories[1].items[5].metadata;assert(m.weight==400 and m.medicalBagVariant==2 and m.imageurl=='saved.png'and m.container=='bag-a');assert(MedicalInventory.refund(r));assert(MedicalInventory.count(1,'pmediora_bandage')==12 and inventories[1].items[1].metadata.batch=='root');assert(MedicalInventory.refund(r));assert(MedicalInventory.count(1,'pmediora_bandage')==12)")
    def test_missing_amount_and_second_remove_failure_never_partially_charge(self):
        self.check("assert(not MedicalInventory.remove(1,'pmediora_bandage',13)and removeCalls==0);failAt=2;assert(not MedicalInventory.remove(1,'pmediora_bandage',5));assert(MedicalInventory.count(1,'pmediora_bandage')==12)")
    def test_transferred_bag_is_not_used(self):
        self.check("inventories[1].items[6]=nil;assert(MedicalInventory.count(1,'pmediora_phoenixkit')==0);assert(not MedicalInventory.remove(1,'pmediora_phoenixkit',1)and removeCalls==0)")
    def test_bag_lost_during_hydration_is_rechecked(self):
        self.check("detachOnHydrate=true;assert(MedicalInventory.count(1,'pmediora_bandage')==9)")
    def test_all_bags_rechecked_after_other_bag_hydration(self):
        self.check("local original=exports.ox_inventory.GetContainerFromSlot;exports.ox_inventory.GetContainerFromSlot=function(_,owner,slot)local bag=original(nil,owner,slot);if slot==6 then inventories[1].items[5]=nil end;return bag end;assert(MedicalInventory.count(1,'pmediora_bandage')==9)")
    def test_duplicate_bag_ids_are_not_counted_twice(self):
        self.check("inventories[1].items[8]={name='pmediora_medicalbag',count=1,slot=8,metadata={container='bag-a'}};assert(MedicalInventory.count(1,'pmediora_bandage')==12)")
    def test_refund_after_bag_transfer_returns_to_doctor_not_new_owner(self):
        self.check("local ok,r=MedicalInventory.remove(1,'pmediora_phoenixkit',1);assert(ok);inventories[1].items[6]=nil;assert(MedicalInventory.refund(r));assert(MedicalInventory.count(1,'pmediora_phoenixkit')==1 and not inventories['bag-b'].items[2])")
    def test_supply_carton_contents_are_not_auto_opened(self):
        self.check("inventories['bag-a'].items[9]={name='pmediora_supplybox',count=1,slot=9,metadata={contents={pmediora_bandage=1000}}};assert(MedicalInventory.count(1,'pmediora_bandage')==12)")

class BagTreatmentIntegrationTest(unittest.TestCase):
    def test_chart_lists_and_consumes_icepacks_stored_only_in_bag(self):
        case=test_wounds.ServerTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local found=false;for _,item in ipairs(MedicalWoundServer.items(1))do if item.name=='pmediora_icepack'then assert(item.count==4);found=true end end;assert(found);local task=start('pmediora_icepack');assert(task.token and task.count==4);assert(finish(task).ok);assert(MedicalInventory.count(1,'pmediora_icepack')==0);assert(not state(2).parts.right_leg.wounds.bruise)")
    def test_phoenix_target_consumes_bag_kit(self):
        case=test_private_medic.PrivateTreatmentTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local task=invoke('begin',1,2);assert(task.ok);clock=clock+Config.PrivateMedic.Duration;assert(invoke('finish',1,task.token).ok and healCalls==1);assert(MedicalInventory.count(1,'pmediora_phoenixkit')==0 and inventories[1].items[6].metadata.weight==700)")
    def test_bag_transferred_during_phoenix_progress_does_not_revive(self):
        case=test_private_medic.PrivateTreatmentTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local task=invoke('begin',1,2);assert(task.ok);inventories[1].items[6]=nil;clock=clock+Config.PrivateMedic.Duration;assert(invoke('finish',1,task.token).error and healCalls==0 and inventories['bag-b'].items[2].count==1)")
    def test_failed_phoenix_effect_restores_kit_to_same_bag(self):
        case=test_private_medic.PrivateTreatmentTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;healFails=true;assert(invoke('finish',1,task.token).error);assert(inventories['bag-b'].items[2].count==1 and inventories['bag-b'].items[2].metadata.batch=='kit' and inventories[1].items[6].metadata.weight==800)")
    def test_patient_change_during_bag_loading_refunds_before_healing(self):
        case=test_wounds.ServerTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local task=start('pmediora_icepack');assert(task.token);local original=exports.ox_inventory.GetContainerFromSlot;local changed=false;exports.ox_inventory.GetContainerFromSlot=function(...)if not changed then changed=true;assert(MedicalWoundServer.clearFractures(2,'right_leg'))end;return original(...)end;assert(finish(task).error);assert(state(2).parts.right_leg.wounds.bruise and MedicalInventory.count(1,'pmediora_icepack')==4)")
    def test_refill_counts_bag_tools_and_does_not_duplicate_on_repeat(self):
        case=test_wounds.ServerTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("commands.medkit30(1);assert(MedicalInventory.count(1,'pmediora_bandage')==30 and MedicalInventory.count(1,'pmediora_phoenixkit')==30);local previous=addCount;commands.medkit30(1);assert(addCount==previous)")
    def test_refill_is_locked_while_stored_bags_are_loading(self):
        case=test_wounds.ServerTest();case.setUp();case.lua.execute(FIXTURE)
        case.lua.execute((ROOT/'main/server/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("local original=exports.ox_inventory.GetContainerFromSlot;local reentered=false;exports.ox_inventory.GetContainerFromSlot=function(...)if not reentered then reentered=true;commands.medkit30(1)end;return original(...)end;commands.medkit30(1);assert(MedicalInventory.count(1,'pmediora_bandage')==30 and MedicalInventory.count(1,'pmediora_phoenixkit')==30)")

class BagClientCacheTest(unittest.TestCase):
    def test_target_counts_bag_kit_and_clears_stale_cache(self):
        case=test_private_medic.PrivateClientTest();case.setUp()
        case.lua.execute("local original=lib.callback.await;local hasBag=true;exports.ox_inventory.Search=function(_,kind,name)if name=='pmediora_medicalbag'and hasBag then return 1 end;return 0 end;lib.callback.await=function(name,...)if name=='ptech_mediora_medical:bagToolCounts'then return {citizenId='patient-1',counts={pmediora_phoenixkit=1}}end;return original(name,...)end")
        case.lua.execute((ROOT/'main/client/inventory.lua').read_text(encoding='utf-8'))
        case.lua.execute("MedicalInventoryClient.refresh();assert(MedicalInventoryClient.count('pmediora_phoenixkit')==1 and targetOption.canInteract(2));clock=clock+3000;assert(MedicalInventoryClient.count('pmediora_phoenixkit')==0 and not targetOption.canInteract(2))")
