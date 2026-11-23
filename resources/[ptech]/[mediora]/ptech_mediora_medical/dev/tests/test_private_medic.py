import json,os,unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'fxmanifest.lua').exists():ROOT=ROOT.parent
CONFIG_PATH='config.lua' if (ROOT/'config.lua').exists() else 'config/config.lua'
HARNESS='''
callbacks={};events={};registered={};timers={};threads={};clock=10000;source=1
local mt={__sub=function(a,b)return setmetatable({x=a.x-b.x},{__len=function(v)return math.abs(v.x)end})end}
positions={[1]=setmetatable({x=0},mt),[2]=setmetatable({x=1},mt),[3]=setmetatable({x=0},mt)}
players={};states={};healths={};stock=1;removed=0;added=0;healCalls=0;removeFails=false;healFails=false
for id=1,3 do
 players[id]={PlayerData={citizenid='patient-'..id,job={name='private_medic',onduty=true},metadata={isdead=id==2,inlaststand=false,hunger=12,thirst=23,stress=45}}}
 states[id]={dead=id==2 and 'dead' or false};healths[id]=id==2 and 0 or 200
end
buckets={[1]=0,[2]=0,[3]=0};caller='ptech_mediora_private_medic';partial=false
function Player(id)return {state=states[id]}end
function GetPlayerPed(id)return players[id] and id or 0 end
function GetEntityCoords(id)return positions[id]end
function GetEntityHealth(id)return healths[id]end
function GetEntityMaxHealth()return 250 end
function GetPlayerRoutingBucket(id)return buckets[id]end
function GetResourceState()return 'started'end
function GetGameTimer()return clock end
function Wait(ms)clock=clock+ms end
function SetTimeout(ms,fn)timers[#timers+1]=fn end
function RegisterNetEvent(name,fn)events[name]=fn end
function RegisterCommand()end
function AddEventHandler(name,fn)events[name]=fn end
function CreateThread(fn)threads[#threads+1]=fn end
function GetInvokingResource()return caller end
function IsPlayerAceAllowed()return true end
function TriggerClientEvent(name,target,percent,citizenId)
 if name=='ptech_mediora_medical:health'then assert(percent==100 and citizenId=='patient-'..target);healths[target]=250 end
end
lib={callback={register=function(name,fn)callbacks[name]=fn end}}
exports=setmetatable({
 qbx_core={GetPlayer=function(_,id)return players[id]end,
  SetMetadata=function(_,id,key,value)players[id].PlayerData.metadata[key]=value end},
 ox_inventory={Search=function()return stock end,
  RemoveItem=function(_,src,item,count)if removeFails or stock<count then return false end;stock=stock-count;removed=removed+count;return true end,
  AddItem=function(_,src,item,count)stock=stock+count;added=added+count;return true end},
 ptech_mediora_medical={restorePrivatePatient=function(_,target,id)
  healCalls=healCalls+1;assert(target==2 and id=='patient-2')
  if healFails then error('unavailable')end
  return partial and {error='incomplete',changed=true}or {ok=true,changed=true}
 end},
},{__call=function(_,name,fn)registered[name]=fn end})
MedicalWoundServer={restorePrivatePatient=function(target,id)return exports.ptech_mediora_medical:restorePrivatePatient(target,id)end}
'''

