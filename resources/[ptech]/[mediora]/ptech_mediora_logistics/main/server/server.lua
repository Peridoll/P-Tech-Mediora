local pointById, hospitalById, itemById = {}, {}, Config.Items
local weightedContents, totalWeight = {}, 0

for _, point in ipairs(Config.CollectionPoints) do pointById[point.id] = point end
for _, hospital in ipairs(Config.Hospitals) do hospitalById[hospital.id] = hospital end
for _, entry in ipairs(Config.BoxContents) do
    totalWeight = totalWeight + entry.weight
    weightedContents[#weightedContents + 1] = { item = entry.item, ceiling = totalWeight }
end

local function notify(source, message)
    TriggerClientEvent('ptech_mediora_logistics:client:notify', source, message)
end

local function getPlayer(source)
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    return ok and player or nil
end

local function isAllowed(source)
    local player = getPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if not job then return false end
    if Config.AllowedJobs and next(Config.AllowedJobs) ~= nil and Config.AllowedJobs[job.name] ~= true then
        return false
    end
    return not Config.RequireOnDuty or job.onduty == true
end

local function isNear(source, point)
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - point.coords) <= Config.Procurement.interactDistance + 1.0
end

local function isNearAnyHospital(source)
    for _, hospital in ipairs(Config.Hospitals) do
        if isNear(source, hospital) then return true end
    end
    return false
end

local function playerKey(source)
    return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0) or tostring(source)
end

local function ownerId(source)
    return tostring(GetHashKey(playerKey(source)))
end

local function getTodayDate()
    local timestamp = os.time() + Config.SpecialCarton.timezoneOffsetHours * 3600
    return os.date('!%Y-%m-%d', timestamp)
end

