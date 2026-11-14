local model = joaat('pems_shinobi')

RegisterCommand('pemsuv', function(_, args)
    local modes = { coarse = 1, fine = 2, off = 0 }
    local index = modes[args[1]]
    local function report(message)
        print('[PEMS UV] ' .. message)
        TriggerEvent('chat:addMessage', { args = { 'PEMS UV', message } })
    end
    if index == nil then
        report('/pemsuv coarse（8マス） /pemsuv fine（16マス） /pemsuv off（EMS塗装）')
        return
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetEntityModel(vehicle) ~= model
        or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or not NetworkHasControlOfEntity(vehicle) then
        report('pems_shinobi の運転席で実行してください。')
        return
    end
    SetVehicleModKit(vehicle, 0)
    if GetNumVehicleMods(vehicle, 48) <= index then
        report('チェック柄が未読込です。更新ファイルと車両の再生成を確認してください。')
        return
    end
    SetVehicleMod(vehicle, 48, index, false)
    report(index == 0 and 'EMS塗装に戻しました。' or '座標チェック柄に切り替えました。左右側面・正面・後面・タンク上面を撮影してください。')
end, false)

-- Manual application also reports whether the vehicle mod kit reached the client.
RegisterCommand('pemslivery', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local function report(message)
        print('[PEMS Shinobi] ' .. message)
        TriggerEvent('chat:addMessage', { args = { 'PEMS Shinobi', message } })
    end
    if vehicle == 0 or GetEntityModel(vehicle) ~= model then
        report('pems_shinobi に乗って実行してください。')
        return
    end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped or not NetworkHasControlOfEntity(vehicle) then
        report('運転席で車両を操作できる状態で実行してください。')
        return
    end
    SetVehicleModKit(vehicle, 0)
    local bodyCount = GetNumVehicleMods(vehicle, 48)
    local boxCount = GetNumVehicleMods(vehicle, 5)
    if bodyCount > 0 then SetVehicleMod(vehicle, 48, 0, false) end
    if boxCount > 0 then SetVehicleMod(vehicle, 5, 0, false) end
    report(('resource=%s / body=%d selected=%d / box=%d selected=%d / label=%s'):format(
        GetCurrentResourceName(), bodyCount, GetVehicleMod(vehicle, 48),
        boxCount, GetVehicleMod(vehicle, 5), GetLabelText('PEMS_SHIN_LIVEMS')))
    if bodyCount == 0 then
        report('車体の塗装パーツが認識されていません。')
    else
        report('EMS塗装を選択しました。見た目が変わるか確認してください。')
    end
end, false)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetEntityModel(vehicle) == model
            and GetPedInVehicleSeat(vehicle, -1) == ped and NetworkHasControlOfEntity(vehicle) then
            SetVehicleModKit(vehicle, 0)
            if GetNumVehicleMods(vehicle, 48) > 0 and GetVehicleMod(vehicle, 48) == -1 then
                SetVehicleMod(vehicle, 48, 0, false)
            end
            if GetNumVehicleMods(vehicle, 5) > 0 and GetVehicleMod(vehicle, 5) == -1 then
                SetVehicleMod(vehicle, 5, 0, false)
            end
        end
        Wait(1000)
    end
end)