class PrivateTreatmentTest(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute(HARNESS)
        for file in [CONFIG_PATH,'main/shared/private_medic.lua','main/server/private_medic.lua']:
            self.lua.execute((ROOT/file).read_text(encoding='utf-8'))
        self.lua.execute("function invoke(action,src,...)return callbacks['ptech_mediora_medical:private:'..action](src,...)end")
    def check(self,code):self.lua.execute(code)
    def test_only_authorized_medics_on_duty_with_kit(self):
        self.check("players[1].PlayerData.job.name='unemployed';assert(invoke('begin',1,2).error);players[1].PlayerData.job.name='private_medic';players[1].PlayerData.job.onduty=false;assert(invoke('begin',1,2).error);players[1].PlayerData.job.onduty=true;stock=0;assert(invoke('begin',1,2).error);assert(healCalls==0)")
    def test_ems_can_use_phoenix_kit_but_off_duty_cannot(self):
        self.check("players[1].PlayerData.job.name='ambulance';players[1].PlayerData.job.onduty=false;assert(invoke('begin',1,2).error);players[1].PlayerData.job.onduty=true;local task=invoke('begin',1,2);assert(task.ok);clock=clock+Config.PrivateMedic.Duration;assert(invoke('finish',1,task.token).ok and removed==1 and healCalls==1)")

    def test_distance_bucket_alive_and_self_rejected(self):
        self.check("assert(invoke('begin',1,1).error);positions[2].x=10;assert(invoke('begin',1,2).error);positions[2].x=1;buckets[2]=1;assert(invoke('begin',1,2).error);buckets[2]=0;states[2].dead=false;players[2].PlayerData.metadata.isdead=false;healths[2]=200;assert(invoke('begin',1,2).error)")
    def test_duration_identity_single_use_and_consumption(self):
        self.check("local task=invoke('begin',1,2);assert(task.ok);assert(invoke('finish',1,task.token).error and removed==0);clock=clock+Config.PrivateMedic.Duration;assert(invoke('finish',1,task.token).ok);assert(removed==1 and stock==0 and healCalls==1);assert(invoke('finish',1,task.token).error and healCalls==1)")
    def test_changed_character_or_job_does_not_consume(self):
        self.check("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;players[2].PlayerData.citizenid='new-character';assert(invoke('finish',1,task.token).error and removed==0);players[2].PlayerData.citizenid='patient-2';task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;players[1].PlayerData.job.name='unemployed';assert(invoke('finish',1,task.token).error and removed==0)")
    def test_patient_lock_and_cancellation(self):
        self.check("local task=invoke('begin',1,2);assert(invoke('begin',3,2).error);source=1;events['ptech_mediora_medical:private:cancel']('wrong');assert(invoke('begin',3,2).error);events['ptech_mediora_medical:private:cancel'](task.token);assert(invoke('begin',3,2).ok and removed==0)")
    def test_missing_item_at_completion_does_not_apply_effect(self):
        self.check("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;stock=0;assert(invoke('finish',1,task.token).error and healCalls==0)")
    def test_remove_failure_does_not_revive(self):
        self.check("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;removeFails=true;assert(invoke('finish',1,task.token).error and healCalls==0 and removed==0)")
    def test_export_error_refunds_and_releases(self):
        self.check("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;healFails=true;assert(invoke('finish',1,task.token).error and added==1 and stock==1);assert(invoke('begin',1,2).ok)")
    def test_partially_applied_revive_is_not_refunded(self):
        self.check("local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;partial=true;assert(invoke('finish',1,task.token).error and removed==1 and added==0)")
    def test_optional_reusable_tool(self):
        self.check("Config.PrivateMedic.ConsumeCount=0;local task=invoke('begin',1,2);clock=clock+Config.PrivateMedic.Duration;assert(invoke('finish',1,task.token).ok and removed==0 and stock==1)")

class PrivateClientTest(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime();self.lua.execute(HARNESS)
        self.lua.execute('''
        coreCalls=0;hides=0;finished=0;cancelled=0;noProgress=false;logoutBegin=false
        function GetCurrentResourceName()return 'ptech_mediora_private_medic'end
        function PlayerPedId()return 1 end
        function IsPedAPlayer()return true end
        function NetworkGetPlayerIndexFromPed(id)return id end
        function GetPlayerServerId(id)return id end
        function DoesEntityExist()return true end
        function DisableAllControlActions()end
        function EnableControlAction()end
        function IsDisabledControlJustPressed()return false end
        function RequestAnimDict()end
        function HasAnimDictLoaded()return true end
        function TaskPlayAnim()end
        function StopAnimTask()end
        function RemoveAnimDict()end
        function Wait(ms)clock=clock+math.max(ms,1000)end
        function TriggerServerEvent(name,token)if name:find(':cancel',1,true)then cancelled=cancelled+1 end end
        LocalPlayer={state=states[1]}
        exports.qbx_core.GetPlayerData=function()return players[1].PlayerData end
        exports.ox_target={addGlobalPlayer=function(_,options)targetOption=options[1]end,removeGlobalPlayer=function()end}
        exports.ptech_mediora_core={
          showProgress=function(_,options)coreCalls=coreCalls+1;assert(options.template=='main/ui/progress/revive.svg');return not noProgress,1 end,
          hideProgress=function()hides=hides+1 end}
        lib.notify=function()end
        lib.callback.await=function(name,...)
          if name:find(':begin',1,true)then
            if logoutBegin then events['QBCore:Client:OnPlayerUnload']()end
            return {ok=true,token='test-token',duration=10000,patientId='patient-2'}
          end
          finished=finished+1;return {ok=true}
        end
        ''')
        for file in [CONFIG_PATH,'main/shared/private_medic.lua','main/client/private_medic.lua']:
            self.lua.execute((ROOT/file).read_text(encoding='utf-8'))
    def test_target_gating_and_core_progress(self):
        self.lua.execute("assert(targetOption.canInteract(2));players[1].PlayerData.job.name='unemployed';assert(not targetOption.canInteract(2));players[1].PlayerData.job.name='ambulance';assert(targetOption.canInteract(2));players[1].PlayerData.job.name='private_medic';stock=0;assert(not targetOption.canInteract(2));stock=1;targetOption.onSelect({entity=2});assert(coreCalls==1 and hides==1 and finished==1)")
    def test_missing_core_bar_cancels_without_finish(self):
        self.lua.execute("noProgress=true;targetOption.onSelect({entity=2});assert(coreCalls==1 and finished==0 and cancelled==1)")
    def test_logout_during_start_does_not_start_progress(self):
        self.lua.execute("logoutBegin=true;targetOption.onSelect({entity=2});assert(coreCalls==0 and finished==0 and cancelled==1)")

API_HARNESS='''
wasabiCalls=0;reviveFails=false;neverRevive=false
exports.wasabi_ambulance={RevivePlayer=function(_,target)
 wasabiCalls=wasabiCalls+1
 if reviveFails then error('revive error')end
 if not neverRevive then
  states[target].dead=false;healths[target]=200
  players[target].PlayerData.metadata.isdead=false
  players[target].PlayerData.metadata.hunger=100
  players[target].PlayerData.metadata.thirst=100
  players[target].PlayerData.metadata.stress=0
 end
end}
'''

class MedicalRestoreTest(unittest.TestCase):
    def runtimes(self):
        roots=json.loads(os.environ.get('MEDIORA_MEDICAL_TEST_ROOTS',json.dumps([str(ROOT)])))
        for root in map(Path,roots):
            lua=LuaRuntime();lua.execute(HARNESS);lua.execute(API_HARNESS)
            config='config.lua' if (root/'config.lua').exists() else 'config/config.lua'
            for file in [config,'main/shared/shared.lua','main/shared/wounds.lua','main/server/wounds.lua']:
                lua.execute((root/file).read_text(encoding='utf-8'))
            lua.execute('''
            local original=MedicalWounds.new;local first=true
            MedicalWounds.new=function()
              local state=original()
              if first then first=false;local part=state.parts.left_leg;part.blunt=80;part.sharp=50;part.fracture='active';part.bleeding='active';part.wounds.cut=true end
              return state
            end
            MedicalWoundServer.get(2)
            function restore()return MedicalWoundServer.restorePrivatePatient(2,'patient-2')end
            ''')
            yield lua
    def test_full_health_and_wounds_without_needs_recovery(self):
        for lua in self.runtimes():
            lua.execute("assert(restore().ok);assert(healths[2]==250);local m=players[2].PlayerData.metadata;assert(m.hunger==12 and m.thirst==23 and m.stress==45);local state=MedicalWoundServer.get(2).state;for _,p in pairs(state.parts)do assert(not p.fracture and not p.bleeding and p.blunt==0 and p.sharp==0 and not next(p.wounds))end;assert(not state.ivCondition)")
    def test_wrong_resource_or_patient_identity_cannot_restore(self):
        for lua in self.runtimes():
            lua.execute("assert(registered.restorePrivatePatient==nil,'no external healing export');assert(MedicalWoundServer.restorePrivatePatient(2,'wrong').error and wasabiCalls==0)")
    def test_revive_exception_preserves_injuries_and_releases_lock(self):
        for lua in self.runtimes():
            lua.execute("reviveFails=true;assert(restore().error);assert(MedicalWoundServer.get(2).state.parts.left_leg.fracture=='active');reviveFails=false;assert(restore().ok)")
    def test_unconfirmed_revive_does_not_clear_wounds(self):
        for lua in self.runtimes():
            lua.execute("neverRevive=true;local result=restore();assert(result.error and result.changed);assert(MedicalWoundServer.get(2).state.parts.left_leg.fracture=='active')")

if __name__=='__main__':unittest.main()
