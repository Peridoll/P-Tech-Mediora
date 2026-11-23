import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

stage=Path(__file__).resolve().parent
root=stage.parent
if not (root/'fxmanifest.lua').exists():root=root.parent
config_file=root/'main/shared/private_billing.lua'
server_file=root/'main/server/private_billing.lua'
if not config_file.exists():config_file=stage/'config.lua';server_file=stage/'server.lua'
class BillingTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
Config={}; callbacks={}; threads={}; notifications={}; queries={}; ledger={}; invoices={}; credits={}; nextInvoice=1
local vec={};vec.__sub=function(a,b)return setmetatable({x=a.x-b.x},vec)end;vec.__len=function(a)return math.abs(a.x)end
coords={[1]=setmetatable({x=0},vec),[2]=setmetatable({x=1},vec)}
players={
 [1]={PlayerData={source=1,citizenid='doctor',charinfo={firstname='Doctor',lastname='One'},job={name='private_medic',onduty=true,grade={level=1}},metadata={}}},
 [2]={PlayerData={source=2,citizenid='patient',charinfo={firstname='Patient',lastname='Two'},job={name='unemployed',onduty=true,grade={level=0}},metadata={}}}
}
Medical={};PrivateMedic={down=function()return false end}
lib={callback={register=function(n,f)callbacks[n]=f end}}
function CreateThread(f)threads[#threads+1]=f end
function Wait()end
function GetGameTimer()return 100 end
function GetPlayerPed(src)return players[src]and src or 0 end
function GetEntityCoords(ped)return coords[ped]end
function GetEntityHealth()return 200 end
function Player()return{state={}}end
function GetPlayerRoutingBucket(src)return buckets and buckets[src]or 0 end
function GetResourceState()return 'started'end
function TriggerClientEvent(...)notifications[#notifications+1]={...}end
function AddEventHandler()end
exports={qbx_core={
 GetPlayer=function(_,src)return players[src]end,
 GetPlayerByCitizenId=function(_,id)for _,p in pairs(players)do if p.PlayerData.citizenid==id then return p end end end,
 AddMoney=function(_,id,kind,amount,reason)
   if creditError then error('credit failed')end
   if creditDenied then return false end
   credits[#credits+1]={id=id,amount=amount,reason=reason};return true
 end,
 Save=function()end,
},oxmysql={}}
local db=exports.oxmysql
function db:scalar_async()return 'server-generated-uuid'end
function db:single_async(sql,args)return ledger[args[1]]end
function db:transaction_async(steps)
 if transactionFail then return false end
 local a,b=steps[1].values,steps[2].values
 local id=nextInvoice;nextInvoice=id+1
 invoices[id]={id=id,author_identifier=a[3],receiver_identifier=a[1],invoice_value=a[5],status='unpaid'}
 ledger[b[1]]={id=id,invoice_id=id,doctor_id=b[2],patient_id=b[4],amount=b[6],bonus_amount=b[7],bonus_status='waiting'}
 lastSteps=steps;return true
end
function db:query_async(sql,args)
 queries[#queries+1]=sql
 if sql:find('CREATE TABLE')then return {}end
 local rows={}
 for _,p in pairs(ledger)do
   local b=invoices[p.invoice_id]
   if p.bonus_status=='waiting'and b and b.status=='paid'and b.author_identifier==p.doctor_id and b.receiver_identifier==p.patient_id and b.invoice_value==p.amount then rows[#rows+1]=p end
 end
 return rows
end
function db:update_async(sql,args)
 local p
 for _,row in pairs(ledger)do if row.id==args[1]then p=row end end
 if sql:find("SET p.bonus_status='processing'")then
   if p.bonus_status~='waiting'then return 0 end
   p.bonus_status='processing';return 1
 elseif sql:find("bonus_status='paid'")then
   if failPaidWrite then error('database lost after credit')end
   p.bonus_status='paid';return 1
 elseif sql:find("bonus_status='review'")then p.bonus_status='review';return 1 end
 error('unexpected update')
end
function call(name,...)return callbacks['ptech_mediora_medical:privateBill:'..name](...)end
''')
        self.lua.execute(config_file.read_text(encoding='utf-8'))
        self.lua.execute(server_file.read_text(encoding='utf-8'))
        self.lua.execute('threads[1]()')
    def check(self,code): self.lua.execute(code)
    def test_open_and_personal_invoice(self):
        self.check("local s=call('open',1,2);assert(s.defaultAmount==1200000 and s.bonus==3600000 and s.manager);local r=call('send',1,s.token,1200000,'診療');assert(r.ok);assert(ledger[s.token].amount==1200000 and #credits==0);assert(lastSteps[1].query:find(\"'','','個人医療費'\",1,true))")
    def test_duplicate_send_same_invoice(self):
        self.check("local s=call('open',1,2);assert(call('send',1,s.token,1200000,'care').ok);assert(call('send',1,s.token,1200000,'care').ok);assert(nextInvoice==2)")
    def test_invalid_amounts_and_note(self):
        self.check("local s=call('open',1,2);for _,a in ipairs({0,-1,1.1,100000001,'1200000',math.huge})do assert(call('send',1,s.token,a,'care').error)end;assert(call('send',1,s.token,1,string.rep('a',181)).error);assert(nextInvoice==1)")
    def test_server_authorization(self):
        self.check("players[1].PlayerData.job.name='ambulance';assert(call('open',1,2).error);players[1].PlayerData.job.name='private_medic';players[1].PlayerData.job.onduty=false;assert(call('open',1,2).error)")
    def test_range_bucket_and_identity(self):
        self.check("local s=call('open',1,2);coords[2].x=10;assert(call('send',1,s.token,1,'care').error);coords[2].x=1;buckets={[1]=0,[2]=1};assert(call('send',1,s.token,1,'care').error);buckets=nil;players[2].PlayerData.citizenid='other';assert(call('send',1,s.token,1,'care').error)")
    def test_only_paid_invoice_grants_once(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,100,'care');MedicalPrivateBilling.settle();assert(#credits==0);invoices[1].status='paid';MedicalPrivateBilling.settle();MedicalPrivateBilling.settle();assert(#credits==1 and credits[1].id=='doctor'and credits[1].amount==3600000);assert(ledger[s.token].bonus_status=='paid')")
    def test_offline_doctor_still_receives(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');players[1]=nil;invoices[1].status='paid';MedicalPrivateBilling.settle();assert(#credits==1 and credits[1].id=='doctor')")
    def test_payment_must_match_stored_invoice(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');invoices[1].status='paid';invoices[1].author_identifier='different';MedicalPrivateBilling.settle();assert(#credits==0)")
    def test_cancelled_not_paid(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');invoices[1].status='cancelled';MedicalPrivateBilling.settle();assert(#credits==0)")
    def test_bonus_failure_preserved_for_review(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');invoices[1].status='paid';creditError=true;MedicalPrivateBilling.settle();assert(ledger[s.token].bonus_status=='review');creditError=false;MedicalPrivateBilling.settle();assert(#credits==0)")
    def test_crash_after_credit_does_not_repeat(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');invoices[1].status='paid';failPaidWrite=true;assert(not pcall(MedicalPrivateBilling.settle));assert(#credits==1 and ledger[s.token].bonus_status=='processing');failPaidWrite=false;MedicalPrivateBilling.settle();assert(#credits==1)")
    def test_failed_invoice_has_no_bonus(self):
        self.check("local s=call('open',1,2);transactionFail=true;assert(call('send',1,s.token,1,'care').error);MedicalPrivateBilling.settle();assert(#credits==0 and nextInvoice==1)")
    def test_history_manager_only(self):
        self.check("assert(call('history',1,1).ok);players[1].PlayerData.job.grade.level=0;assert(call('history',1,1).error);players[1].PlayerData.job.grade.level=1;players[1].PlayerData.job.name='ambulance';assert(call('history',1,1).error)")
    def test_restart_does_not_repeat_paid_bonus(self):
        self.check("local s=call('open',1,2);call('send',1,s.token,1,'care');invoices[1].status='paid';MedicalPrivateBilling.settle();assert(#credits==1)")
        self.lua.execute(server_file.read_text(encoding='utf-8'))
        self.check("threads[3]();MedicalPrivateBilling.settle();assert(#credits==1)")
    def test_forged_token_and_expired_session(self):
        self.check("local s=call('open',1,2);assert(call('send',1,'forged',1,'care').error);GetGameTimer=function()return 999999 end;assert(call('send',1,s.token,1,'care').error);assert(nextInvoice==1)")
if __name__=='__main__':unittest.main()
