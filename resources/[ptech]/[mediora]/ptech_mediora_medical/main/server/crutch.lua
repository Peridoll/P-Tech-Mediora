lib.callback.register('ptech_mediora_medical:crutch:remove', function(src, request)
    local medic = exports.qbx_core:GetPlayer(src)
    if not medic or not PrivateMedic.allowed(medic.PlayerData) then
        return { error = '勤務中のEMS・個人医のみ松葉杖を外せます。' }
    end
    if GetResourceState('wasabi_crutch') ~= 'started' then return { error = '松葉杖の機能が停止中です。' } end
    if type(request) ~= 'table' or not PrivateMedic.validId(request.targetId)
        or not PrivateMedic.validId(request.targetNetId) or request.targetId == src then
        return { error = '対象の患者を選び直してください。' }
    end
    local target = request.targetId
    local patient = exports.qbx_core:GetPlayer(target)
    local actorPed, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if not patient or actorPed == 0 or targetPed == 0
        or NetworkGetNetworkIdFromEntity(targetPed) ~= request.targetNetId
        or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target)
        or #(GetEntityCoords(actorPed) - GetEntityCoords(targetPed)) > Config.PrivateMedic.ServerDistance then
        return { error = '対象の患者に近づいてください。' }
    end
    if PrivateMedic.down(Player(src).state, medic.PlayerData.metadata, GetEntityHealth(actorPed)) then
        return { error = '現在の状態では松葉杖を外せません。' }
    end
    if Player(target).state.medioraCrutch ~= true then return { error = '対象の患者は松葉杖を使用していません。' } end
    if MedicalWoundServer and MedicalWoundServer.clearCrutchAssignment then
        MedicalWoundServer.clearCrutchAssignment(target)
    end
    TriggerClientEvent('ptech_mediora_medical:crutch:remove', target)
    return { ok = true }
end)
