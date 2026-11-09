"""最終設計の実装を実際のLua 5.4で検証。FiveMの実機試験とは別。"""
import unittest
from test_charts import HARNESS, ROOT, LuaRuntime


class ModelTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        for path in ['config.lua', 'main/shared/shared.lua', 'main/shared/wounds.lua']:
            self.lua.execute((ROOT / path).read_text(encoding='utf-8'))
        self.lua.execute('W=MedicalWounds; s=W.new(); p=s.parts.right_leg; function miss() return 99 end; function hit() return 0 end')

    def check(self, code):
        self.lua.execute(code)

    def test_twenty_percent_hit_adds_twenty_in_affected_part_only(self):
        self.check("W.damage(s,'right_leg','blunt',20,false,miss); assert(p.blunt==20 and p.wounds.blunt and not p.wounds.bruise); assert(s.parts.head.blunt==0)")

    def test_shot_uses_final_125_075_multipliers(self):
        self.check("W.damage(s,'right_leg','shot',20,false,miss); assert(p.blunt==25 and p.sharp==15 and p.wounds.shot)")

    def test_repeat_bruise_success_adds_bonus_before_fracture_roll(self):
        self.check('''
        local draws={64,44}; local function draw() return table.remove(draws,1) end
        W.damage(s,'right_leg','blunt',70,false,draw)
        assert(p.blunt==75 and p.wounds.bruise and not p.wounds.blunt and p.fracture=='active')
        p.fracture=nil
        W.damage(s,'right_leg','blunt',1,false,hit)
        assert(p.blunt==81 and p.fracture=='active')
        ''')

    def test_missed_bruise_roll_keeps_existing_bruise_and_skips_fracture(self):
        self.check('''
        p.blunt=50; p.wounds.bruise=true; local calls=0
        W.damage(s,'right_leg','blunt',1,false,function() calls=calls+1; return 99 end)
        assert(calls==1 and p.wounds.bruise and not p.fracture and p.blunt==51)
        ''')

    def test_chances_are_clamped_and_cap_is_ninety(self):
        self.check("W.damage(s,'right_leg','blunt',100,false,hit); assert(p.blunt==90); W.damage(s,'right_leg','shot',100,false,hit); assert(p.blunt==90 and p.sharp==80)")

    def test_zero_probability_never_hits(self):
        self.check("W.damage(s,'right_leg','blunt',1,false,hit); assert(not p.wounds.bruise and not p.fracture)")

    def test_bruise_floor_applies_to_halving_and_decay(self):
        self.check("p.wounds.bruise=true;p.blunt=40;p.sharp=20;W.medication(s,false);assert(p.blunt==30 and p.sharp==10);W.decay(s,100);assert(p.blunt==30 and p.sharp==0 and p.wounds.bruise)")

    def test_full_medication_starts_blunt_recovery_and_still_cures_cuts(self):
        self.check('''
        os.time=function() return 1000 end
        p.wounds={blunt=true,cut=true,shot=true,burn=true}
        p.fracture='active'
        s.parts.head.wounds.bruise=true
        W.medication(s,false)
        assert(p.wounds.blunt and not p.bluntRecoveryAt)
        W.medication(s,true)
        assert(p.wounds.blunt and not p.wounds.cut)
        assert(not W.expireBlunt(s,1899) and p.wounds.blunt)
        assert(W.expireBlunt(s,1900) and not p.wounds.blunt)
        assert(p.wounds.shot and p.wounds.burn and p.fracture=='active' and s.parts.head.wounds.bruise)
        ''')

    def test_new_blunt_hit_restarts_requirement_for_full_health(self):
        self.check('''
        W.damage(s,'right_leg','blunt',5,false,miss)
        W.medication(s,true)
        local deadline=p.bluntRecoveryAt
        W.damage(s,'right_leg','blunt',1,false,miss)
        assert(not W.expireBlunt(s,deadline) and p.wounds.blunt and not p.bluntRecoveryAt)
        ''')

    def test_cut_and_bruise_thresholds_and_required_counts(self):
        self.check('''
        p.wounds.blunt=true;p.blunt=30;assert(W.plan(s,'right_leg','pmediora_icepack').count==1)
        p.blunt=30.1;assert(W.plan(s,'right_leg','pmediora_icepack').count==2)
        p.wounds.blunt=nil;p.wounds.bruise=true;p.blunt=60;assert(W.plan(s,'right_leg','pmediora_icepack').count==3)
        p.blunt=60.1;assert(W.plan(s,'right_leg','pmediora_icepack').count==4)
        p.wounds.cut=true;p.sharp=20;assert(W.plan(s,'right_leg','pmediora_suturekit').count==1)
        p.sharp=20.1;assert(W.plan(s,'right_leg','pmediora_suturekit').count==2)
        ''')

    def test_burn_bonus_only_on_first_occurrence(self):
        self.check("W.damage(s,'right_leg','burn',10,false,miss);W.damage(s,'right_leg','burn',10,false,miss);assert(p.sharp==10 and p.wounds.burn)")

    def test_pin_even_without_hp_damage_and_forceps_remove_it(self):
        self.check("W.damage(s,'right_leg','pin',0,false,miss);assert(p.wounds.pin);local plan=W.plan(s,'right_leg','pmediora_surgicalforceps');W.treat(s,plan,false);assert(not p.wounds.pin)")

    def test_bleeding_uses_explicit_final_document_basis(self):
        self.check("p.sharp=80;W.damage(s,'right_leg','cut',1,false,hit);assert(not p.bleeding);p.blunt=30;W.damage(s,'right_leg','cut',1,false,hit);assert(p.bleeding=='active' and p.sharp==87)")

    def test_bleeding_suppression_bonus_relapse_and_notifications(self):
        self.check("p.bleeding='suppressed';local notices=W.damage(s,'right_leg','cut',1,false,function() return 19 end);assert(p.bleeding=='active' and p.sharp==6 and notices[1].symptom=='bleedingRelapse')")

    def test_fatal_blunt_and_cut_force_injury_silently(self):
        self.check("local n=W.damage(s,'right_leg','blunt',1,true,miss);assert(p.wounds.bruise and p.blunt==30 and #n==0);local n2=W.damage(s,'head','cut',1,true,miss);assert(s.parts.head.bleeding=='active' and #n2==0)")

    def test_painkillers_and_hemostatic_suppress_without_curing(self):
        self.check("p.fracture='active';p.bleeding='active';W.treat(s,W.plan(s,'right_leg','pmediora_painkiller'));W.treat(s,W.plan(s,'right_leg','pmediora_hemostatic'));assert(p.fracture=='suppressed' and p.bleeding=='suppressed');assert(not W.active(s,'bleeding'));assert(not W.plan(s,'right_leg','pmediora_painkiller'))")

    def test_cast_and_cooling_treat_separately_and_preserve_residual(self):
        self.check("p.wounds.bruise=true;p.blunt=80;p.fracture='active';W.treat(s,W.plan(s,'right_leg','pmediora_icepack'));assert(not p.wounds.bruise and p.fracture=='active' and p.blunt==30);W.treat(s,W.plan(s,'right_leg','pmediora_protectivecast'));assert(not p.fracture and p.blunt==30);W.decay(s,1);assert(p.blunt==29)")

    def test_suture_and_extraction_stop_bleeding_but_alternatives_do_not(self):
        self.check("p.wounds.cut=true;p.bleeding='active';W.treat(s,W.plan(s,'right_leg','pmediora_needleandthread'));assert(p.bleeding=='active');p.wounds.cut=true;W.treat(s,W.plan(s,'right_leg','pmediora_suturekit'));assert(not p.bleeding and not p.wounds.cut)")

    def test_invalid_damage_and_mismatched_item_do_not_mutate(self):
        self.check("assert(not W.damage(s,'bad','blunt',20));assert(not W.damage(s,'head','unknown',20));assert(not W.damage(s,'head','blunt',0/0));assert(s.revision==0);assert(not W.plan(s,'head','pmediora_icepack'))")


