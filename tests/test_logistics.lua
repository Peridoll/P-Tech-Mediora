-- テスト環境での静的結合テスト。FiveM / Qbox / ox_inventory の実機試験ではない。
local root = arg[1]
assert(root)
local function vec(x,y,z) return setmetatable({x=x,y=y,z=z}, {
  __sub = function(a,b) return vec(a.x-b.x,a.y-b.y,a.z-b.z) end,
  __len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end,
}) end
vector3=vec
local callbacks, events, registeredExports = {},{},{}
local kvps, jsonObjects, serial = {},{},0
local function deepcopy(x)
  if type(x)~='table' then return x end
  local r={}
  for k,v in pairs(x) do r[k]=deepcopy(v) end
  return r
end
json={encode=function(value)
  serial=serial+1
  local key='J'..serial
  jsonObjects[key]=deepcopy(value)
  return key
end, decode=function(key) return deepcopy(jsonObjects[key]) end}
GetResourceKvpString=function(key) return kvps[key] end
SetResourceKvp=function(key,v) kvps[key]=v end
GetResourceKvpInt=function(key) return kvps[key] or 0 end
SetResourceKvpInt=function(key,v) kvps[key]=v end
local current=1793260800
local originalTime=os.time
os.time=function() return current end
GetGameTimer=function() return 14500 end
GetPlayerIdentifierByType=function(source) return 'license:'..source end
GetPlayerIdentifier=function(source) return 'license:'..source end
GetHashKey=function(str)
  local h=0 for i=1,#str do h=(h*131+str:byte(i))%2147483647 end
  return h
end
local positions,invs,bank,notifications = {},{},{},{}
local function inventoryOf(id)
  if not invs[id] then invs[id]={} end
  return invs[id]
end
local function match(slot,name,metadata)
  if slot.name~=name then return false end
  if metadata then
    for k,v in pairs(metadata) do if slot.metadata[k] ~= v then return false end end
  end
  return true
