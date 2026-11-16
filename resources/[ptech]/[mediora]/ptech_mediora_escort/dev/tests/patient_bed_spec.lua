local events, exported, sent = {}, {}, {}
local caller = 'ptech_omnite_seating'
local buckets = {[1]=0,[2]=0,[3]=0}
local mt={__sub=function(a,b) return setmetatable({distance=math.abs(a.x-b.x)}, {__len=function(v) return v.distance end}) end}
local positions={[1]=setmetatable({x=0},mt),[2]=setmetatable({x=0},mt),[3]=setmetatable({x=0},mt)}
local states={}
local duty=true
for id=1,3 do
    states[id]={dead=id==2 and 'dead' or false}
    states[id].set=function(self,key,value) self[key]=value end
end
function Player(id) return {state=states[id]} end
function GetPlayerPing() return 10 end
function GetPlayerPed(id) return states[id] and id or 0 end
function DoesEntityExist() return true end
function GetEntityHealth() return 150 end
function GetEntityCoords(id) return positions[id] end
function GetPlayerRoutingBucket(id) return buckets[id] end
function GetVehiclePedIsIn() return 0 end
function GetResourceState() return 'stopped' end
function GetResourceKvpString() end
function GetInvokingResource() return caller end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler() end
function CreateThread() end
function TriggerClientEvent(...) sent[#sent+1]={...} end
exports=setmetatable({qbx_core={GetPlayer=function(_,id)
    return {PlayerData={citizenid=tostring(id),job={name='ambulance',onduty=duty},metadata={isdead=id==2}}}
end}},{__call=function(_,name,fn) exported[name]=fn end})
function runBedTransferSpecs()
    local transfer=exported.PreparePatientBed
    assert(transfer(1,2),'nearby uncarried patient can transfer')
    source=1 events['ptech_mediora_escort:server:start'](2)
    assert(states[1].emsEscorting==2 and states[2].emsEscortedBy==1,'patient carried before bed transfer')
    assert(not transfer(3,2),'another EMS cannot interrupt existing carrier')
    assert(states[2].emsEscortedBy==1,'denied transfer keeps carry session')
    caller='untrusted'
    assert(not transfer(1,2),'restricted export rejects other resources')
    caller='ptech_omnite_seating' duty=false
    assert(not transfer(1,2),'off-duty actor cannot transfer')
    duty=true buckets[2]=1
    assert(not transfer(1,2),'different routing bucket rejected')
    buckets[2]=0 positions[2].x=100
    assert(not transfer(1,2),'distant patient rejected')
    positions[2].x=0
    assert(transfer(1,2),'carrier can place own patient in bed')
    assert(not states[1].emsEscorting and not states[2].emsEscortedBy,'transfer clears both authoritative carry states')
    assert(sent[#sent-1][1]=='ptech_mediora_escort:client:released' and sent[#sent-1][2]==2,'patient detached with release ticket')
    assert(sent[#sent][1]=='ptech_mediora_escort:client:removeTarget' and sent[#sent][2]==1,'carrier animation released')
end