SERVER_HARNESS = '''
threads={};CreateThread=function(fn)threads[#threads+1]=fn end
healths={ [1]=200,[2]=200,[3]=200 };stock={};writes=0; failRemoval=false; deadFlags={}
function GetEntityMaxHealth() return 200 end
function GetEntityHealth(ped) return healths[ped] end
function Player(id) return {state={dead=deadFlags[id] or false}} end
function GetPlayers() return {'1','2','3'} end
function GetResourceState(name) return name == 'screenshot-basic' and 'missing' or 'started' end
function TriggerClientEvent(name,target,value) end
exports.ox_inventory={
 Search=function(_,src,kind,name) assert(kind=='count');return stock[name] or 0 end,
 RemoveItem=function(_,src,name,count)
  if failRemoval or (stock[name] or 0)<count then return false end
  stock[name]=stock[name]-count;writes=writes+count;return true
 end
}
function syncPatient(src)
 return invoke('wounds:get',src,players[src].PlayerData.citizenid)
end
function damage(src,kind,pct,part,seq)
 local session=syncPatient(src);source=src
 emit('ptech_mediora_medical:damage',{citizenId=session.citizenId,token=session.token,sequence=seq or session.sequence+1,kind=kind,percent=pct,part=part or 'right_leg'})
end
function state(src) return MedicalWoundServer.get(src or 2).state end
function makeChart()
 assert(not invoke('inspect',1,2).error)
 local confirm=invoke('confirm',1,2,{unsupported='irrelevant'},false)
 assert(confirm.report and not confirm.error)
 clock=clock+confirm.duration
 return invoke('createChart',1,2).chart.chartId
end
function start(item,part,medic,target,chart)
 return invoke('treatment:start',medic or 1,target or 2,part or 'right_leg',item,chart or chartId)
end
function finish(task,medic)
 clock=clock+task.duration
 return invoke('treatment:finish',medic or 1,task.token)
end
'''


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        self.lua.execute(SERVER_HARNESS)
        for path in ['config.lua','main/shared/shared.lua','main/shared/wounds.lua','main/server/wounds.lua','main/server/fractures.lua','main/server/server.lua']:
            self.lua.execute((ROOT/path).read_text(encoding='utf-8'))
        self.lua.execute("math.random=function(a,b) return a or 0 end;damage(2,'blunt',70);chartId=makeChart();stock.pmediora_icepack=10;stock.pmediora_protectivecast=10")

    def check(self, code):
        self.lua.execute(code)

    def test_real_treatment_consumes_required_count_only_after_success(self):
        self.check("local task=start('pmediora_icepack');assert(task.count==4 and writes==0 and task.motion=='cooling');assert(finish(task).ok and writes==4);local p=state().parts.right_leg;assert(not p.wounds.bruise and p.fracture=='active');assert(#state().history==1)")

    def test_receipt_counts_distinct_treatment_sites_and_keeps_material_cost(self):
        self.check('''
        assert(finish(start('pmediora_icepack')).ok)
        math.random=function(a,b) return a or 0.99 end
        damage(2,'blunt',1,'right_leg'); assert(finish(start('pmediora_icepack')).ok)
        damage(2,'blunt',1,'left_arm'); assert(finish(start('pmediora_icepack','left_arm')).ok)
        local receipt=invoke('getPatientCharts',1,2).charts[1]
        local line=receipt.treatmentCharges[1]
        assert(#receipt.treatmentCharges==1 and line.label=='冷却' and line.siteCount==2)
        assert(line.amount==writes*100000 and receipt.totalCharge==line.amount+100000)
        ''')

    def test_chart_is_immutable_and_current_symptoms_separate(self):
        self.check("local task=start('pmediora_icepack');finish(task);local r=invoke('getPatientCharts',1,2);assert(r.charts[1].injuries[1].kind=='bruise');assert(r.currentInjuries[1].kind=='fracture' and r.treatment and #r.treatmentHistory==1)")

    def test_rediagnosis_appends_within_five_minutes_and_archives_only_on_new_wounds(self):
        self.check('''
        local created=os.time()
        clock=clock+5000; os.time=function() return created+300 end
        damage(2,'pin',0,'left_arm'); assert(makeChart()==chartId)
        local result=invoke('getPatientCharts',1,2)
        assert(#result.charts==1 and #result.charts[1].injuries==3)
        clock=clock+5000; os.time=function() return created+301 end
        assert(makeChart()==chartId)
        clock=clock+5000; damage(2,'pin',0,'right_arm')
        local latest=makeChart(); assert(latest~=chartId)
        result=invoke('getPatientCharts',1,2)
        assert(result.charts[2].archived and not result.charts[2].canTreat and result.charts[1].canTreat)
        assert(start('pmediora_icepack').error and writes==0)
        assert(invoke('billChart',1,2,chartId).error=='このカルテは請求無効です')
        assert(finish(start('pmediora_icepack',nil,nil,nil,latest)).ok)
        ''')

    def test_partial_invoice_seals_chart_and_next_examination_creates_new_one(self):
        self.check("""
        local calls=0
        exports.oxmysql={insert_async=function(_,query,params) calls=calls+1;assert(params[7]==500000);return 77 end}
        assert(invoke('billChart',1,2,chartId).error and calls==0)
        assert(finish(start('pmediora_icepack')).ok)
        assert(state().parts.right_leg.fracture=='active')
        players[2].PlayerData.metadata.isdead=true
        assert(invoke('billChart',1,2,chartId).ok and calls==1)
        assert(invoke('billChart',1,2,chartId).ok and calls==1)
        assert(start('pmediora_protectivecast').error)
        MedicalWoundServer.clearFractures(2)
        players[2].PlayerData.metadata.isdead=false
        clock=clock+5000
        local nextChart=makeChart()
        local result=invoke('getPatientCharts',1,2)
        assert(nextChart~=chartId and #result.charts==2 and #result.charts[1].injuries==0)
        assert(result.charts[2].archived and result.charts[2].invoiceId==77)
        """)

    def test_photo_attaches_once_to_new_chart_and_is_shared_with_medic(self):
        self.check("""
        Config.Examination.ChartPhoto=true
        function GetResourceState() return 'started' end
        promise={new=function() return {resolve=function(self,value) self.value=value end} end}
        Citizen={Await=function(result) return result.value end}
        local shots=0
        exports['screenshot-basic']={requestClientScreenshot=function(_,src,opts,cb)
            assert(src==1 and opts.encoding=='jpg');shots=shots+1;cb(false,'data:image/jpeg;base64,AAAA')
        end}
        clock=clock+5000;damage(2,'pin',0,'head')
        local currentTime=os.time(); os.time=function() return currentTime+400 end
        local id=makeChart()
        local points={head={x=.5,y=.2},upper_body={x=.5,y=.4}}
        assert(not invoke('capturePhoto',3,2,id,points))
        assert(invoke('capturePhoto',1,2,id,points))
        assert(not invoke('capturePhoto',1,2,id,points) and shots==1)
        assert(invoke('getPatientCharts',3,2).charts[1].hasPhoto)
        local sent=0
        function TriggerLatentClientEvent(_,target,_,request,photo)
            assert(target==3 and request==7 and photo.anchors.head.y==.2);sent=sent+1
        end
        source=3;emit('ptech_mediora_medical:requestChartPhoto',2,id,7)
        players[3].PlayerData.job.onduty=false
        emit('ptech_mediora_medical:requestChartPhoto',2,id,7)
        assert(sent==1)
        """)

    def test_cancel_and_early_finish_do_not_consume(self):
        self.check("local task=start('pmediora_icepack');assert(invoke('treatment:finish',1,task.token).error and writes==0);task=start('pmediora_icepack');invoke('treatment:cancel',1,task.token);assert(finish(task).error and writes==0)")

    def test_other_medic_locked_replay_prevented(self):
        self.check("local task=start('pmediora_icepack');assert(start('pmediora_icepack',nil,3).error);assert(finish(task).ok);assert(invoke('treatment:finish',1,task.token).error and writes==4)")

    def test_permissions_and_character_rechecked(self):
        self.check("local task=start('pmediora_icepack');players[1].PlayerData.job.onduty=false;assert(finish(task).error and writes==0);players[1].PlayerData.job.onduty=true;task=start('pmediora_icepack');players[2].PlayerData.citizenid='replacement';assert(finish(task).error and writes==0)")

    def test_state_changes_and_insufficient_stock_never_charge(self):
        self.check("local task=start('pmediora_icepack');damage(2,'blunt',1);assert(finish(task).error and writes==0);stock.pmediora_icepack=3;assert(start('pmediora_icepack').error);stock.pmediora_icepack=10;task=start('pmediora_icepack');failRemoval=true;assert(finish(task).error and writes==0 and state().parts.right_leg.wounds.bruise)")

    def test_invalid_chart_and_self_use_tools_rejected(self):
        self.check("assert(start('pmediora_icepack',nil,nil,nil,'fake').error);assert(invoke('treatment:start',2,2,'right_leg','pmediora_protectivecast',nil,true).error and writes==0)")

    def test_snapshot_and_network_replay_cannot_modify_other_patients(self):
        self.check("local old=state();old.parts.right_leg.blunt=0;assert(state().parts.right_leg.blunt==75);damage(2,'blunt',1,nil,1);assert(state().parts.right_leg.blunt==75);assert(not invoke('wounds:get',2,'citizen-1').token)")

    def test_medicine_self_use_requires_no_duty_and_consumes_once(self):
        self.check("healths[2]=150;stock.pmediora_firstaidkit=1;players[2].PlayerData.job.onduty=false;local task=invoke('treatment:start',2,2,'upper_body','pmediora_firstaidkit',nil,true);assert(finish(task,2).ok and writes==1);assert(state().parts.right_leg.blunt==37.5 and state().parts.right_leg.fracture=='active')")

    def test_starvation_iv_restores_twenty_once_without_reviving(self):
        self.check('''
        local data=players[2].PlayerData
        data.metadata={hunger=0,thirst=65,stress=45,isdead=false}
        exports.qbx_core.SetMetadata=function(_,target,key,value) players[target].PlayerData.metadata[key]=value end
        stock.pmediora_ivdrip=2
        assert(start('pmediora_ivdrip','upper_body').error and writes==0)
        data.metadata.isdead=true
        assert(start('pmediora_ivdrip','upper_body').error and writes==0) -- recent trauma
        assert(not invoke('getPatientCharts',1,2).canReceiveIV)
        data.metadata.isdead=false;MedicalWoundServer.updateDeath(2)
        clock=clock+6000;data.metadata.isdead=true
        assert(invoke('getPatientCharts',1,2).canReceiveIV)
        local task=start('pmediora_ivdrip','upper_body')
        assert(task.count==1 and writes==0)
        assert(finish(task).ok and writes==1)
        assert(data.metadata.hunger==20 and data.metadata.thirst==85 and data.metadata.stress==25 and data.metadata.isdead)
        assert(not invoke('getPatientCharts',1,2).canReceiveIV)
        assert(start('pmediora_ivdrip','upper_body').error and writes==1)
        data.metadata.hunger=0;data.metadata.isdead=false
        assert(start('pmediora_ivdrip','upper_body').error and writes==1)
        ''')

    def test_admin_injury_and_damage_commands_validate_and_target_one_patient(self):
        self.check("""
        assert(restrictedCommands.medinjury==true and restrictedCommands.meddamage==true)
        local writes=0
        TriggerClientEvent=function(name,target,id,amount)
            if name=='ptech_mediora_medical:damageTest' then
                assert(target==3 and id=='citizen-3' and amount==25);writes=writes+1
            end
        end
        commands.medinjury(1,{'3','invalid','cut'})
        commands.medinjury(1,{'3','head','shot','heavy'})
        assert(#state(3).history==0 and #MedicalWoundServer.report(3).rows==0)
        commands.medinjury(1,{'3','head','cut','heavy'})
        commands.medinjury(1,{'3','left_arm','fracture','suppressed'})
        local wounds=MedicalWoundServer.report(3).rows
        assert(#wounds==2 and wounds[1].kind=='cut' and wounds[1].severity==2)
        assert(wounds[2].kind=='fracture' and wounds[2].suppressed and healths[3]==200)
        commands.meddamage(1,{'3','-25'});commands.meddamage(1,{'99','25'});assert(writes==0)
        commands.meddamage(1,{'3','25'});assert(writes==1)
        """)

    def test_admin_settings_recheck_permission_before_applying(self):
        self.check("""
        local opened, writes=0,0
        TriggerClientEvent=function(event,target,mode)
            if event=='ptech_mediora_medical:openTestSettings' then
                assert(target==1 and mode=='meddamage');opened=opened+1
            elseif event=='ptech_mediora_medical:damageTest' then
                assert(target==3);writes=writes+1
            end
        end
        commands.meddamage(1,{})
        assert(opened==1 and writes==0)
        local permitted=false
        function IsPlayerAceAllowed(src,ace) return src==1 and permitted and ace=='command.meddamage' end
        source=1;emit('ptech_mediora_medical:applyTestSettings','meddamage',{'3','25'})
        assert(writes==0)
        permitted=true
        emit('ptech_mediora_medical:applyTestSettings','meddamage',{'3',25})
        assert(writes==0)
        emit('ptech_mediora_medical:applyTestSettings','meddamage',{'3','25'})
        assert(writes==1)
        """)

    def test_admin_starvation_is_targeted_and_overrides_recent_damage_for_test(self):
        self.check("""
        local eventTarget, eventCitizen, calls
        calls=0
        exports.qbx_core.SetMetadata=function(_,target,key,value)
            calls=calls+1; players[target].PlayerData.metadata[key]=value
        end
        TriggerClientEvent=function(name,target,value)
            if name=='ptech_mediora_medical:starvationTest' then eventTarget,eventCitizen=target,value end
        end
        assert(restrictedCommands.medstarve==true)
        commands.medstarve(1,{});commands.medstarve(1,{'99'});assert(calls==0)
        players[2].PlayerData.metadata.hunger=80
        commands.medstarve(1,{'2'})
        assert(calls==1 and eventTarget==2 and eventCitizen==players[2].PlayerData.citizenid)
        assert(players[2].PlayerData.metadata.hunger==0)
        players[2].PlayerData.metadata.isdead=true
        MedicalWoundServer.updateDeath(2)
        assert(MedicalWoundServer.report(2).cause=='餓死（空腹値からの推定）')
        commands.medstarve(1,{'2'});assert(calls==1)
        """)

    def test_starvation_is_recorded_even_without_wounds(self):
        self.check('''
        players[3].PlayerData.metadata={hunger=0,isdead=true}
        clock=clock+5000
        assert(not invoke('inspect',1,3).error)
        local confirmation=invoke('confirm',1,3,{},true)
        clock=clock+confirmation.duration
        local chart=invoke('createChart',1,3).chart
        assert(chart.deathCause=='餓死（空腹値からの推定）' and #chart.injuries==1 and chart.injuries[1].kind=='starvation')
        ''')

    def test_drowning_is_treated_once_without_changing_needs(self):
        self.check("""
        local data=players[3].PlayerData
        data.metadata={hunger=47,thirst=55,stress=65}
        exports.qbx_core.SetMetadata=function(_,target,key,value) players[target].PlayerData.metadata[key]=value end
        stock.pmediora_ivdrip=2
        damage(3,'drowning',5);assert(#MedicalWoundServer.report(3).rows==0)
        deadFlags[3]=true
        clock=clock+1000
        assert(not invoke('inspect',1,3).error)
        local confirmation=invoke('confirm',1,3,{},true)
        clock=clock+confirmation.duration
        local chart=invoke('createChart',1,3).chart
        assert(chart.deathCause=='溺死' and #chart.injuries==1 and chart.injuries[1].kind=='drowning')
        assert(invoke('reviveChart',1,3,chart.chartId).error=='餓死・溺死の患者には先に点滴を使用してください')
        assert(finish(start('pmediora_ivdrip','upper_body',1,3,chart.chartId)).ok and writes==1)
        assert(data.metadata.hunger==47 and data.metadata.thirst==55 and data.metadata.stress==65)
        damage(3,'drowning',0)
        local result=invoke('getPatientCharts',1,3)
        assert(not result.canReceiveIV and #result.currentInjuries==0)
        assert(result.charts[1].treated['1'] and result.charts[1].deathCause=='溺死')
        assert(start('pmediora_ivdrip','upper_body',1,3,chart.chartId).error)
        """)

    def test_persisted_chart_restores_read_only_after_resource_restart(self):
        self.check('''
        local storage={}
        json={
            encode=function(record) return MedicalWounds.copy(record) end,
            decode=function(record) return MedicalWounds.copy(record) end,
        }
        MySQL={
            ready=function(fn) fn() end,
            query={await=function(sql, args)
                if not args then return {} end
                local records={}
                for id, row in pairs(storage) do
                    if row[2]==args[1] then records[#records+1]={chart_id=id,record=row[4]} end
                end
                return records
            end},
            update={await=function(sql, row) storage[row[1]]=row;return 1 end},
        }
        ''')
        source = (ROOT/'main/server/server.lua').read_text(encoding='utf-8')
        self.lua.execute(source)
        self.check('''
        clock=clock+Config.Cooldown
        chartId=makeChart()
        assert(finish(start('pmediora_icepack')).ok)
        assert(invoke('getPatientCharts',1,2).charts[1].archived==false)
        ''')
        self.lua.execute(source)
        self.check('''
        local restored=invoke('getPatientCharts',1,2).charts[1]
        assert(restored.chartId==chartId and restored.archived and not restored.canTreat)
        assert(restored.totalCharge==500000 and restored.treatmentCharges[1].siteCount==1)
        assert(#restored.currentInjuries==1 and restored.currentInjuries[1].kind=='fracture')
        assert(invoke('billChart',1,2,chartId).error)
        ''')

    def test_manual_invoice_validates_total_and_preserves_treatment_charges(self):
        self.check('''
        assert(invoke('billChart',1,2,chartId,nil,125000).error)
        assert(finish(start('pmediora_icepack')).ok)
        local resourceState=GetResourceState
        GetResourceState=function(name)
            if name=='okokBilling' or name=='oxmysql' then return 'started' end
            return resourceState(name)
        end
        local saved
        exports.oxmysql={insert_async=function(_,sql,values) saved=values;return 17 end}
        for _, amount in ipairs({0, -1, 1.5, 100000001, '125000'}) do
            assert(invoke('billChart',1,2,chartId,nil,amount).error and not saved)
        end
        assert(invoke('billChart',1,2,chartId,nil,125000).ok)
        assert(saved[7]==125000 and saved[8]:find('125000'))
        local chart=invoke('getPatientCharts',1,2).charts[1]
        assert(chart.invoiceTotal==125000 and chart.totalCharge==500000)
        ''')

    def test_trauma_can_be_revived_and_treated_afterward(self):
        self.check('''
        deadFlags[2]=true
        exports.wasabi_ambulance={RevivePlayer=function(_,target) deadFlags[target]=false end}
        assert(invoke('reviveChart',1,2,chartId).ok)
        assert(state().parts.right_leg.wounds.bruise)
        assert(finish(start('pmediora_icepack')).ok)
        ''')

    def test_no_full_health_or_dead_kit_consumption(self):
        self.check("stock.pmediora_firstaidkit=2;assert(invoke('treatment:start',2,2,'head','pmediora_firstaidkit',nil,true).error);players[2].PlayerData.metadata.isdead=true;healths[2]=100;assert(invoke('treatment:start',1,2,'head','pmediora_firstaidkit',chartId).error and writes==0)")

    def test_drowning_and_hunger_without_inventing_body_wounds(self):
        self.check("healths[3]=100;damage(3,'drowning',2);assert(MedicalWoundServer.report(3).cause=='溺死' and #MedicalWoundServer.report(3).rows==0);players[1].PlayerData.metadata.isdead=true;players[1].PlayerData.metadata.hunger=0;MedicalWoundServer.updateDeath(1);assert(MedicalWoundServer.report(1).cause:find('餓死'))")

    def test_unknown_hp_damage_does_not_gain_a_fictitious_wound(self):
        self.check("local rev=state().revision;damage(2,'unknown',20);assert(state().revision==rev);damage(2,'blunt',0/0);assert(state().revision==rev)")


