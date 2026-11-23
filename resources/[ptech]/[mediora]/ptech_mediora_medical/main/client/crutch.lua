local targetName = 'ptech_mediora_medical:crutch:remove'
local stateKey = 'medioraCrutch'
local busy = false
local function setActive(active)
    if LocalPlayer.state[stateKey] ~= active then LocalPlayer.state:set(stateKey, active, true) end
end
local function targetId(entity)
    if not entity or entity == 0 or entity == PlayerPedId() or not IsPedAPlayer(entity) then return end
    local player = NetworkGetPlayerIndexFromPed(entity)
    if player == -1 then return end
    return GetPlayerServerId(player)
end
local function allowed()
    local data = exports.qbx_core:GetPlayerData()
    return PrivateMedic.allowed(data)
        and not PrivateMedic.down(LocalPlayer.state, data.metadata, GetEntityHealth(PlayerPedId()))
end

CreateThread(function()
    while true do
        local active = false
        if GetResourceState('wasabi_crutch') == 'started' then
            local data = exports.qbx_core:GetPlayerData()
            if data and data.citizenid then
                local ok, using = pcall(function() return exports.wasabi_crutch:IsCrutchActive() end)
                active = ok and using == true
            end
        end
        setActive(active)
        Wait(500)
    end
end)

exports.ox_target:addGlobalPlayer({{
    name = targetName, icon = 'fa-solid fa-crutch', label = '松葉杖を外す',
    distance = Config.PrivateMedic.TargetDistance,
    canInteract = function(entity)
        local target = targetId(entity)
        return not busy and GetResourceState('wasabi_crutch') == 'started' and target and allowed()
            and Player(target).state[stateKey] == true
    end,
    onSelect = function(data)
        local target = targetId(data.entity)
        if busy or not target or not allowed() then return end
        busy = true
        local ok, result = pcall(lib.callback.await, 'ptech_mediora_medical:crutch:remove', false, {
            targetId = target, targetNetId = NetworkGetNetworkIdFromEntity(data.entity),
        })
        busy = false
        local success = ok and type(result) == 'table' and result.ok
        lib.notify({title = '松葉杖', type = success and 'success' or 'error',
            description = success and '松葉杖の解除を依頼しました。'
                or (ok and type(result) == 'table' and result.error) or '解除できませんでした。もう一度お試しください。'})
    end,
}})

RegisterNetEvent('ptech_mediora_medical:crutch:remove', function()
    if source ~= 65535 or GetResourceState('wasabi_crutch') ~= 'started' then return end
    local ok, result = pcall(function() return exports.wasabi_crutch:RemoveCrutch(GetPlayerServerId(PlayerId())) end)
    if ok and result ~= false then setActive(false)
    else lib.notify({title = '松葉杖', description = '解除できませんでした。EMS・個人医に再操作を依頼してください。', type = 'error'}) end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function() setActive(false) end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        setActive(false)
        exports.ox_target:removeGlobalPlayer(targetName)
    elseif resource == 'wasabi_crutch' then setActive(false) end
end)
