local root=arg[1]
local distanceChecks=0
local vectorMT={}
local function vec(x,y,z) return setmetatable({x=x,y=y,z=z},vectorMT) end
vectorMT.__sub=function(a,b) distanceChecks=distanceChecks+1 return vec(a.x-b.x,a.y-b.y,a.z-b.z) end
vectorMT.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
vector3=vec
dofile(root..'/config/config.lua')
dofile(root..'/config/items.lua')
dofile(root..'/config/recipes.lua')
local thread,menu,playerCoords,now,pressed,helps,draws
local function runAt(coords,tickCount)
  menu=nil; playerCoords=coords; now=1000; pressed=true; helps=0;draws=0;distanceChecks=0
  lib={
    callback={await=function(name,isAsync,hospitalId) assert(name=='ptech_mediora_logistics:server:getHospitalMultiplier');return 1.25 end},
    registerContext=function(m) menu=m end,
    showContext=function(id) assert(menu.id==id) end,
    notify=function() end,
  }
  PlayerPedId=function() return 1 end
  GetEntityCoords=function() return playerCoords end
  GetGameTimer=function() return now end
  BeginTextCommandDisplayHelp=function() end
  AddTextComponentSubstringPlayerName=function() helps=helps+1 end
  EndTextCommandDisplayHelp=function() end
  DrawMarker=function() draws=draws+1 end
  IsControlJustReleased=function(_,key) assert(key==38); if pressed then pressed=false;return true end;return false end
  Wait=function(ms) coroutine.yield(ms) end
  CreateThread=function(fn) thread=fn end
  RegisterNetEvent=function() end
  assert(loadfile(root..'/main/client/client.lua'))()
  local co=coroutine.create(thread)
  for i=1,(tickCount or 1) do
    local ok,err=coroutine.resume(co)
    assert(ok,err)
    now=now+16
  end
  return menu,helps,draws,distanceChecks
end
local m,h,d,ops=runAt(Config.Hospitals[1].coords)
assert(m and #m.options==5,'Pillbox must offer 5 entries')
assert(m.options[1].description:find('×1.25',1,true),'Daily rate missing')
assert(m.options[2].title==Config.Text.menuCraftSpBox,'Special menu label mismatch')
print('PASS client Pillbox menu with rate and buy/sell')
m,h,d,ops=runAt(Config.Hospitals[7].coords)
assert(m and #m.options==3,'Non-Pillbox should not offer buy/sell')
print('PASS client other hospital menu excludes buy/sell')
local hospital=Config.Hospitals[1]
m,h,d,ops=runAt(vec(hospital.coords.x+10,hospital.coords.y,hospital.coords.z))
assert(m==nil and h==0 and d>0,'Cannot interact from 10m, marker still renders')
print('PASS interact distance 2m, marker 20m')
m,h,d,ops=runAt(Config.Hospitals[1].coords,100)
assert(ops<400, 'Unexpected every-frame full scan '..ops)
print('PASS throttled scan: '..ops..' vector calculations / 100 updates')
print('PASS 4 client tests')