CLIENT_HARNESS = '''
function GetHashKey(name) return name end
function GetWeaponDamageType(weapon) return weapon=='GUN' and 3 or 0 end
function IsPedDeadOrDying() return false end
function IsPedInAnyVehicle() return false end
function IsPedSwimming() return false end
function IsPedSwimmingUnderWater() return false end
function IsEntityAttached() return false end
function IsPedJumping() return jumping==true end
function IsPedClimbing() return false end
function IsPedVaulting() return false end
function IsPedDiving() return false end
function IsPedRagdoll() return false end
function CanPedRagdoll() return true end
function GetPedLastDamageBone() return true,51826 end
function SetPedToRagdoll() trips=trips+1 end
function SetEntityHealth(ped,hp) healths[ped]=hp end
function ApplyDamageToPed(ped,loss) healths[ped]=healths[ped]-loss; selfDamage=selfDamage+loss end
function TriggerClientEvent(name,target,value)
 if target==1 then local previous=source;source=65535;emit(name,value);source=previous end
end
LocalPlayer={state={dead=false}};trips=0;selfDamage=0
'''


class ClientTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        self.lua.execute(SERVER_HARNESS)
        self.lua.execute(CLIENT_HARNESS)
        for path in ['config.lua','main/shared/shared.lua','main/shared/wounds.lua','main/server/wounds.lua','main/client/wounds.lua']:
            self.lua.execute((ROOT/path).read_text(encoding='utf-8'))
        self.lua.execute("math.random=function(a,b)return a or 0 end;MedicalWoundClient.refresh()")

    def check(self, code):
        self.lua.execute(code)

    def test_actual_hp_loss_not_base_damage_and_no_duplicate_from_same_health(self):
        self.check("healths[1]=180;MedicalWoundClient.sampleDamage('WEAPON_UNARMED','right_leg');assert(state(1).parts.right_leg.blunt==30);MedicalWoundClient.sampleDamage('WEAPON_UNARMED','right_leg');assert(state(1).parts.right_leg.blunt==30)")

    def test_pin_adds_on_zero_loss_then_doubles_burn_and_does_not_loop(self):
        self.check("MedicalWoundClient.sampleDamage('WEAPON_STUNGUN','right_leg');assert(state(1).parts.right_leg.wounds.pin);healths[1]=190;MedicalWoundClient.sampleDamage('WEAPON_FIRE','right_leg');assert(healths[1]==180 and selfDamage==10 and state(1).parts.right_leg.sharp==10)")

    def test_bleeding_ticks_once_per_second_and_never_increases_accumulation(self):
        self.check("damage(1,'shot',40);local b=state(1).parts.right_leg.blunt;MedicalWoundClient.step();assert(selfDamage==2);MedicalWoundClient.step();assert(selfDamage==2 and state(1).parts.right_leg.blunt==b);clock=clock+1000;MedicalWoundClient.step();assert(selfDamage==4)")

    def test_active_fracture_trips_but_walking_and_dead_do_not(self):
        self.check("damage(1,'blunt',70);MedicalWoundClient.step();assert(trips==0);jumping=true;MedicalWoundClient.step();assert(trips==1);MedicalWoundClient.step();assert(trips==1);players[1].PlayerData.metadata.isdead=true;clock=clock+4000;MedicalWoundClient.step();assert(trips==1)")

    def test_suppressed_fracture_action_hurts_and_reenters_same_injury_chain(self):
        self.check("MedicalWoundClient.send('right_leg','blunt',70);stock.pmediora_painkiller=1;local task=invoke('treatment:start',1,1,'right_leg','pmediora_painkiller',nil,true);assert(finish(task,1).ok);jumping=true;MedicalWoundClient.step();assert(selfDamage==1 and trips==0);assert(state(1).parts.right_leg.fracture=='active')")

    def test_character_switch_and_old_update_are_discarded(self):
        self.check("local old=MedicalWoundServer.get(1);players[1].PlayerData.citizenid='other';MedicalWoundClient.refresh();assert(not MedicalWoundClient.apply(old));healths[1]=180;MedicalWoundClient.sampleDamage('WEAPON_UNARMED','head');assert(state(1).parts.head.blunt>0 and not state(1).parts.right_leg.wounds.blunt)")

    def test_settings_dialog_sends_selected_injury(self):
        self.check("""
        local opened, submitted=0,0
        lib.inputDialog=function(_,fields)
            assert(#fields==3 and #fields[2].options==7);opened=opened+1
            return {3,'left_arm','bruise:heavy'}
        end
        TriggerServerEvent=function(event,mode,args)
            assert(event=='ptech_mediora_medical:applyTestSettings' and mode=='medinjury')
            assert(args[1]=='3' and args[2]=='left_arm' and args[3]=='bruise' and args[4]=='heavy')
            submitted=submitted+1
        end
        source=1;emit('ptech_mediora_medical:openTestSettings','medinjury')
        assert(opened==0)
        source=65535;emit('ptech_mediora_medical:openTestSettings','medinjury')
        assert(opened==1 and submitted==1)
        """)

    def test_damage_event_requires_server_and_current_character(self):
        self.check("""
        source=1;emit('ptech_mediora_medical:damageTest','citizen-1',25);assert(healths[1]==200)
        source=65535;emit('ptech_mediora_medical:damageTest','other',25);assert(healths[1]==200)
        emit('ptech_mediora_medical:damageTest','citizen-1',25);assert(healths[1]==175)
        emit('ptech_mediora_medical:damageTest','citizen-1',300);assert(healths[1]==0)
        """)

    def test_starvation_event_only_accepts_server_and_current_character(self):
        self.check("""
        source=1;emit('ptech_mediora_medical:starvationTest','citizen-1');assert(healths[1]==200)
        source=65535;emit('ptech_mediora_medical:starvationTest','other');assert(healths[1]==200)
        source=65535;emit('ptech_mediora_medical:starvationTest','citizen-1');assert(healths[1]==0)
        """)

    def test_health_event_is_server_only_and_does_not_revive(self):
        self.check("healths[1]=150;source=0;emit('ptech_mediora_medical:health',100,'citizen-1');assert(healths[1]==150);source=65535;emit('ptech_mediora_medical:health',15,'citizen-1');assert(healths[1]==165);players[1].PlayerData.metadata.isdead=true;emit('ptech_mediora_medical:health',100,'citizen-1');assert(healths[1]==165)")


class NativeFlowTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        self.lua.execute(SERVER_HARNESS)
        self.lua.execute(CLIENT_HARNESS)
        for path in ['config.lua','main/shared/shared.lua','main/shared/wounds.lua',
                     'main/server/wounds.lua','main/server/fractures.lua','main/server/server.lua',
                     'main/client/nui.lua','main/client/ui.lua','main/client/wounds.lua',
                     'main/client/treatment.lua','main/client/client.lua']:
            self.lua.execute((ROOT/path).read_text(encoding='utf-8'))
        self.lua.execute("math.random=function(a,b)return a or 0 end;stock.pmediora_icepack=10;damage(2,'blunt',70)")

    def check(self, code):
        self.lua.execute(code)

    def test_real_diagnosis_and_nui_treatment_use_server_model_end_to_end(self):
        self.check("diagnose();assert(latest().action=='charts:open');local r=nui('getCharts',{targetId=2});assert(r.charts[1].injuries[1].kind=='bruise');local done=nui('treat',{part='right_leg',item='pmediora_icepack',chartId=r.charts[1].chartId,targetId=3});assert(done.ok and writes==4 and done.result.currentInjuries[1].kind=='fracture');assert(#state(3).history==0)")

    def test_closed_ui_during_progress_does_not_consume(self):
        self.check("diagnose();local r=nui('getCharts',{targetId=2});local waited=Wait; Wait=function(ms)waited(ms);MedicalUI.close()end;local result=nui('treat',{part='right_leg',item='pmediora_icepack',chartId=r.charts[1].chartId});assert(result.error and writes==0 and state().parts.right_leg.wounds.bruise)")

    def test_new_patient_search_cancels_pending_treatment(self):
        self.check("diagnose();local r=nui('getCharts',{targetId=2});local waited=Wait; Wait=function(ms)waited(ms);nui('getCharts',{targetId=3})end;local result=nui('treat',{part='right_leg',item='pmediora_icepack',chartId=r.charts[1].chartId});assert(result.error and writes==0)")

    def test_current_tablet_treatment_reopens_and_records_actual_quantity(self):
        self.check('''
        players[2].PlayerData.metadata.isdead=true
        healths[2]=100
        diagnose()
        local chart=nui('getCharts',{targetId=2}).charts[1]
        local result=nui('treatChartInjury',{targetId=3,part='right_leg',item='pmediora_icepack',chartId=chart.chartId})
        assert(result.started and writes==4)
        assert(not state().parts.right_leg.wounds.bruise and state().parts.right_leg.fracture=='active')
        assert(#state(3).history==0)
        assert(latest().action=='charts:open' and latest().data.openTreatment)
        local receipt=nui('getCharts',{targetId=2}).charts[1]
        assert(receipt.charges[1].quantity==4 and receipt.totalCharge==500000)
        assert(#receipt.currentInjuries==1 and receipt.currentInjuries[1].kind=='fracture')
        ''')

    def test_current_tablet_cancel_does_not_consume_or_add_invoice_lines(self):
        self.check('''
        diagnose()
        local chart=nui('getCharts',{targetId=2}).charts[1]
        IsDisabledControlJustPressed=function()return true end
        local result=nui('treatChartInjury',{part='right_leg',item='pmediora_icepack',chartId=chart.chartId})
        assert(result.started and writes==0 and state().parts.right_leg.wounds.bruise)
        local receipt=invoke('getPatientCharts',1,2).charts[1]
        assert(#receipt.charges==0 and receipt.totalCharge==0)
        ''')

    def test_invoice_requires_billable_treatment_or_revival(self):
        self.check('''
        diagnose()
        local chart=nui('getCharts',{targetId=2}).charts[1]
        assert(invoke('billChart',1,2,chart.chartId).error)
        assert(invoke('reviveChart',1,2,chart.chartId).error)
        ''')


if __name__ == '__main__':
    unittest.main()
