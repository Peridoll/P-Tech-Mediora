local Config = Config.PrivateMedic
local busy=false
local active
local generation=0
local prefix='ptech_mediora_medical:private:'
local targetName='ptech_mediora_medical:private:revive'
local function notify(text,kind)lib.notify({title='救命処置',description=text,type=kind or 'error'})end
local function targetId(entity)
    if not entity or entity==0 or entity==PlayerPedId() or not IsPedAPlayer(entity) then return end
    local player=NetworkGetPlayerIndexFromPed(entity)
    if player==-1 then return end
    return GetPlayerServerId(player)
end
local function cancel()
    local session=active
    if not session then return end
    session.cancelled=true
    TriggerServerEvent(prefix..'cancel',session.token)
    if session.progress then pcall(function()exports.ptech_mediora_core:hideProgress(session.progress)end)end
    if session.animating then StopAnimTask(PlayerPedId(),'mini@cpr@char_a@cpr_str','cpr_pumpchest',2.0) end
end
local function treat(entity)
    if busy then return end
    local target=targetId(entity)
    if not target then return end
    local requestGeneration=generation
    local doctor=exports.qbx_core:GetPlayerData()
    local doctorId=doctor and doctor.citizenid
    busy=true
    local session
    local ok,error=pcall(function()
        local start=lib.callback.await(prefix..'begin',false,target)
        if requestGeneration~=generation then
            if start and start.token then TriggerServerEvent(prefix..'cancel',start.token)end
            return
        end
        if not start or not start.ok then notify(start and start.error or '処置を開始できません');return end
        session={token=start.token}
        active=session
        local shown,id=exports.ptech_mediora_core:showProgress({duration=start.duration,label='救命処置中',
            style='segmented',template='main/ui/progress/revive.svg'})
        if not shown then cancel();notify('Coreの進行表示を開始できません');return end
        session.progress=id
        local dict,clip='mini@cpr@char_a@cpr_str','cpr_pumpchest'
        RequestAnimDict(dict)
        local ped,deadline=PlayerPedId(),GetGameTimer()+start.duration
        while GetGameTimer()<deadline do
            DisableAllControlActions(0)
            EnableControlAction(0,1,true);EnableControlAction(0,2,true)
            local current=targetId(entity)
            local data=exports.qbx_core:GetPlayerData()
            if session.cancelled or IsDisabledControlJustPressed(0,73) or PlayerPedId()~=ped
                or not data or data.citizenid~=doctorId or not PrivateMedic.allowed(data)
                or PrivateMedic.down(LocalPlayer.state,data and data.metadata,GetEntityHealth(ped))
                or current~=target or not DoesEntityExist(entity)
                or #(GetEntityCoords(ped)-GetEntityCoords(entity))>Config.ServerDistance then
                cancel();notify('処置を中止しました','inform');return
            end
            if not session.animating and HasAnimDictLoaded(dict) then
                TaskPlayAnim(ped,dict,clip,4.0,-4.0,-1,1,0.0,false,false,false);session.animating=true
            end
            Wait(0)
        end
        if session.animating then StopAnimTask(ped,dict,clip,2.0);session.animating=false end
        exports.ptech_mediora_core:hideProgress(session.progress)
        RemoveAnimDict(dict)
        if session.cancelled then return end
        local result=lib.callback.await(prefix..'finish',false,session.token)
        notify(result and result.ok and '蘇生と全身の治療が完了しました' or result and result.error or '蘇生の完了を確認できません',result and result.ok and 'success' or 'error')
    end)
    if not ok then cancel();notify('処置中にエラーが発生しました');print('[Private Medic] '..tostring(error))end
    active=nil;busy=false
end
exports.ox_target:addGlobalPlayer({{
    name=targetName,icon='fa-solid fa-briefcase-medical',label=Config.TargetLabel,distance=Config.TargetDistance,
    canInteract=function(entity)
        local data=exports.qbx_core:GetPlayerData()
        local target=targetId(entity)
        return not busy and target and PrivateMedic.allowed(data)
            and not PrivateMedic.down(LocalPlayer.state,data.metadata,GetEntityHealth(PlayerPedId()))
            and PrivateMedic.down(Player(target).state,nil,GetEntityHealth(entity))
            and (MedicalInventoryClient and MedicalInventoryClient.count(Config.Item)or exports.ox_inventory:Search('count',Config.Item)or 0)>=math.max(1,Config.ConsumeCount)
    end,
    onSelect=function(data)treat(data.entity)end,
}})
exports('usePhoenixKit',function()notify('ダウン中の相手をターゲットして「'..Config.TargetLabel..'」を選んでください','inform')end)
AddEventHandler('QBCore:Client:OnPlayerUnload',function()generation=generation+1;cancel()end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    generation=generation+1
    cancel();exports.ox_target:removeGlobalPlayer(targetName)
end)
