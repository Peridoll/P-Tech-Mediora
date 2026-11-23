local C=Config.PrivateBilling
local prefix='ptech_mediora_medical:privateBill:'
local targetName=prefix..'target'
local opened=false
local session
local opening=false
local epoch=0
local function allowed(manager)
    local d=exports.qbx_core:GetPlayerData()
    local j=d and d.job
    local g=j and (type(j.grade)=='table'and j.grade.level or j.grade)
    return j and j.name==C.Job and (not C.RequireDuty or j.onduty)
        and (not manager or (tonumber(g)or -1)>=C.ManagerGrade)
end
local function request(method,...)
    local ok,result=pcall(lib.callback.await,prefix..method,false,...)
    return ok and result or {error='請求システムに接続できません'}
end
local function close()
    epoch=epoch+1;opened=false;session=nil
    SetNuiFocus(false,false)
    SendNUIMessage({action='private-billing:close'})
end
local function show(data)
    if MedicalUI then MedicalUI.close()end
    opened=true;session=data.token
    SetNuiFocus(true,true)
    SendNUIMessage({action='private-billing:open',data=data})
end
exports.ox_target:addGlobalPlayer({{
    name=targetName,label='個人医の請求',icon='fa-solid fa-file-invoice-dollar',distance=C.Distance,
    canInteract=function(entity)
        return not opened and not opening and allowed(false)and entity~=PlayerPedId()
            and not PrivateMedic.down(LocalPlayer.state,nil,GetEntityHealth(PlayerPedId()))
    end,
    onSelect=function(data)
        if opening or opened then return end
        local player=NetworkGetPlayerIndexFromPed(data.entity)
        if player==-1 then return end
        opening=true
        local version=epoch
        local result=request('open',GetPlayerServerId(player))
        opening=false
        if epoch~=version then return end
        if not result or result.error then lib.notify({title='個人医の請求',description=result and result.error or '開けません',type='error'});return end
        show(result)
    end,
}})
RegisterCommand(C.HistoryCommand,function()
    if not allowed(true)then lib.notify({title='ボーナス履歴',description='個人医の代表のみ確認できます',type='error'});return end
    if opening then return end
    show({manager=true,historyOnly=true})
end,false)
RegisterNUICallback('privateBillClose',function(_,cb)close();cb({ok=true})end)
RegisterNUICallback('privateBillSend',function(data,cb)
    if not opened or not session or type(data)~='table'then cb({error='画面を開き直してください'});return end
    cb(request('send',session,data.amount,data.note))
end)
RegisterNUICallback('privateBillHistory',function(data,cb)
    if not opened or not allowed(true)then cb({error='閲覧権限がありません'});return end
    cb(request('history',type(data)=='table'and data.page or 1))
end)
RegisterNetEvent('ptech_mediora_medical:privateBill:close',close)
AddEventHandler('QBCore:Client:OnPlayerUnload',function()opening=false;close()end)
RegisterNetEvent('QBCore:Client:OnJobUpdate',function()
    if opened and not allowed(false)then close()end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName()then return end
    if opened then close()end
    exports.ox_target:removeGlobalPlayer(targetName)
end)
