"""Run with Python and lupa installed. FiveM services are mocked."""
from pathlib import Path

from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in root.rglob("*.lua"):
    lua.execute("assert(load(...))", path.read_text(encoding="utf-8"))

lua.execute("""
clock, paid, payout = 0, 0, true
callbacks, events, players, positions = {}, {}, {}, {}
function vec3(x,y,z)
    return setmetatable({x=x,y=y,z=z}, {
        __sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end,
        __len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
    })
end
os.time=function() return clock end
function GetGameTimer() return clock*1000 end
function Player(id) return {state=players[id].state} end
function GetPlayerPed(id) return id end
function GetEntityHealth(id) return 200 end
function GetPlayerRoutingBucket(id) return 0 end
function GetEntityCoords(id) return positions[id] end
function RegisterNetEvent(name,cb) events[name]=cb end
function AddEventHandler(name,cb) events[name]=cb end
function Wait() coroutine.yield() end
function CreateThread(cb) worker=coroutine.create(cb);assert(coroutine.resume(worker)) end
lib={callback={register=function(name,cb) callbacks[name]=cb end}}
exports={
 qbx_core={GetPlayer=function(_,id) return {PlayerData=players[id].data} end},
 ptech_mediora_core={AddPoints=function(_,id,amount,reason)
    if paymentHook then paymentHook() end
    if payout then paid=paid+amount end
    return payout
 end}
}
for id=1,2 do
 players[id]={data={citizenid='char'..id,job={name='ambulance',onduty=true},metadata={}},state={dead=0}}
 positions[id]=vec3(0,0,0)
end
function tick(seconds)
 clock=clock+seconds
 local ok,err=coroutine.resume(worker)
 assert(ok,err)
end
function call(name,id,...) return callbacks['ptech_mediora_hospital:'..name](id,...) end
function cancel(player,id,token)
 source=player;events['ptech_mediora_hospital:cancel'](id,token)
end
""")
lua.execute((root / "config.lua").read_text(encoding="utf-8"))
lua.execute((root / "main/shared/rules.lua").read_text(encoding="utf-8"))
lua.execute("""
Hospital.drawInterval=1
Hospital.activities.floor.cooldown={0,0}
Hospital.activities.floor.chance=100
Hospital.activities.floor.limit=2
Hospital.hospitals={test={limit=1,spots={
 {coords=vec3(0,0,0),activity='floor'},
 {coords=vec3(1,0,0),activity='floor'}
}}}
assert(Hospital.canWork(players[1].data,0))
assert(Hospital.canWork(players[1].data,false))
assert(Hospital.canWork(players[1].data,nil))
for _,state in ipairs({true,1,2,'dead','laststand'}) do
 assert(not Hospital.canWork(players[1].data,state))
end
""")
lua.execute((root / "main/server/activities.lua").read_text(encoding="utf-8"))
lua.execute("""
tick(1)
assert(#call('list',1)==1,'hospital cap')
local id=call('list',1)[1].id
local first=call('start',1,id)
assert(first and not call('start',2,id),'exclusive claim')
cancel(1,id,first)
local second=call('start',1,id)
assert(second and second~=first)
cancel(1,id,first)
assert(not call('start',2,id),'stale cancel must not free claim')
tick(8)
assert(not call('finish',1,id,first),'stale completion')
paymentHook=function()
 assert(not call('finish',1,id,second),'concurrent duplicate completion')
end
assert(call('finish',1,id,second))
paymentHook=nil
assert(paid==1 and not call('finish',1,id,second),'single payout')
tick(1)
id=call('list',1)[1].id
local token=call('start',1,id)
positions[1]=vec3(100,0,0)
tick(1)
assert(call('start',2,id),'leave area allows handover')
positions[1]=vec3(0,0,0)
source=2;events.playerDropped()
assert(call('start',1,id),'disconnect releases claim')
players[1].data.job.onduty=false
tick(1)
assert(not call('start',1,id),'off duty blocked')
players[1].data.job.onduty=true
assert(call('start',1,id))
players[1].data.metadata.inlaststand=true
tick(1)
assert(call('start',2,id),'laststand releases claim')
players[1].data.metadata.inlaststand=false
source=2;events.playerDropped()
token=call('start',1,id)
tick(8)
payout=false
assert(not call('finish',1,id,token),'failed points grant')
assert(#call('list',1)==1,'failed payment preserves task')
payout=true
token=call('start',2,id)
tick(8)
assert(call('finish',2,id,token) and paid==2,'payment retry')
tick(1)
id=call('list',1)[1].id
assert(call('start',1,id))
tick(24)
assert(call('start',2,id),'abandoned claim timeout')
""")
lua.execute("""
clock, finished, cancelled, hidden, cleared = 0,0,0,0,0
progressReady, cancelKey = true,false
QBX={PlayerData=players[1].data}
LocalPlayer={state={dead=0}}
function PlayerPedId() return 1 end
function PlayerId() return 1 end
function IsEntityDead() return false end
function IsPedInAnyVehicle() return false end
function DisableControlAction() end
function DisablePlayerFiring() end
function IsControlJustPressed() return cancelKey end
function IsDisabledControlJustPressed() return false end
function GetResourceState() return 'started' end
function TaskStartScenarioInPlace() end
function ClearPedTasks() cleared=cleared+1 end
function RegisterCommand() end
function TriggerServerEvent(name,id,token) cancelled=cancelled+1 end
function CreateThread(cb) poll=coroutine.create(cb) end
exports=setmetatable({
 ptech_mediora_core={
  showProgress=function() return progressReady,42 end,
  hideProgress=function(_,id) assert(id==42);hidden=hidden+1 end
 },
 ox_target={
  addSphereZone=function(_,zone) option=zone.options[1];return 1 end,
  removeZone=function() end
 }
},{__call=function(_,name,cb) if name=='CancelWork' then cancelExport=cb end end})
lib={
 progressActive=function() return false end,
 notify=function() end,
 callback={await=function(name,delay,id,token)
  if name:match('list$') then
   return {{id='client-task',coords=vec3(0,0,0),activity='floor',available=true}}
  end
  if name:match('start$') then return 10 end
  assert(token==10)
  finished=finished+1
  return true
 end}
}
""")
lua.execute((root / "main/client/activities.lua").read_text(encoding="utf-8"))
lua.execute("""
assert(coroutine.resume(poll))
function beginWork()
 local work=coroutine.create(option.onSelect)
 local ok,err=coroutine.resume(work)
 assert(ok,err)
 return work
end
function stepWork(work)
 clock=clock+1
 local ok,err=coroutine.resume(work)
 assert(ok,err)
end
local work=beginWork()
while coroutine.status(work)~='dead' do stepWork(work) end
assert(finished==1 and hidden==1 and cleared==1,'Core progress completes and cleans up')
work=beginWork()
assert(cancelExport())
stepWork(work)
assert(finished==1 and cancelled==1 and hidden==2,'export cancellation without reward')
work=beginWork()
QBX.PlayerData.job.onduty=false
stepWork(work)
assert(finished==1 and cancelled==2,'duty change cancels client work')
QBX.PlayerData.job.onduty=true
progressReady=false
work=beginWork()
assert(coroutine.status(work)=='dead' and cancelled==3,'unready Core releases claim')
""")
print("PASS: Lua syntax; server caps, claims, stale messages, payouts, handover, duty, laststand, retry, timeout; client Core progress, cancellation, cleanup")
