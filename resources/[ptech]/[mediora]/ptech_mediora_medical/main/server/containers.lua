-- ox_inventory owns per-bag IDs, persistence, weight, transfers and nesting checks.
local registration = 0
local appearanceHook
local capacityHook
local images = {}
local function localImage(variant)
    return ('nui://ptech_mediora_medical/install/ox_inventory/images/pmediora_bag%d.png'):format(variant)
end

local function bagAppearance(payload)
    local metadata = payload.metadata or {}
    local variant = metadata.medicalBagVariant
    if type(variant) ~= 'number' or variant % 1 ~= 0 or variant < 1 or variant > 4 then
        variant = math.random(1, 4)
        metadata.medicalBagVariant = variant
    end
    -- Keep the chosen appearance and container ID through transfers and DB reloads.
    metadata.imageurl = images[variant]
    return metadata
end

-- Upgrade existing bags lazily on open; retain ID, appearance, contents and slot count.
local function upgradeCapacity(payload)
    local slot=exports.ox_inventory:GetSlot(payload.source,payload.slot)
    if not slot or slot.name~='pmediora_medicalbag' then return end
    local metadata=slot.metadata
    if type(metadata)~='table' or not metadata.container
        or tostring(metadata.container)~=tostring(payload.inventoryId) then return end
    local settings=Config.MedicalBag
    local size=type(metadata.size)=='table' and metadata.size or {}
    if size[2]~=settings.MaxWeight then
        local updated={}
        for key,value in pairs(metadata)do updated[key]=value end
        updated.size={size[1] or settings.Slots,settings.MaxWeight}
        exports.ox_inventory:SetMetadata(payload.source,payload.slot,updated)
    end
    exports.ox_inventory:SetMaxWeight(payload.inventoryId,settings.MaxWeight)
end

local function loadRemoteImages()
    local base = Config.MedicalBag.ImageBase
    if type(base) ~= 'string' or base == '' then return end
    -- With inventory webhook logging enabled, image URLs need an allowed host.
    if GetConvar('inventory:webhook', '') ~= '' then
        local ok, hosts = pcall(json.decode, GetConvar('inventory:validhosts', '{}'))
        local host = base:match('^https?://([^/]+)')
        if not ok or type(hosts) ~= 'table' or hosts[host] ~= true then return end
    end
    local request = registration
    for variant = 1, 4 do
        local selected = variant
        local url = base .. ('pmediora_bag%d.png'):format(selected)
        PerformHttpRequest(url, function(status, body, headers)
            if request ~= registration or status ~= 200 then return end
            local contentType = headers and (headers['content-type'] or headers['Content-Type']) or ''
            if contentType:lower():find('image/png', 1, true) then images[selected] = url end
        end, 'HEAD')
    end
end
local function registerBag()
    local settings = Config.MedicalBag
    local whitelist = {}
    for name in pairs(Config.Wounds.Items) do whitelist[name] = true end
    for _, name in ipairs(settings.ExtraItems or {}) do whitelist[name] = true end
    whitelist.pmediora_medicalbag = nil
    exports.ox_inventory:setContainerProperties('pmediora_medicalbag', {
        slots = settings.Slots, maxWeight = settings.MaxWeight, whitelist = whitelist,
    })
    if appearanceHook then exports.ox_inventory:removeHooks(appearanceHook) end
    appearanceHook = exports.ox_inventory:registerHook('createItem', bagAppearance, {
        itemFilter = { pmediora_medicalbag = true },
    })
    if capacityHook then exports.ox_inventory:removeHooks(capacityHook) end
    capacityHook=exports.ox_inventory:registerHook('openInventory',upgradeCapacity,{
        typeFilter={container=true},
    })
end

local function scheduleRegistration()
    registration = registration + 1
    for variant = 1, 4 do images[variant] = localImage(variant) end
    local request = registration
    CreateThread(function()
        local lastError
        for attempt = 1, 10 do
            if request ~= registration or GetResourceState('ox_inventory') ~= 'started' then return end
            local ok, error = pcall(registerBag)
            if ok then loadRemoteImages(); return end
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
