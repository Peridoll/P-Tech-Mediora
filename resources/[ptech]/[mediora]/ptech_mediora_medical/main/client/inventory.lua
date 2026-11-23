MedicalInventoryClient = {}
local I=MedicalInventoryClient
local bagCounts,id,updatedAt={},nil,0
local suspended=false
local generation=0
local function identity()
    local data=exports.qbx_core:GetPlayerData()
    return not suspended and data and data.citizenid
end
local function rootCount(name)
    local ok,value=pcall(function()return exports.ox_inventory:Search('count',name)end)
    return ok and type(value)=='number'and value or 0
end
function I.count(name)
    local extra=0
    if identity()==id and GetGameTimer()-updatedAt<=2500 and rootCount('pmediora_medicalbag')>0 then extra=bagCounts[name]or 0 end
    return rootCount(name)+extra
end
function I.refresh()
    local current=identity()
    if not current or GetResourceState('ox_inventory')~='started'or rootCount('pmediora_medicalbag')<=0 then
        bagCounts,id,updatedAt={},current,GetGameTimer();return
    end
    local request=generation
    local ok,result=pcall(lib.callback.await,'ptech_mediora_medical:bagToolCounts',false)
    if request~=generation or identity()~=current then return end
    if ok and type(result)=='table'and result.citizenId==current and type(result.counts)=='table'then
        bagCounts,id,updatedAt=result.counts,current,GetGameTimer()
    end
end
AddEventHandler('QBCore:Client:OnPlayerUnload',function()
    suspended=true;generation=generation+1;bagCounts,id,updatedAt={},nil,0
end)
AddEventHandler('QBCore:Client:OnPlayerLoaded',function()suspended=false;generation=generation+1 end)
CreateThread(function()while true do I.refresh();Wait(1000)end end)
