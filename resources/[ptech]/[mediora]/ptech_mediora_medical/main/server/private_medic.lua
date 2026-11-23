local Config = Config.PrivateMedic
local tasks, patients = {}, {}
local sequence = 0
local prefix = 'ptech_mediora_medical:private:'
local function release(src, expected)
    local task=tasks[src]
    if not task or (expected and task~=expected) then return end
    if patients[task.patientId]==task then patients[task.patientId]=nil end
    tasks[src]=nil
end
local function validate(src,target,task,skipStock)
    if not PrivateMedic.validId(target) or target==src then return nil,'対象を確認してください' end
    local doctor=exports.qbx_core:GetPlayer(src)
    local patient=exports.qbx_core:GetPlayer(target)
    local a,b=GetPlayerPed(src),GetPlayerPed(target)
    if not doctor or not patient or a==0 or b==0 then return nil,'対象または処置者が退出しました' end
    local d,p=doctor.PlayerData,patient.PlayerData
    if not PrivateMedic.allowed(d) then return nil,'勤務中のEMS・個人医のみ処置できます' end
    if PrivateMedic.down(Player(src).state,d.metadata,GetEntityHealth(a)) then return nil,'行動不能中は処置できません' end
    if not PrivateMedic.down(Player(target).state,p.metadata,GetEntityHealth(b)) then return nil,'蘇生が必要な相手に使用してください' end
    if task and (task.doctorId~=d.citizenid or task.patientId~=p.citizenid) then return nil,'対象またはキャラクターが変わりました' end
    if GetPlayerRoutingBucket(src)~=GetPlayerRoutingBucket(target)
        or #(GetEntityCoords(a)-GetEntityCoords(b))>Config.ServerDistance then return nil,'対象に近づいてください' end
    if GetResourceState('ptech_mediora_core')~='started' or GetResourceState('wasabi_ambulance')~='started' then
        return nil,'医療機能が停止中です'
    end
    if not skipStock and (MedicalInventory and MedicalInventory.count(src,Config.Item)or exports.ox_inventory:Search(src,'count',Config.Item)or 0)<math.max(1,Config.ConsumeCount) then return nil,'フェニックスキットが必要です' end
    return {doctorId=d.citizenid,patientId=p.citizenid}
end

lib.callback.register(prefix..'begin',function(src,target)
    if tasks[src] then return {error='すでに処置中です'} end
    local valid,error=validate(src,target)
    if not valid then return {error=error} end
    if patients[valid.patientId] then return {error='ほかの個人医が処置中です'} end
    sequence=sequence+1
    local task={target=target,patientId=valid.patientId,doctorId=valid.doctorId,
        token=('%d:%d:%d'):format(src,sequence,math.random(100000,999999)),started=GetGameTimer()}
    tasks[src],patients[task.patientId]=task,task
    SetTimeout(Config.Duration+15000,function() if not task.finishing then release(src,task) end end)
    return {ok=true,token=task.token,duration=Config.Duration,patientId=task.patientId}
end)

RegisterNetEvent(prefix..'cancel',function(token)
    local task=tasks[source]
    if task and task.token==token and not task.finishing then release(source,task) end
end)

lib.callback.register(prefix..'finish',function(src,token)
    local task=tasks[src]
    if not task or task.token~=token or task.finishing then return {error='処置情報が無効です'} end
    if GetGameTimer()-task.started<Config.Duration then return {error='処置が完了していません'} end
    if GetGameTimer()-task.started>Config.Duration+15000 then release(src,task);return {error='処置の有効期限が切れました'} end
    local valid,error=validate(src,task.target,task)
    if not valid then release(src,task);return {error=error} end
    task.finishing=true
    local consumed=false
    local receipt
    local ok,result=pcall(function()
        if Config.ConsumeCount>0 then
            if MedicalInventory then
                local removed,from=MedicalInventory.remove(src,Config.Item,Config.ConsumeCount)
                if not removed then return {error='キットを消費できませんでした'} end
                receipt=from
            elseif not exports.ox_inventory:RemoveItem(src,Config.Item,Config.ConsumeCount) then return {error='キットを消費できませんでした'} end
            consumed=true
        end
        local stillValid,reason=validate(src,task.target,task,consumed)
        if not stillValid then return {error=reason} end
        return MedicalWoundServer.restorePrivatePatient(task.target,task.patientId)
    end)
    if not ok or type(result)~='table' then result={error='蘇生処理との連携に失敗しました'} end
    if not result.ok and consumed and not result.changed then
        local doctor=exports.qbx_core:GetPlayer(src)
        if doctor and doctor.PlayerData.citizenid==task.doctorId then
            local returned,refunded=pcall(function()
                if receipt then return MedicalInventory.refund(receipt)end
                return exports.ox_inventory:AddItem(src,Config.Item,Config.ConsumeCount)
            end)
            if not returned or not refunded then print(('[Private Medic] kit refund failed source=%d citizenid=%s'):format(src,task.doctorId)) end
        end
    end
    release(src,task)
    return result
end)

AddEventHandler('playerDropped',function()
    local src=source
    release(src)
    for doctor,task in pairs(tasks) do if task.target==src and not task.finishing then release(doctor,task) end end
end)
AddEventHandler('onResourceStop',function(name)
    if name=='ptech_mediora_medical' or name=='wasabi_ambulance' then
        for src,task in pairs(tasks) do if not task.finishing then release(src,task) end end
    end
end)
