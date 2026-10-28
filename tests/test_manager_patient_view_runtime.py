"""Patient-view lifecycle and NUI integration without a running FiveM client."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

MODULE = Path(__file__).resolve().parents[1] / 'resources' / '[ptech]' / '[mediora]' / 'ptech_mediora_manager'

HARNESS = '''
callbacks, events, api, messages, threads, cameras = {}, {}, {}, {}, {}, {}
rendered, cameraSequence = -1, 100
local vector = {}
vector.__index = vector
function vec(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
vector.__add=function(a,b) return vec(a.x+b.x,a.y+b.y,a.z+b.z) end
vector.__sub=function(a,b) return vec(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__mul=function(a,b) return vec(a.x*b,a.y*b,a.z*b) end
vector.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
players = {[1]={ped=11,coords=vec(0,0,0)}, [7]={ped=77,coords=vec(0,1,0)}}
citizenId='patient-7'
LocalPlayer={state={}}
exports=setmetatable({ptech_mediora_medical={getTreatmentItems=function() return {} end}},
  {__call=function(_,name,fn) api[name]=fn end})
lib={notify=function() end, callback={await=function(name,_,target)
  if name == 'ptech_mediora_medical:managerAccess' then return {name='Doctor'} end
  if onProbe then onProbe() end
  return {patient={serverId=7,citizenId=citizenId,name='Patient'},charts={}}
end}}
function GetResourceState() return 'started' end
function RegisterNUICallback(name,fn) callbacks[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function SendNUIMessage(message) messages[#messages+1]=message end
function SetNuiFocus() end
function GetCurrentResourceName() return 'ptech_mediora_manager' end
function PlayerPedId() return 11 end
function GetPlayerFromServerId(id) return players[id] and id or -1 end
function GetPlayerPed(id) return players[id] and players[id].ped or 0 end
function DoesEntityExist(ped) return ped==11 or ped==77 end
function GetEntityCoords(ped)
  for _,p in pairs(players) do if p.ped==ped then return p.coords end end
  error('missing ped')
end
function GetPedBoneCoords(ped,bone)
  local coords=GetEntityCoords(ped)
  if lying then return coords+vec(bone==31086 and .8 or -.8,0,.1) end
  return coords+vec(0,0,bone==31086 and 1.6 or .1)
end
function IsPedInAnyVehicle() return inVehicle==true end
function IsEntityAttached() return attached==true end
function IsEntityDead() return false end
function GetRenderingCam() return rendered end
function DoesCamExist(cam) return cameras[cam]~=nil end
function CreateCam()
  cameraSequence=cameraSequence+1
  cameras[cameraSequence]={}
  return cameraSequence
end
function SetCamCoord(cam,x,y,z) cameras[cam].coords=vec(x,y,z) end
function PointCamAtCoord(cam,x,y,z) cameras[cam].target=vec(x,y,z) end
function SetCamFov(cam,fov) cameras[cam].fov=fov end
function RenderScriptCams(active) rendered=active and cameraSequence or -1 end
function DestroyCam(cam) cameras[cam]=nil end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait() coroutine.yield() end
function invoke(name,data)
  local result
  callbacks[name](data or {},function(value) result=value end)
  return result
end
function prepare()
  api.openCharts(7)
  invoke('getCharts',{targetId=7})
end
function frame()
  for _,thread in ipairs(threads) do
    if coroutine.status(thread)~='dead' then
      local ok,err=coroutine.resume(thread)
      assert(ok,err)
    end
  end
end
'''


class ManagerPatientViewTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for rel in ('config/config.lua', 'main/client/patient_view.lua', 'main/client/client.lua'):
            self.lua.execute((MODULE / rel).read_text(encoding='utf-8'))

    def test_uses_verified_patient_and_tracks_standing_and_lying_pose(self):
        self.lua.execute('''
        prepare()
        assert(invoke('setPatientView',{active=true,targetId=999}).active)
        assert(cameras[rendered].target.y==1)
        local standingHeight=cameras[rendered].coords.z
        lying=true
        frame(); frame()
        assert(cameras[rendered].coords.z > standingHeight)
        assert(players[7].coords.y==1 and players[7].coords.z==0)
        assert(not invoke('setPatientView',{active=false}).active)
        assert(rendered==-1 and next(cameras)==nil)
        ''')

    def test_cannot_start_without_a_verified_chart_patient(self):
        self.lua.execute('''
        api.openCharts(7)
        assert(not invoke('setPatientView',{active=true,targetId=7}).active)
        assert(next(cameras)==nil)
        ''')

    def test_distant_and_carried_patients_keep_chart_only_view(self):
        self.lua.execute('''
        prepare()
        players[7].coords=vec(0,30,0)
        assert(not invoke('setPatientView',{active=true}).active)
        players[7].coords=vec(0,1,0)
        attached=true
        assert(not invoke('setPatientView',{active=true}).active)
        assert(next(cameras)==nil)
        ''')

    def test_moving_out_of_range_restores_normal_camera(self):
        self.lua.execute('''
        prepare()
        assert(invoke('setPatientView',{active=true}).active)
        players[7].coords=vec(0,30,0)
        frame(); frame()
        assert(rendered==-1 and next(cameras)==nil)
        assert(messages[#messages].action=='patientView:status')
        assert(not messages[#messages].data.active)
        ''')

    def test_close_during_server_recheck_cannot_reopen_camera(self):
        self.lua.execute('''
        prepare()
        onProbe=function() invoke('close') end
        assert(not invoke('setPatientView',{active=true}).active)
        assert(next(cameras)==nil and rendered==-1)
        ''')

    def test_reused_server_id_does_not_show_another_patient(self):
        self.lua.execute('''
        prepare()
        citizenId='another-patient'
        assert(not invoke('setPatientView',{active=true}).active)
        assert(next(cameras)==nil)
        ''')

    def test_stopping_resource_preserves_another_resources_camera(self):
        self.lua.execute('''
        prepare()
        assert(invoke('setPatientView',{active=true}).active)
        local own=rendered
        cameras[900]={}; rendered=900
        events.onResourceStop('ptech_mediora_manager')
        assert(rendered==900 and cameras[900] and not cameras[own])
        ''')

    def test_logout_cleans_up_the_active_camera(self):
        self.lua.execute('''
        prepare()
        assert(invoke('setPatientView',{active=true}).active)
        events['QBCore:Client:OnPlayerUnload']()
        assert(rendered==-1 and next(cameras)==nil)
        ''')


if __name__ == '__main__':
    unittest.main()