end
local ox={}
function ox:CanCarryItem(source, name, count, metadata) return true end
function ox:AddItem(source,name,count,metadata)
  local inv=inventoryOf(source)
  for _,slot in ipairs(inv) do
    if match(slot,name,metadata) and (not metadata or slot.metadata.stackKey==metadata.stackKey) then
      slot.count=slot.count+count
      return true
    end
  end
  inv[#inv+1]={name=name,count=count,metadata=deepcopy(metadata or {})}
  return true
end
function ox:RemoveItem(source,name,count,metadata,slotIndex)
  local inv=inventoryOf(source)
  for _,slot in ipairs(inv) do
    if match(slot,name,metadata) and slot.count>=count then
      slot.count=slot.count-count
      return true
    end
  end
  return false
end
function ox:GetItemCount(source,name)
  local count=0
  for _,slot in ipairs(inventoryOf(source)) do if slot.name==name then count=count+slot.count end end
  return count
end
function ox:GetInventoryItems(source) return inventoryOf(source) end
function ox:GetSlot(source,slotIndex) return inventoryOf(source)[slotIndex] end
function ox:registerHook(event,fn,args) end
local qb={}
function qb:GetPlayer(source) return {PlayerData={job={name='ambulance',onduty=true}}} end
function qb:AddMoney(source,account,amount,reason) bank[source]=(bank[source] or 0)+amount return true end
function qb:RemoveMoney(source,account,amount,reason)
  if (bank[source] or 0)<amount then return false end
  bank[source]=bank[source]-amount
  return true
end
exports=setmetatable({qbx_core=qb,ox_inventory=ox},{__call=function(_,name,fn) registeredExports[name]=fn end})
GetPlayerPed=function(source) return source end
GetEntityCoords=function(ped) return positions[ped] or vec(9999,9999,9999) end
TriggerClientEvent=function(ev,source,txt) notifications[#notifications+1]={source=source,text=txt} end
RegisterNetEvent=function(ev,fn) events[ev]=fn end
CreateThread=function(fn) end
lib={callback={register=function(name,fn) callbacks[name]=fn end}}

assert(dofile(root..'/config/config.lua')==nil)
assert(dofile(root..'/config/items.lua')==nil)
assert(dofile(root..'/config/recipes.lua')==nil)
assert(loadfile(root..'/main/server/server.lua'))()
local function at(source,point) positions[source]=point.coords end
local function run(ev,source,...) _G.source=source; return assert(events[ev],ev)(...) end
local function cb(name,source,...) return assert(callbacks['ptech_mediora_logistics:server:'..name],name)(source,...) end
local function ok(cond,msg) assert(cond,msg) end
local function eq(a,b,msg) assert(a==b, (msg or 'value')..' '..tostring(a)..' vs '..tostring(b)) end
local tests=0
local function test(name, fn) fn();tests=tests+1; print('PASS '..name) end
local point1,point2=Config.CollectPoints[1],Config.CollectPoints[2]
local pillbox=Config.Hospitals[1]
local sandy=Config.Hospitals[7]
local box=Config.Procurement.boxItem
local special=Config.Procurement.specialBoxItem
local oldRandom=math.random
math.random=function(n,m)
  if m then return n end
  return 1
end

test('per-player / per-point cooldown',function()
  at(1,point1);at(2,point1)
  run('ptech_mediora_logistics:server:collect',1,point1.id)
  eq(ox:GetItemCount(1,box),1,'first collect')
  run('ptech_mediora_logistics:server:collect',1,point1.id)
  eq(ox:GetItemCount(1,box),1,'same player cooldown')
  run('ptech_mediora_logistics:server:collect',2,point1.id)
  eq(ox:GetItemCount(2,box),1,'another player')
  at(1,point2)
  run('ptech_mediora_logistics:server:collect',1,point2.id)
  eq(ox:GetItemCount(1,box),2,'another point')
  current=current+901
  at(1,point1)
  run('ptech_mediora_logistics:server:collect',1,point1.id)
  eq(ox:GetItemCount(1,box),3,'cooldown expires')
end)

test('daily rates stable, bounded and change between days',function()
  at(1,pillbox)
  local rates={}
  for _,h in ipairs(Config.Hospitals) do
    at(1,h)
    local r=cb('getHospitalMultiplier',1,h.id)
    eq(r,cb('getHospitalMultiplier',1,h.id),'repeat')
    ok(r>=0.80 and r<=1.60,'bounds')
    rates[h.id]=r
  end
  local different=false
  current=current+86400
  for _,h in ipairs(Config.Hospitals) do
    at(1,h)
    if rates[h.id]~=cb('getHospitalMultiplier',1,h.id) then different=true end
  end
  ok(different,'daily change')
end)

test('ordinary box payout includes hospital day rate',function()
  at(1,pillbox)
  local r=cb('getHospitalMultiplier',1,pillbox.id)
  local before=bank[1] or 0
  local count=cb('getDeliverableCount',1,pillbox.id)
  eq(count,3)
  run('ptech_mediora_logistics:server:deliver',1,pillbox.id,3)
  -- fake random picks 5 first-aid kits @60,000 sell each; unopened box factor 1.20
  eq(bank[1]-before,math.floor(5*60000*1.2*r)*3,'payout')
  eq(ox:GetItemCount(1,box),0,'boxes deducted')
end)

test('trade catalog / action only at Pillbox',function()
  at(1,sandy)
  eq(#cb('getTradeCatalog',1,sandy.id,'buy'),0)
  local before=bank[1]
  run('ptech_mediora_logistics:server:tradeItem',1,sandy.id,'buy','ptech_medical_bandage',1)
  eq(bank[1],before,'restricted trade')
  at(1,pillbox)
  ok(#cb('getTradeCatalog',1,pillbox.id,'buy')>0,'Pillbox catalog')
end)

test('special box premium valid only creation date, daily rate still applies after expiration',function()
  at(1,pillbox)
  local rec=cb('getDailySpecial',1,pillbox.id)
  ok(rec~=nil,'daily recipe')
  -- For recipe ingredients ensure enough supply
  for itemId,required in pairs(rec.ingredients) do ox:AddItem(1,itemId,required*2) end
  run('ptech_mediora_logistics:server:craftDailySpecial',1,pillbox.id)
  eq(ox:GetItemCount(1,special),1,'special crafted')
  local target
  for _,hospital in ipairs(Config.Hospitals) do
    if hospital.id==rec.targetHospital then target=hospital break end
  end
  at(1,target)
  local rate=cb('getHospitalMultiplier',1,target.id)
  local totalBase=0
  for itemId,count in pairs(rec.ingredients) do totalBase=totalBase+((Config.Items[itemId].sellPrice or 0)*count) end
  local before=bank[1]
  run('ptech_mediora_logistics:server:deliver',1,target.id,1)
  eq(bank[1]-before,math.floor(totalBase*1.2*1.5*rate),'same-day premium')
  -- Another parcel, then next day: no special premium but new hospital multiplier
  at(1,pillbox)
  run('ptech_mediora_logistics:server:craftDailySpecial',1,pillbox.id)
  eq(ox:GetItemCount(1,special),1,'second special')
  current=current+86400
  at(1,target)
  local nextRate=cb('getHospitalMultiplier',1,target.id)
  local before2=bank[1]
  run('ptech_mediora_logistics:server:deliver',1,target.id,1)
  eq(bank[1]-before2,math.floor(totalBase*1.2*nextRate),'expired but day rate')
end)

print(('PASS %d behavioral tests'):format(tests))
os.time=originalTime
math.random=oldRandom
