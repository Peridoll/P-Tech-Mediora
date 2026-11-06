local equipped = false
local boosted = false

local function applySwimSpeed()
    local ped = PlayerPedId()
    local underwater = equipped and not IsPedInAnyVehicle(ped, false)
        and IsPedSwimmingUnderWater(ped)

    if underwater then
        local multiplier = tonumber(Config.Fins.SwimMultiplier) or 1.0
        SetSwimMultiplierForPlayer(PlayerId(), math.max(1.0, math.min(1.49, multiplier)))
        boosted = true
    elseif boosted then
        SetSwimMultiplierForPlayer(PlayerId(), 1.0)
        boosted = false
    end
end

exports('toggleFins', function(data, slot)
    exports.ox_inventory:useItem(data, function(used)
        if not used then return end

        local ok, enabled = pcall(lib.callback.await, 'ptech_mediora_marine:toggleFins', false)
        if not ok or type(enabled) ~= 'boolean' then
            lib.notify({ description = 'フィンを装備できません。EMSの勤務状態と所持品を確認してください。', type = 'error' })
            return
        end

        equipped = enabled
        applySwimSpeed()
        lib.notify({ description = equipped and 'フィンを装備しました' or 'フィンを解除しました', type = 'inform' })
    end)
end)

RegisterNetEvent('ptech_mediora_marine:finsState', function(enabled)
    if source ~= 65535 then return end
    equipped = enabled == true
    applySwimSpeed()
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if itemName == Config.Fins.Item and (type(totalCount) ~= 'number' or totalCount <= 0) then
        equipped = false
        applySwimSpeed()
    end
end)

CreateThread(function()
    while true do
        applySwimSpeed()
        Wait(equipped and 0 or 500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and boosted then
        SetSwimMultiplierForPlayer(PlayerId(), 1.0)
    end
end)
