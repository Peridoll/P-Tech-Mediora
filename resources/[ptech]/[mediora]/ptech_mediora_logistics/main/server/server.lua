
--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local pointById, hospitalById, itemById = {}, {}, Config.Items
local weightedContents, totalWeight = {}, 0

for _, point in ipairs(Config.CollectPoints) do pointById[point.id] = point end
for _, hospital in ipairs(Config.Hospitals) do hospitalById[hospital.id] = hospital end
for _, entry in ipairs(Config.BoxContents) do
  totalWeight = totalWeight + entry.weight
  weightedContents[#weightedContents + 1] = { item = entry.item, ceiling = totalWeight }
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function notify(source, message)
  TriggerClientEvent('ptech_mediora_logistics:client:notify', source, message)
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getPlayer(source)
  local ok, player = pcall(function()
    return exports.qbx_core:GetPlayer(source)
  end)
  return ok and player or nil
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function isAllowed(source)
  local player = getPlayer(source)
  local job = player and player.PlayerData and player.PlayerData.job
  if not job then return false end
  if Config.AllowedJobs and next(Config.AllowedJobs) ~= nil and Config.AllowedJobs[job.name] ~= true then
    return false
  end
  return not Config.RequireOnDuty or job.onduty == true
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function isNear(source, point)
  local ped = GetPlayerPed(source)
  if ped == 0 then return false end
  return #(GetEntityCoords(ped) - point.coords) <= Config.Procurement.interactDistance + 1.0
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- local function isNearAnyHospital(source)
--   for _, hospital in ipairs(Config.Hospitals) do
--     if isNear(source, hospital) then return true end
--   end
--   return false
-- end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function playerKey(source)
  return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0) or tostring(source)
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function ownerId(source)
  return tostring(GetHashKey(playerKey(source)))
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getTodayDate()
  local timestamp = os.time() + Config.SpecialCarton.timezoneOffsetHours * 3600
  return os.date('!%Y-%m-%d', timestamp)
end

