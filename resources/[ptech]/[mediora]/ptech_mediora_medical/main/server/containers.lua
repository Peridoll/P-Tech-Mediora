-- ox_inventory owns per-bag IDs, persistence, weight, transfers and nesting checks.
local registration = 0
local function registerBag()
    local settings = Config.MedicalBag
    local whitelist = {}
    for name in pairs(Config.Wounds.Items) do whitelist[name] = true end
    for _, name in ipairs(settings.ExtraItems or {}) do whitelist[name] = true end
    whitelist.pmediora_medicalbag = nil
    exports.ox_inventory:setContainerProperties('pmediora_medicalbag', {
        slots = settings.Slots, maxWeight = settings.MaxWeight, whitelist = whitelist,
    })
end

local function scheduleRegistration()
    registration = registration + 1
    local request = registration
    CreateThread(function()
        local lastError
        for attempt = 1, 10 do
            if request ~= registration or GetResourceState('ox_inventory') ~= 'started' then return end
            local ok, error = pcall(registerBag)
            if ok then return end
            lastError = error
            Wait(250)
        end
        print('[ptech_mediora_medical] 医療バッグを登録できませんでした: '..tostring(lastError))
    end)
end

-- Initial start and inventory-only restarts both need registration.
CreateThread(scheduleRegistration)
AddEventHandler('onResourceStart', function(name)
    if name == 'ox_inventory' then scheduleRegistration() end
end)