local function getDailyRecipe()
    local recipes = Config.SpecialCarton.recipes
    if #recipes == 0 then return nil end
    local dayKey = tonumber(os.date('!%j', os.time() + Config.SpecialCarton.timezoneOffsetHours * 3600)) or 1
    local index = ((dayKey - 1) % #recipes) + 1
    return recipes[index], getTodayDate()
end

local function contentsStackKey(contents)
    table.sort(contents, function(a, b) return a.item < b.item end)
    local parts = {}
    for _, entry in ipairs(contents) do
        parts[#parts + 1] = ('%s=%s'):format(entry.item, entry.count)
    end
    return table.concat(parts, ';')
end

local function normalStackKey(contents)
    return ('regular:%s'):format(contentsStackKey(contents))
end

local function specialStackKey(date, recipeId, contents)
    return ('special:%s:%s:%s'):format(date, recipeId, contentsStackKey(contents))
end

local function queueKey(source, destinationId, stackKey)
    return ('boxes:%s:%s:%s'):format(playerKey(source), destinationId, stackKey)
end

local function getQueue(source, destinationId, stackKey)
    local raw = GetResourceKvpString(queueKey(source, destinationId, stackKey))
    if not raw then return {} end
    local ok, queue = pcall(json.decode, raw)
    if ok and type(queue) == 'table' then return queue end
    return {}
end

local function setQueue(source, destinationId, stackKey, queue)
    SetResourceKvp(queueKey(source, destinationId, stackKey), json.encode(queue))
end

local function nextSerial()
    local serial = GetResourceKvpInt('serial') + 1
    SetResourceKvpInt('serial', serial)
    return serial
end

local function rollContents()
    local totalCount = math.random(Config.Procurement.minItems, Config.Procurement.maxItems)
    local counts = {}
    for _ = 1, totalCount do
        local roll = math.random(totalWeight)
        for _, entry in ipairs(weightedContents) do
            if roll <= entry.ceiling then
                counts[entry.item] = (counts[entry.item] or 0) + 1
                break
            end
        end
    end

    local contents = {}
    for item, count in pairs(counts) do
        contents[#contents + 1] = { item = item, count = count }
    end
    return contents
end

local function contentsSellValue(contents)
    local value = 0
    for _, entry in ipairs(contents) do
        local item = itemById[entry.item]
        if item and item.sellPrice then
            value = value + item.sellPrice * entry.count
        end
    end
    return value
end

local function boxMetadata(hospital, source, stackKey, kind, extra)
    local metadata = {
        destinationId = hospital.id,
        destinationLabel = hospital.label,
        ownerId = ownerId(source),
        stackKey = stackKey,
        boxKind = kind,
        label = kind == 'special' and '特注医療物資段ボール' or '医療物資段ボール',
        description = ('納品先: %s'):format(hospital.label),
    }
    for key, value in pairs(extra or {}) do metadata[key] = value end
    return metadata
end

local function addBox(source, hospital, contents, kind, date, recipe)
    local stackKey = kind == 'special'
        and specialStackKey(date, recipe.id, contents)
        or normalStackKey(contents)
    local extra = kind == 'special' and {
        specialDate = date,
        recipeId = recipe.id,
        bonusHospital = recipe.targetHospital,
        description = ('%s / 納品先: %s / 有効日: %s'):format(recipe.label, hospital.label, date),
    } or nil
    local itemName = kind == 'special' and Config.Procurement.specialBoxItem or Config.Procurement.boxItem
    local metadata = boxMetadata(hospital, source, stackKey, kind, extra)
    if not exports.ox_inventory:CanCarryItem(source, itemName, 1, metadata) then return false end

    local queue = getQueue(source, hospital.id, stackKey)
    local parcel = { serial = nextSerial(), contents = contents, kind = kind, date = date }
    queue[#queue + 1] = parcel
    setQueue(source, hospital.id, stackKey, queue)

    local success = exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    if not success then
        table.remove(queue, #queue)
        setQueue(source, hospital.id, stackKey, queue)
        return false
    end
    return true, parcel.serial, stackKey
end

local function getBoxGroups(source, hospital)
    local groups = {}
    local slots = exports.ox_inventory:GetInventoryItems(source) or {}
    for _, slot in pairs(slots) do
        local metadata = slot.metadata or {}
        local isBox = slot.name == Config.Procurement.boxItem or slot.name == Config.Procurement.specialBoxItem
        if isBox and metadata.destinationId == hospital.id and metadata.ownerId == ownerId(source) then
            local key = metadata.stackKey
            if key then
                local group = groups[key]
                if not group then
                    group = {
                        stackKey = key,
                        itemName = slot.name,
                        kind = metadata.boxKind or 'regular',
                        metadata = metadata,
                        inventoryCount = 0,
                        queue = getQueue(source, hospital.id, key),
                    }
                    groups[key] = group
                end
                group.inventoryCount = group.inventoryCount + slot.count
            end
        end
    end

    local result, total = {}, 0
    for key, group in pairs(groups) do
        group.available = math.min(group.inventoryCount, #group.queue)
        if group.available > 0 then
            result[#result + 1] = group
            total = total + group.available
        end
    end
    table.sort(result, function(a, b) return a.stackKey < b.stackKey end)
    return result, total
end

local function getSellValueForParcel(parcel, hospital)
    local multiplier = Config.Economy.unopenedBoxSellMultiplier
    local premium = parcel.kind == 'special'
        and parcel.date == getTodayDate()
        and hospital.id == parcel.bonusHospital
    if premium then multiplier = multiplier * Config.Economy.specialBoxSellMultiplier end
    local expiredSpecial = parcel.kind == 'special' and not premium
    return math.floor(contentsSellValue(parcel.contents) * multiplier), premium, expiredSpecial
end

RegisterNetEvent('ptech_mediora_logistics:server:collect', function(pointId)
    local source = source
    local point = pointById[pointId]
    if not point or not isAllowed(source) or not isNear(source, point) then return end

    local cooldownKey = ('cooldown:%s'):format(point.id)
    local now = os.time()
    local expiresAt = GetResourceKvpInt(cooldownKey)
    if expiresAt > now then
        notify(source, Config.Text.cooldown)
        return
    end

    local hospital = Config.Hospitals[math.random(#Config.Hospitals)]
    local success, serial = addBox(source, hospital, rollContents(), 'regular')
    if not success then
        notify(source, Config.Text.inventoryFull)
        return
    end

    SetResourceKvpInt(cooldownKey, now + Config.Procurement.cooldownSeconds)
    notify(source, ('段ボール #%s を調達しました。納品先: %s'):format(serial, hospital.label))
end)

lib.callback.register('ptech_mediora_logistics:server:getDeliverableCount', function(source, hospitalId)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return 0 end
    local _, count = getBoxGroups(source, hospital)
    return math.min(count, Config.Procurement.maxDeliveries)
end)

RegisterNetEvent('ptech_mediora_logistics:server:deliver', function(hospitalId, requestedCount)
    local source = source
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return end

    local groups, availableCount = getBoxGroups(source, hospital)
    if availableCount < 1 then
        notify(source, Config.Text.noDestinationBoxes)
        return
    end
    if type(requestedCount) ~= 'number' or requestedCount % 1 ~= 0
        or requestedCount < 1 or requestedCount > math.min(availableCount, Config.Procurement.maxDeliveries) then
        notify(source, Config.Text.deliveryCountInvalid)
        return
    end

    local operations, remaining, payout, gotPremium, gotExpiredSpecial = {}, requestedCount, 0, false, false
    for _, group in ipairs(groups) do
        if remaining <= 0 then break end
        local amount = math.min(group.available, remaining)
        local queue = group.queue
        for index = 1, amount do
            local value, premium, expiredSpecial = getSellValueForParcel(queue[index], hospital)
            payout = payout + value
            gotPremium = gotPremium or premium
            gotExpiredSpecial = gotExpiredSpecial or expiredSpecial
        end
        operations[#operations + 1] = { group = group, count = amount }
        remaining = remaining - amount
    end
    if remaining ~= 0 then
        notify(source, Config.Text.deliveryCountInvalid)
        return
    end

    local removed = {}
    for _, operation in ipairs(operations) do
        local group = operation.group
        local success = exports.ox_inventory:RemoveItem(
            source, group.itemName, operation.count, group.metadata, nil, false, true
        )
        if not success then
            for _, rollback in ipairs(removed) do
                exports.ox_inventory:AddItem(source, rollback.itemName, rollback.count, rollback.metadata)
            end
            notify(source, Config.Text.deliveryCountInvalid)
            return
        end
        removed[#removed + 1] = {
            itemName = group.itemName,
            count = operation.count,
            metadata = group.metadata,
        }
    end

    if payout > 0 and not exports.qbx_core:AddMoney(source, Config.Economy.moneyType, payout, 'mediora-logistics-delivery') then
        for _, rollback in ipairs(removed) do
            exports.ox_inventory:AddItem(source, rollback.itemName, rollback.count, rollback.metadata)
        end
        notify(source, Config.Text.tradeInvalid)
        return
    end

    for _, operation in ipairs(operations) do
        local group = operation.group
        local queue = getQueue(source, hospital.id, group.stackKey)
        for _ = 1, operation.count do table.remove(queue, 1) end
        setQueue(source, hospital.id, group.stackKey, queue)
    end

    if gotPremium then notify(source, Config.Text.specialPremiumPaid) end
    if gotExpiredSpecial then notify(source, Config.Text.specialExpired) end
    notify(source, ('%s 向けの段ボールを %s 個納品し、$%s を受け取りました。')
        :format(hospital.label, requestedCount, payout))
end)

lib.callback.register('ptech_mediora_logistics:server:getTradeCatalog', function(source, hospitalId, mode)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return {} end
    if mode ~= 'buy' and mode ~= 'sell' then return {} end

    local catalog = {}
    for itemId, item in pairs(Config.Items) do
        local price = mode == 'buy' and item.buyPrice or item.sellPrice
        if price and price > 0 then
            local count = mode == 'sell'
                and exports.ox_inventory:GetItemCount(source, itemId) or 0
            if mode == 'buy' or count > 0 then
                catalog[#catalog + 1] = {
                    id = itemId,
                    label = item.label,
                    price = price,
                    count = count,
                }
            end
        end
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end)

RegisterNetEvent('ptech_mediora_logistics:server:tradeItem', function(hospitalId, mode, itemId, count)
    local source = source
    local hospital = hospitalById[hospitalId]
    local item = itemById[itemId]
    if not hospital or not item or not isAllowed(source) or not isNear(source, hospital) then return end
    if type(count) ~= 'number' or count % 1 ~= 0 or count < 1
        or count > Config.Economy.maxTransactionItems then
        notify(source, Config.Text.tradeInvalid)
        return
    end

    if mode == 'buy' then
        local unitPrice = item.buyPrice
        local total = unitPrice and unitPrice * count
        if not total or not exports.ox_inventory:CanCarryItem(source, itemId, count) then
            notify(source, Config.Text.inventoryFull)
            return
        end
        if not exports.qbx_core:RemoveMoney(source, Config.Economy.moneyType, total, 'mediora-logistics-purchase') then
            notify(source, Config.Text.insufficientFunds)
            return
        end
        local success = exports.ox_inventory:AddItem(source, itemId, count)
        if not success then
            exports.qbx_core:AddMoney(source, Config.Economy.moneyType, total, 'mediora-logistics-refund')
            notify(source, Config.Text.inventoryFull)
            return
        end
        notify(source, ('%s を %s 個購入しました。$%s'):format(item.label, count, total))
    elseif mode == 'sell' then
        local unitPrice = item.sellPrice
        local total = unitPrice and unitPrice * count
        if not total or count > exports.ox_inventory:GetItemCount(source, itemId) then
            notify(source, Config.Text.tradeInvalid)
            return
        end
        local success = exports.ox_inventory:RemoveItem(source, itemId, count)
        if not success then return end
        if not exports.qbx_core:AddMoney(source, Config.Economy.moneyType, total, 'mediora-logistics-sale') then
            exports.ox_inventory:AddItem(source, itemId, count)
            notify(source, Config.Text.tradeInvalid)
            return
        end
        notify(source, ('%s を %s 個売却しました。$%s'):format(item.label, count, total))
    else
        notify(source, Config.Text.tradeInvalid)
    end
end)

local craftingRecipeById = {}
for _, recipe in ipairs(Config.CraftingRecipes) do craftingRecipeById[recipe.id] = recipe end

local function getMaxCraftCount(source, recipe)
    local maxCount = Config.Economy.maxTransactionItems
    for itemId, required in pairs(recipe.ingredients) do
        local owned = exports.ox_inventory:GetItemCount(source, itemId) or 0
        maxCount = math.min(maxCount, math.floor(owned / required))
    end
    return maxCount
end

lib.callback.register('ptech_mediora_logistics:server:getCraftingCatalog', function(source, hospitalId)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return {} end
    local catalog = {}
    for _, recipe in ipairs(Config.CraftingRecipes) do
        local output = itemById[recipe.output]
        local maxCount = getMaxCraftCount(source, recipe)
        if output and maxCount > 0 then
            catalog[#catalog + 1] = {
                id = recipe.id,
                label = recipe.label,
                output = recipe.output,
                outputLabel = output.label,
                maxCount = maxCount,
                ingredients = recipe.ingredients,
            }
        end
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end)

RegisterNetEvent('ptech_mediora_logistics:server:craftItem', function(hospitalId, recipeId, count)
    local source = source
    local hospital = hospitalById[hospitalId]
    local recipe = craftingRecipeById[recipeId]
    if not hospital or not recipe or not isAllowed(source) or not isNear(source, hospital) then return end
    if type(count) ~= 'number' or count % 1 ~= 0 or count < 1
        or count > getMaxCraftCount(source, recipe) then
        notify(source, Config.Text.missingRecipeItems)
        return
    end

    if not exports.ox_inventory:CanCarryItem(source, recipe.output, count) then
        notify(source, Config.Text.inventoryFull)
        return
    end

    local removed = {}
    for itemId, perCraft in pairs(recipe.ingredients) do
        local amount = perCraft * count
        if not exports.ox_inventory:RemoveItem(source, itemId, amount) then
            for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
            notify(source, Config.Text.missingRecipeItems)
            return
        end
        removed[#removed + 1] = { item = itemId, count = amount }
    end

    if not exports.ox_inventory:AddItem(source, recipe.output, count) then
        for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
        notify(source, Config.Text.inventoryFull)
        return
    end
    notify(source, ('%s を %s 個作成しました。'):format(recipe.label, count))
end)

lib.callback.register('ptech_mediora_logistics:server:getDailySpecial', function(source, hospitalId)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return nil end
    local recipe, date = getDailyRecipe()
    if not recipe then return nil end
    local target = hospitalById[recipe.targetHospital]
    if not target then return nil end
    return {
        id = recipe.id,
        label = recipe.label,
        targetHospital = target.id,
        targetLabel = target.label,
        date = date,
        ingredients = recipe.ingredients,
    }
end)

RegisterNetEvent('ptech_mediora_logistics:server:craftDailySpecial', function(hospitalId)
    local source = source
    local hospital = hospitalById[hospitalId]
    local recipe, date = getDailyRecipe()
    local target = recipe and hospitalById[recipe.targetHospital]
    if not hospital or not target or not isAllowed(source) or not isNear(source, hospital) then return end

    for itemId, required in pairs(recipe.ingredients) do
        if (exports.ox_inventory:GetItemCount(source, itemId) or 0) < required then
            notify(source, Config.Text.missingRecipeItems)
            return
        end
    end

    local contents = {}
    for itemId, required in pairs(recipe.ingredients) do
        contents[#contents + 1] = { item = itemId, count = required }
    end

    local stackKey = specialStackKey(date, recipe.id, contents)
    local metadata = boxMetadata(target, source, stackKey, 'special', {
        specialDate = date,
        recipeId = recipe.id,
        bonusHospital = target.id,
        description = ('%s / 納品先: %s / 有効日: %s'):format(recipe.label, target.label, date),
    })
    if not exports.ox_inventory:CanCarryItem(source, Config.Procurement.specialBoxItem, 1, metadata) then
        notify(source, Config.Text.inventoryFull)
        return
    end

    local removed = {}
    for itemId, required in pairs(recipe.ingredients) do
        if not exports.ox_inventory:RemoveItem(source, itemId, required) then
            for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
            notify(source, Config.Text.missingRecipeItems)
            return
        end
        removed[#removed + 1] = { item = itemId, count = required }
    end

    local queue = getQueue(source, target.id, stackKey)
    local parcel = { serial = nextSerial(), contents = contents, kind = 'special', date = date, bonusHospital = target.id }
    queue[#queue + 1] = parcel
    setQueue(source, target.id, stackKey, queue)
    if not exports.ox_inventory:AddItem(source, Config.Procurement.specialBoxItem, 1, metadata) then
        table.remove(queue, #queue)
        setQueue(source, target.id, stackKey, queue)
        for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
        notify(source, Config.Text.inventoryFull)
        return
    end
    notify(source, ('%s を作成しました。納品先: %s / #%s'):format(recipe.label, target.label, parcel.serial))
end)

exports('openDeliveryBox', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local source = inventory.id
    if not isAllowed(source) then return false end

    local slotData = exports.ox_inventory:GetSlot(source, slot)
    local metadata = slotData and slotData.metadata
    local destinationId = metadata and metadata.destinationId
    local hospital = destinationId and hospitalById[destinationId]
    if not hospital or metadata.ownerId ~= ownerId(source) or not metadata.stackKey then return false end

    local queue = getQueue(source, destinationId, metadata.stackKey)
    local parcel = queue[1]
    if not parcel then return false end
    for _, entry in ipairs(parcel.contents) do
        if not exports.ox_inventory:CanCarryItem(source, entry.item, entry.count) then
            notify(source, Config.Text.inventoryFull)
            return false
        end
    end

    if not exports.ox_inventory:RemoveItem(source, item.name, 1, metadata, slot, false, true) then
        return false
    end
    table.remove(queue, 1)
    setQueue(source, destinationId, metadata.stackKey, queue)
    for _, entry in ipairs(parcel.contents) do
        exports.ox_inventory:AddItem(source, entry.item, entry.count)
    end
    notify(source, Config.Text.boxOpened:format(parcel.serial))
    return true
end)

exports.ox_inventory:registerHook('swapItems', function(payload)
    local sourceName = payload.fromSlot and payload.fromSlot.name
    if sourceName == Config.Procurement.boxItem or sourceName == Config.Procurement.specialBoxItem then
        if payload.action == 'give' or payload.toType == 'drop' then return false end
    end
end, { itemFilter = {
    [Config.Procurement.boxItem] = true,
    [Config.Procurement.specialBoxItem] = true,
} })

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
end)