-- 病院IDと日本時間の日付から、その日の倍率を決定する。
-- 同じ病院・同じ日付なら、再起動後も全プレイヤーで同じ倍率になる。
local function getHospitalMultiplier(hospitalId)
  local settings = Config.Economy.dailyHospitalMultiplier
  local min100 = math.floor(settings.min * 100 + 0.5)
  local max100 = math.floor(settings.max * 100 + 0.5)
  local step100 = math.max(1, math.floor(settings.step * 100 + 0.5))
  local variations = math.max(1, math.floor((max100 - min100) / step100) + 1)
  local key = ('%s:%s'):format(getTodayDate(), hospitalId)
  local hash = 0
  for i = 1, #key do
    hash = (hash * 131 + key:byte(i)) % 2147483647
  end
  -- 日付や病院IDが1文字違うだけでも倍率が偏りにくいよう混ぜる。
  hash = (hash * 48271 + 1) % 2147483647
  return (min100 + (hash % variations) * step100) / 100
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getDailyRecipe()
  local recipes = Config.SpecialCarton.recipes
  if #recipes == 0 then return nil end
  local dayKey = tonumber(os.date('!%j', os.time() + Config.SpecialCarton.timezoneOffsetHours * 3600)) or 1
  local index = ((dayKey - 1) % #recipes) + 1
  return recipes[index], getTodayDate()
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function contentsStackKey(contents)
  table.sort(contents, function(a, b) return a.item < b.item end)
  local parts = {}
  for _, entry in ipairs(contents) do
    parts[#parts + 1] = ('%s=%s'):format(entry.item, entry.count)
  end
  return table.concat(parts, ';')
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function normalStackKey(contents)
    return ('regular:%s'):format(contentsStackKey(contents))
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function specialStackKey(date, recipeId, contents)
  return ('special:%s:%s:%s'):format(date, recipeId, contentsStackKey(contents))
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function queueKey(source, destinationId, stackKey)
  return ('boxes:%s:%s:%s'):format(playerKey(source), destinationId, stackKey)
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getQueue(source, destinationId, stackKey)
  local raw = GetResourceKvpString(queueKey(source, destinationId, stackKey))
  if not raw then return {} end
  local ok, queue = pcall(json.decode, raw)
  if ok and type(queue) == 'table' then return queue end
  return {}
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function setQueue(source, destinationId, stackKey, queue)
  SetResourceKvp(queueKey(source, destinationId, stackKey), json.encode(queue))
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function nextSerial()
  local serial = GetResourceKvpInt('serial') + 1
  SetResourceKvpInt('serial', serial)
  return serial
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
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



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
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



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
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



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
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



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
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



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getSellValueForParcel(parcel, hospital)
  local multiplier = Config.Economy.unopenedBoxSellMultiplier
  local premium = parcel.kind == 'special' and parcel.date == getTodayDate() and hospital.id == parcel.bonusHospital
  if premium then multiplier = multiplier * Config.Economy.specialBoxSellMultiplier end
  local expiredSpecial = parcel.kind == 'special' and not premium
  -- 当日病院倍率は通常箱・特注箱の両方にかかる。特注ボーナスだけが当日限定。
  local hospitalRate = getHospitalMultiplier(hospital.id)
  return math.floor(contentsSellValue(parcel.contents) * multiplier * hospitalRate), premium, expiredSpecial
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent('ptech_mediora_logistics:server:collect',
  function(pointId)
    local source = source
    local point = pointById[pointId]
    if not point or not isAllowed(source) or not isNear(source, point) then return end

    -- クールタイムはプレイヤー単位かつ収集地点単位で永続保存する。
    local cooldownKey = ('cooldown:%s:%s'):format(playerKey(source), point.id)
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
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- 現地にいるEMSだけが、病院メニュー表示用の当日倍率を取得できる。
lib.callback.register('ptech_mediora_logistics:server:getHospitalMultiplier',
  function(source, hospitalId)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return nil end
    return getHospitalMultiplier(hospital.id)
  end
)


lib.callback.register('ptech_mediora_logistics:server:getDeliverableCount',
  function(source, hospitalId)
    local hospital = hospitalById[hospitalId]
    if not hospital or not isAllowed(source) or not isNear(source, hospital) then return 0 end
    local _, count = getBoxGroups(source, hospital)
    return math.min(count, Config.Procurement.maxDeliveries)
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent('ptech_mediora_logistics:server:deliver',
  function(hospitalId, requestedCount)
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
    notify(source, ('%s 向けの段ボールを %s 個納品し、$%s を受け取りました。'):format(hospital.label, requestedCount, payout))

  end -- RegisterNetEvent('ptech_mediora_logistics:server:deliver')
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
lib.callback.register('ptech_mediora_logistics:server:getTradeCatalog',
  function(source, hospitalId, mode)
    local hospital = hospitalById[hospitalId]
    if not hospital or hospital.id ~= Config.Economy.tradeHospitalId or not isAllowed(source) or not isNear(source, hospital) then return {} end
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
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent('ptech_mediora_logistics:server:tradeItem',
  function(hospitalId, mode, itemId, count)
    local source = source
    local hospital = hospitalById[hospitalId]
    local item = itemById[itemId]
    if not hospital or hospital.id ~= Config.Economy.tradeHospitalId or not item or not isAllowed(source) or not isNear(source, hospital) then return end
    if type(count) ~= 'number' or count % 1 ~= 0 or count < 1 or count > Config.Economy.maxTransactionItems then
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
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local craftingRecipeById = {}
for _, recipe in ipairs(Config.CraftingRecipes) do craftingRecipeById[recipe.id] = recipe end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function getMaxCraftCount(source, recipe)
  local maxCount = Config.Economy.maxTransactionItems
  for itemId, required in pairs(recipe.ingredients) do
    local owned = exports.ox_inventory:GetItemCount(source, itemId) or 0
    maxCount = math.min(maxCount, math.floor(owned / required))
  end
  return maxCount
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
lib.callback.register('ptech_mediora_logistics:server:getCraftingCatalog',
  function(source, hospitalId)
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
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent('ptech_mediora_logistics:server:craftItem',
  function(hospitalId, recipeId, count)
    local source = source
    local hospital = hospitalById[hospitalId]
    local recipe = craftingRecipeById[recipeId]
    if not hospital or not recipe or not isAllowed(source) or not isNear(source, hospital) then return end
    if type(count) ~= 'number' or count % 1 ~= 0 or count < 1 or count > getMaxCraftCount(source, recipe) then
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
      if ( not exports.ox_inventory:RemoveItem(source, itemId, amount) ) then
        for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
        notify(source, Config.Text.missingRecipeItems)
        return
      end
      removed[#removed + 1] = { item = itemId, count = amount }
    end

    if ( not exports.ox_inventory:AddItem(source, recipe.output, count) ) then
      for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
      notify(source, Config.Text.inventoryFull)
      return
    end
    notify(source, ('%s を %s 個作成しました。'):format(recipe.label, count))
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
lib.callback.register('ptech_mediora_logistics:server:getDailySpecial',
  function(source, hospitalId)
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
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 特注物資を作成するイベント "craftDailySpecial" を定義 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent('ptech_mediora_logistics:server:craftDailySpecial',
  function(hospitalId)

    local source       = source
    local hospital     = hospitalById[hospitalId]
    local recipe, date = getDailyRecipe()
    local target       = recipe and hospitalById[recipe.targetHospital]

    -- いずれかの条件が満たされない場合は処理を中断
    if (not hospital) or (not target) or (not isAllowed(source)) or (not isNear(source, hospital)) then return end

    -- レシピの材料が揃っているか確認 >> 揃っていない場合は通知して処理を中断
    for itemId, required in pairs(recipe.ingredients) do
      if ( (exports.ox_inventory:GetItemCount(source, itemId) or 0) < required ) then
        notify(source, Config.Text.missingRecipeItems)
        return
      end
    end

    -- 材料を箱の中身としてまとめる
    local contents = {}
    for itemId, required in pairs(recipe.ingredients) do
      contents[#contents + 1] = { item = itemId, count = required }
    end

    -- 箱のスタックキーとメタデータを作成
    local stackKey = specialStackKey(date, recipe.id, contents)
    local metadata = boxMetadata(
      target,
      source,
      stackKey,
      'special',
      {
        specialDate = date,
        recipeId = recipe.id,
        bonusHospital = target.id,
        description = ('%s / 納品先: %s / 有効日: %s'):format(recipe.label, target.label, date),
      }
    )

    -- インベントリに空きがあるか確認 >> 空きがない場合は通知して処理を中断
    if ( not exports.ox_inventory:CanCarryItem(source, Config.Procurement.specialBoxItem, 1, metadata) ) then
      notify(source, Config.Text.inventoryFull)
      return
    end

    -- 材料を削除する前に、削除に失敗した場合に備えて削除済みのアイテムを記録するテーブルを用意
    local removed = {}
    for itemId, required in pairs(recipe.ingredients) do
      if ( not exports.ox_inventory:RemoveItem(source, itemId, required) ) then
        for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end
          notify(source, Config.Text.missingRecipeItems)
        return
      end
      removed[#removed + 1] = { item = itemId, count = required }
    end

    -- 配送キューを取得
    local queue = getQueue(source, target.id, stackKey)

    -- 箱の情報を作成
    local parcel = { serial = nextSerial(), contents = contents, kind = 'special', date = date, bonusHospital = target.id }

    -- 配送キューに箱を追加
    queue[#queue + 1] = parcel

    -- 配送キューを保存
    setQueue(source, target.id, stackKey, queue)

    -- 箱をインベントリに追加
    if ( not exports.ox_inventory:AddItem(source, Config.Procurement.specialBoxItem, 1, metadata) ) then

      -- 箱の追加に失敗した場合は配送キューから削除し、材料を返却して通知
      table.remove(queue, #queue)

      -- 配送キューを更新
      setQueue(source, target.id, stackKey, queue)

      -- 材料を返却
      for _, entry in ipairs(removed) do exports.ox_inventory:AddItem(source, entry.item, entry.count) end

      -- 通知
      notify(source, Config.Text.inventoryFull)

      -- 処理を中断
      return
    end

    -- 作成完了の通知
    notify(source, ('%s を作成しました。納品先: %s / #%s'):format(recipe.label, target.label, parcel.serial))
  end
)



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 物資を開封するイベント "openDeliveryBox" を定義 】

  > event
      動作イベント

  > item
      使用するアイテム

  > inventory
      所持しているインベントリ

  > slot
      アイテムのスロット番号

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
exports( 'openDeliveryBox',
  function(event, item, inventory, slot)

    -- 取得したイベントが 'usingItem' でない場合は処理を中断
    if ( event ~= 'usingItem' ) then return end

    -- イベントが発生したプレイヤーのIDを取得
    local source = inventory.id

    -- 許可されていないプレイヤーの場合は処理を中断
    if ( not isAllowed(source) ) then return false end

    -- スロット情報を取得
    local slotData      = exports.ox_inventory:GetSlot(source, slot)

    -- メタデータを取得
    local metadata      = slotData and slotData.metadata

    -- 配送先IDと病院情報を取得
    local destinationId = metadata      and metadata.destinationId
    local hospital      = destinationId and hospitalById[destinationId]

    -- メタデータと病院情報の妥当性を確認 >> 一致していない場合は処理を中断
    if not hospital or metadata.ownerId ~= ownerId(source) or not metadata.stackKey then return false end

    -- 配送キューを取得
    local queue = getQueue(source, destinationId, metadata.stackKey)

    -- 配送キューの先頭の荷物を取得
    local parcel = queue[1]

    -- 配送キューにアイテムが存在しない場合は処理を中断
    if not parcel then return false end

    -- 配送キューの内容を確認
    for _, entry in ipairs(parcel.contents) do
      if not exports.ox_inventory:CanCarryItem(source, entry.item, entry.count) then
        -- 所持可能か確認できなかった場合は処理を中断して通知する
        notify(source, Config.Text.inventoryFull)
        return false
      end
    end

    -- 箱アイテムをインベントリから削除 >> 失敗した場合は処理を中断
    local removed = exports.ox_inventory:RemoveItem(source, item.name, 1, metadata, slot, false, true)
    if (not removed) then return false end

    -- 配送キューから先頭の荷物を削除
    table.remove(queue, 1)

    -- 配送キューを更新
    setQueue(source, destinationId, metadata.stackKey, queue)

    -- 配送キューの内容をインベントリに追加
    for _, entry in ipairs(parcel.contents) do
      -- アイテムをインベントリに追加
      exports.ox_inventory:AddItem(source, entry.item, entry.count)
    end

    -- 開封通知を送信
    notify(source, Config.Text.boxOpened:format(parcel.serial))

    -- 処理完了
    return true
  end
) -- openDeliveryBox



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 箱アイテムの移動制限 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
exports.ox_inventory:registerHook( 'swapItems',
  function(payload)

    -- 元のスロットのアイテム名を取得
    local sourceName = payload.fromSlot and payload.fromSlot.name

    -- 元のスロットのアイテムが箱アイテムかどうかを確認
    if ( sourceName == Config.Procurement.boxItem or sourceName == Config.Procurement.specialBoxItem ) then

      -- 箱アイテムの場合、'give' または 'drop' アクションを禁止
      if (payload.action == 'give' or payload.toType == 'drop') then
        return false
      end -- if (payload.action == 'give' or payload.toType == 'drop') then

    end -- if ( sourceName == Config.Procurement.boxItem or sourceName == Config.Procurement.specialBoxItem ) then

  end,
  {
    itemFilter = {
      [Config.Procurement.boxItem]        = true,
      [Config.Procurement.specialBoxItem] = true,
    }
  }
) -- swapItems



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 ランダムシードの初期化 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
CreateThread(
  function()
    -- ランダムシード発生器
    math.randomseed( os.time() + GetGameTimer() )
  end
) -- CreateThread
