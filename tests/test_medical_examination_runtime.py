"""Diagnosis timing, patient notices and cleanup using the actual Lua callbacks."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

MODULE = Path(__file__).resolve().parents[1] / 'resources' / '[ptech]' / '[mediora]' / 'ptech_mediora_medical'
HARNESS = '''
callbacks, events, netEvents, commands, timers, sent, notices, messages, trace = {}, {}, {}, {}, {}, {}, {}, {}, {}
now = 1000
local vector = {}
vector.__index = vector
vector.__sub = function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},vector) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vec(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
players = {
  [1]={ped=11,coords=vec(0,0,0),state={},data={citizenid='medic-1',job={name='ambulance',onduty=true},metadata={}}},
  [2]={ped=22,coords=vec(1,0,0),state={dead='dead'},data={citizenid='patient-2',metadata={isdead=true}}},
  [3]={ped=33,coords=vec(0,1,0),state={},data={citizenid='medic-3',job={name='ambulance',onduty=true},metadata={}}},
}
exports=setmetatable({
  qbx_core={GetPlayer=function(_,id) return players[id] and {PlayerData=players[id].data} end,
    GetPlayerData=function() return players[1].data end},
  wasabi_ambulance={diagnosePlayer=function(_,id)
    assert(id==2); trace[#trace+1]='wasabi'
    if failWasabi then error('export failed') end
    return observed or {}
  end},
  ptech_mediora_manager={openCharts=function(_,target,chartId)
    trace[#trace+1]='chart'; openedChart={target=target,id=chartId}
  end},
}, {__call=function() end})
lib={notify=function(data) notices[#notices+1]=data end,
  callback={register=function(name,fn) callbacks[name]=fn end,
    await=function(name,_,...) return callbacks[name](1,...) end},
  progressCircle=function(options)
    trace[#trace+1]='progress'; progress=options
    if failProgress then error('progress failed') end
    now=now+options.duration
    return not cancelProgress
  end,
}
MedicalUI={describe=function() return '' end,show=function(snapshot) shown=snapshot end}
function MedicalNuiSend(_,message) messages[#messages+1]=message end
function RegisterNetEvent(name,fn) netEvents[name]=fn end
function RegisterCommand(name,fn) commands[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function SetTimeout(duration,fn) timers[#timers+1]={duration=duration,fn=fn} end
function TriggerClientEvent(name,target,active) sent[#sent+1]={name=name,target=target,active=active} end
function GetGameTimer() return now end
function GetResourceState() return 'started' end
function Player(id) return {state=players[id].state} end
function GetPlayerPed(id) return players[id] and players[id].ped or 0 end
function GetPlayerRoutingBucket(id) return players[id].bucket or 0 end
function GetEntityCoords(ped)
  for _,p in pairs(players) do if p.ped==ped then return p.coords end end
  error('missing ped')
end
function GetEntityHealth() return 200 end
function call(name,id,...) return callbacks['ptech_mediora_medical:'..name](id,...) end
function injurySet(count)
  local parts={'head','upper_body','lower_body','left_arm','right_arm','left_leg','right_leg'}
  local injuries={}
  for i=1,count do injuries[parts[i]]={type='beat',data={level=2,bleed=1}} end
  return injuries
end
function begin(id,count)
  assert(not call('inspect',id,2).error)
  return call('confirm',id,2,injurySet(count),true)
end
'''


class ExaminationHarness(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for path in ['config/config.lua', 'main/shared/shared.lua', 'main/server/server.lua']:
            self.lua.execute((MODULE / path).read_text(encoding='utf-8'))


class ExaminationRuntimeTests(ExaminationHarness):
    def test_duration_counts_parts_caps_at_six_seconds_and_saves_observation(self):
        self.lua.execute('''
        for count=0,7 do
          now=now+2000
          local result=begin(1,count)
          assert(result.duration==math.min(1000+count*1000,6000))
          assert(sent[#sent].target==2 and sent[#sent].active)
          now=now+result.duration
          -- 保存時に別の観察を渡しても、演出開始時の内容だけが記録される。
          local saved=call('createChart',1,2,injurySet(7),true)
          assert(not sent[#sent].active)
          if count==0 then assert(saved.noChart and not saved.chart)
          else
            assert(#saved.chart.injuries==count)
            assert(saved.chart.injuries[1].severity==2 and saved.chart.injuries[1].bleed==1)
          end
        end
        ''')

    def test_failed_and_unsupported_observations_are_not_one_second_exams(self):
        self.lua.execute('''
        for _,case in ipairs({{value={},success=false},{value='invalid',success=true},
            {value={neck={type='beat'}},success=true}}) do
          now=now+2000
          assert(not call('inspect',1,2).error)
          assert(call('confirm',1,2,case.value,case.success).error)
          assert(call('createChart',1,2).error)
        end
        assert(#sent==0)
        ''')

    def test_patient_change_and_range_are_rechecked_before_notice_and_chart(self):
        self.lua.execute('''
        assert(not call('inspect',1,2).error)
        players[2].coords=vec(10,0,0)
        assert(call('confirm',1,2,injurySet(1),true).error and #sent==0)
        players[2].coords=vec(1,0,0); now=now+2000
        local result=begin(1,1)
        now=now+result.duration; players[2].coords=vec(10,0,0)
        assert(call('createChart',1,2).error and not sent[#sent].active)
        players[2].coords=vec(1,0,0); now=now+2000
        assert(not call('inspect',1,2).error)
        players[2].data.citizenid='replacement'
        assert(call('confirm',1,2,injurySet(1),true).error)
        assert(not sent[#sent].active)
        ''')

    def test_cancel_and_early_finish_remove_notice_without_chart(self):
        self.lua.execute('''
        begin(1,2)
        assert(call('createChart',1,2).error and not sent[#sent].active)
        now=now+2000; begin(1,2)
        call('cancel',1,2)
        assert(not sent[#sent].active and call('createChart',1,2).error)
        ''')

    def test_another_active_medic_keeps_patient_notice_visible(self):
        self.lua.execute('''
        begin(1,1); local result=begin(3,2)
        call('cancel',1,2)
        assert(sent[#sent].active)
        now=now+result.duration
        assert(call('createChart',3,2).chart and not sent[#sent].active)
        ''')

    def test_timeout_cleans_up_and_old_timer_cannot_end_next_exam(self):
        self.lua.execute('''
        begin(1,1); local firstExpiry=timers[#timers].fn
        call('cancel',1,2); now=now+2000
        begin(1,1); local before=#sent
        firstExpiry()
        assert(#sent==before)
        timers[#timers].fn()
        assert(not sent[#sent].active and call('createChart',1,2).error)
        ''')

    def test_disconnect_cleans_up_medic_and_patient_exams(self):
        self.lua.execute('''
        begin(1,1); source=1; players[1]=nil; events.playerDropped()
        assert(not sent[#sent].active)
        begin(3,1); source=2; players[2]=nil; events.playerDropped()
        assert(call('createChart',3,2).error)
        ''')


class ExaminationClientTests(ExaminationHarness):
    # The server tests above use independent runtimes. These add the real entrypoint.
    def setUp(self):
        super().setUp()
        self.lua.execute('Config.Target.Enabled=false')
        self.lua.execute((MODULE / 'main/client/client.lua').read_text(encoding='utf-8'))

    def test_command_observes_before_progress_and_uses_server_duration(self):
        self.lua.execute('''
        observed=injurySet(2)
        commands.pmedical(0,{'diagnose','2'})
        assert(table.concat(trace,',')=='wasabi,progress,chart')
        assert(progress.duration==3000 and openedChart.target==2 and not sent[#sent].active)
        ''')

    def test_cancel_and_exception_cleanup_and_allow_next_diagnosis(self):
        self.lua.execute('''
        observed=injurySet(1); cancelProgress=true
        commands.pmedical(0,{'diagnose','2'})
        assert(not openedChart and not sent[#sent].active)
        now=now+2000; cancelProgress=false; failProgress=true
        commands.pmedical(0,{'diagnose','2'})
        assert(not openedChart and not sent[#sent].active)
        now=now+2000; failProgress=false
        commands.pmedical(0,{'diagnose','2'})
        assert(openedChart)
        ''')

    def test_export_failure_does_not_run_progress_or_notify_patient(self):
        self.lua.execute('''
        failWasabi=true
        commands.pmedical(0,{'diagnose','2'})
        assert(not progress and #sent==0 and not openedChart)
        assert(notices[#notices].type=='error')
        ''')

    def test_patient_notice_and_unload_do_not_capture_controls(self):
        self.lua.execute('''
        netEvents['ptech_mediora_medical:examinationStatus'](true)
        assert(messages[#messages].action=='examination:status' and messages[#messages].data.active)
        events['QBCore:Client:OnPlayerUnload']()
        assert(not messages[#messages].data.active)
        ''')


if __name__ == '__main__':
    unittest.main()
