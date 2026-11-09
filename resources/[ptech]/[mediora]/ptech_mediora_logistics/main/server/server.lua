
--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local pointById, hospitalById, itemById = {}, {}, Config.Items
local weightedContentsByRarity = {}
local rarityOrder = { 'C', 'UC', 'R', 'SR', 'UR' }

for _, point in ipairs(Config.CollectPoints) do pointById[point.id] = point end
for _, hospital in ipairs(Config.Hospitals) do hospitalById[hospital.id] = hospital end
for _, entry in ipairs(Config.BoxContents) do
  local item = itemById[entry.item]
  local rarity = item and item.rarity or 'C'
  weightedContentsByRarity[rarity] = weightedContentsByRarity[rarity] or { totalWeight = 0, entries = {} }
  local pool = weightedContentsByRarity[rarity]
  pool.totalWeight = pool.totalWeight + entry.weight
  pool.entries[#pool.entries + 1] = { item = entry.item, ceiling = pool.totalWeight }
end

local function getGradeProfile(grade)
  local profiles = Config.Procurement.gradeProfiles or {}
  return profiles[tonumber(grade)] or profiles[1]
end


local function pickWeighted(pool)
  if not pool or pool.totalWeight < 1 then return nil end
  local roll = math.random(pool.totalWeight)
  for _, entry in ipairs(pool.entries) do
    if roll <= entry.ceiling then return entry.item end
  end
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
local function isNear(source, point, distance)
  local ped = GetPlayerPed(source)
  if ped == 0 then return false end
  return #(GetEntityCoords(ped) - point.coords) <= (distance or Config.Procurement.interactDistance) + 1.0
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
--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function normalStackKey(destinationId)
    return ('regular:%s'):format(destinationId)
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function specialStackKey(destinationId)
  return ('special:%s'):format(destinationId)
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
local function rollContents(grade)
  local profile = getGradeProfile(grade)
  if not profile then return {} end

  local countMultiplier = profile.itemCountMultiplier or 1.0
  local minItems = math.floor(Config.Procurement.minItems * countMultiplier + 0.5)
  local maxItems = math.floor(Config.Procurement.maxItems * countMultiplier + 0.5)
  local totalCount = math.random(minItems, math.max(minItems, maxItems))
  local counts = {}
  for _ = 1, totalCount do
    local chance = profile.rarityChance or {}
    local roll = math.random(10000)
    local threshold, selectedRarity, selectedIndex = 0, 'C', 1
    for index, rarity in ipairs(rarityOrder) do
      threshold = threshold + (chance[rarity] or 0) * 100
      if roll <= threshold then
        selectedRarity = rarity
        selectedIndex = index
        break
      end
    end

    local selectedItem = pickWeighted(weightedContentsByRarity[selectedRarity])
    if not selectedItem then
      for index = selectedIndex - 1, 1, -1 do
        selectedItem = pickWeighted(weightedContentsByRarity[rarityOrder[index]])
        if selectedItem then break end
      end
    end
    if not selectedItem then
      for index = selectedIndex + 1, #rarityOrder do
        selectedItem = pickWeighted(weightedContentsByRarity[rarityOrder[index]])
        if selectedItem then break end
      end
    end
    if selectedItem then counts[selectedItem] = (counts[selectedItem] or 0) + 1 end
  end

  local contents = {}
  for item, count in pairs(counts) do
    contents[#contents + 1] = { item = item, count = count, rarity = itemById[item].rarity }
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
-- 旧回収品の物流用メタデータを除き、通常品と同じスタック条件へ戻す。
local function cleanItemRarityLabels(source)
  for _, slot in pairs(exports.ox_inventory:GetInventoryItems(source) or {}) do
    local item = itemById[slot.name]
    local metadata = slot.metadata
    if item and metadata and (metadata.medioraRarity or metadata.medioraSourceGrade) then
      local updated = {}
      for key, value in pairs(metadata) do updated[key] = value end
      updated.medioraRarity = nil
      updated.medioraSourceGrade = nil
      if updated.label == item.label
        or (metadata.medioraRarity and updated.label == ('%s [%s]'):format(item.label, metadata.medioraRarity)) then
        updated.label = nil
      end
      if updated.description == item.description
        or (type(updated.description) == 'string'
          and (updated.description:find('\nランク ', 1, true) or updated.description:find('\n回収グレード ', 1, true))) then
        updated.description = nil
      end
      exports.ox_inventory:SetMetadata(source, slot.slot, updated)
    end
  end
end

CreateThread(function()
  Wait(1000)
  for _, playerId in ipairs(GetPlayers()) do
    cleanItemRarityLabels(tonumber(playerId))
  end
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
  local playerId = player and player.PlayerData and player.PlayerData.source
  if playerId then cleanItemRarityLabels(playerId) end
end)

local function boxMetadata(hospital, source, stackKey, kind, extra)
  local metadata = {
    destinationId = hospital.id,
    destinationLabel = hospital.label,
    ownerId = ownerId(source),
    stackKey = stackKey,
    boxKind = kind,
    label = kind == 'special' and '特注医療物資' or '医療物資',
    description = ('納品先: %s'):format(hospital.label),
  }
  for key, value in pairs(extra or {}) do metadata[key] = value end
  return metadata
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function addBox(source, hospital, contents, kind, date, recipe, sourceGrade)
  local stackKey = kind == 'special'
    and specialStackKey(hospital.id)
    or normalStackKey(hospital.id)
  local itemName = kind == 'special' and Config.Procurement.specialBoxItem or Config.Procurement.boxItem
  local metadata = boxMetadata(hospital, source, stackKey, kind)
  if not exports.ox_inventory:CanCarryItem(source, itemName, 1, metadata) then return false end

  local queue = getQueue(source, hospital.id, stackKey)
  local parcel = {
    serial = nextSerial(),
    contents = contents,
    kind = kind,
    date = date,
    sourceGrade = sourceGrade,
  }
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

local function hasFullServices(hospital)
  return hospital and hospital.id == (Config.Economy.fullServiceHospitalId or Config.Economy.tradeHospitalId)
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
  local value = contentsSellValue(parcel.contents)
  if parcel.kind ~= 'special' then
    return math.floor(value * Config.Economy.unopenedBoxSellMultiplier), false, false
  end
  local multiplier = Config.Economy.specialBoxBaseMultiplier
  local gradeProfile = getGradeProfile(parcel.sourceGrade or 1)
  multiplier = multiplier * (gradeProfile and gradeProfile.sellMultiplier or 1.0)
  local premium = parcel.kind == 'special' and parcel.date == getTodayDate() and hospital.id == parcel.bonusHospital
  if premium then multiplier = multiplier * Config.Economy.specialBoxSellMultiplier end
  local expiredSpecial = parcel.kind == 'special' and not premium
  -- 特注段ボールは病院の日替わり倍率と当日ボーナスを適用する。
  local hospitalRate = getHospitalMultiplier(hospital.id)
  return math.floor(value * multiplier * hospitalRate), premium, expiredSpecial
end



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
-- クールタイムはプレイヤー単位かつ収集地点単位で永続保存する。
local function collectionCooldownKey(source, pointId)
  return ('cooldown:%s:%s'):format(playerKey(source), pointId)
end

lib.callback.register('ptech_mediora_logistics:server:getCollectionCooldown', function(source, pointId)
  local point = pointById[pointId]
  if not point or not isAllowed(source) then return 0 end
  local distance = Config.Procurement.interactDistance
  if point.prop then
    distance = math.max(distance, Config.Procurement.propDisplayDistance or 10.0)
  end
  if not isNear(source, point, distance) then return 0 end
  return math.max(0, GetResourceKvpInt(collectionCooldownKey(source, point.id)) - os.time())
end)

local function collectSupplies(source, pointId)
  local point = pointById[pointId]
  if not point or not isAllowed(source) or not isNear(source, point) then return 0 end

  local cooldownKey = collectionCooldownKey(source, point.id)
  local now = os.time()
  local remaining = GetResourceKvpInt(cooldownKey) - now
  if remaining > 0 then
    notify(source, Config.Text.cooldown)
    return remaining
  end

  local hospital = Config.Hospitals[math.random(#Config.Hospitals)]
  local grade = tonumber(point.grade) or 1
  local success, serial = addBox(source, hospital, rollContents(grade), 'regular', nil, nil, grade)
  if not success then
    notify(source, Config.Text.collectionFailed)
    return 0
  end

  local cooldown = Config.Procurement.cooldownSeconds
  SetResourceKvpInt(cooldownKey, now + cooldown)
  notify(source, ('段ボール #%s を調達しました。納品先: %s'):format(serial, hospital.label))
  return cooldown
end

lib.callback.register('ptech_mediora_logistics:server:collect', collectSupplies)
RegisterNetEvent('ptech_mediora_logistics:server:collect', function(pointId)
  collectSupplies(source, pointId)
end)



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
local function counterBuyPrice(item)
  local price = item.buyPrice
  if not price or price <= 0 then return end
  return math.floor(price * Config.Economy.counterBuyMultiplier + 0.5)
end

lib.callback.register('ptech_mediora_logistics:server:getTradeCatalog',
  function(source, hospitalId, mode)
    local hospital = hospitalById[hospitalId]
    if not hospital or hospital.id ~= Config.Economy.tradeHospitalId or not isAllowed(source) or not isNear(source, hospital) then return {} end
    if mode ~= 'buy' and mode ~= 'sell' then return {} end

    local catalog = {}
    if mode == 'buy' then
      for itemId, item in pairs(Config.Items) do
        local price = counterBuyPrice(item)
        if price and price > 0 then
          catalog[#catalog + 1] = {
            key = itemId,
            id = itemId,
            label = item.label,
            price = price,
            count = 0,
            grade = 0,
          }
        end
      end
    else
      local byItemAndGrade = {}
      for _, slot in pairs(exports.ox_inventory:GetInventoryItems(source) or {}) do
        local item = itemById[slot.name]
        if item and item.sellPrice and item.sellPrice > 0 and (not item.buyPrice or item.sellPrice < item.buyPrice) then
          local grade = 0
          local key = ('%s:%s'):format(slot.name, grade)
          local entry = byItemAndGrade[key]
          if not entry then
            local profile = grade > 0 and getGradeProfile(grade) or nil
            local multiplier = profile and profile.sellMultiplier or 1.0
            entry = {
              key = key,
              id = slot.name,
              label = item.label,
              price = math.floor(item.sellPrice * multiplier + 0.5),
              count = 0,
              grade = grade,
            }
            byItemAndGrade[key] = entry
          end
          entry.count = entry.count + (slot.count or 0)
        end
      end
      for _, entry in pairs(byItemAndGrade) do
        if entry.count > 0 then catalog[#catalog + 1] = entry end
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
  function(hospitalId, mode, itemId, count, sourceGrade)
    local source = source
    local hospital = hospitalById[hospitalId]
    local item = itemById[itemId]
    if not hospital or hospital.id ~= Config.Economy.tradeHospitalId or not item or not isAllowed(source) or not isNear(source, hospital) then return end
    if type(count) ~= 'number' or count % 1 ~= 0 or count < 1 or count > Config.Economy.maxTransactionItems then
      notify(source, Config.Text.tradeInvalid)
      return
    end

    if mode == 'buy' then
      local unitPrice = counterBuyPrice(item)
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
      local grade = 0

      local matchingSlots, availableCount, total = {}, 0, 0
      for _, slot in pairs(exports.ox_inventory:GetInventoryItems(source) or {}) do
        if slot.name == itemId then
          matchingSlots[#matchingSlots + 1] = slot
          availableCount = availableCount + (slot.count or 0)
        end
      end
      table.sort(matchingSlots, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
      if count > availableCount then
        notify(source, Config.Text.tradeInvalid)
        return
      end

      local profile = grade > 0 and getGradeProfile(grade) or nil
      local multiplier = profile and profile.sellMultiplier or 1.0
      if not item.sellPrice or item.sellPrice <= 0 or (item.buyPrice and item.sellPrice >= item.buyPrice) then
        notify(source, Config.Text.tradeInvalid)
        return
      end
      local unitPrice = math.floor(item.sellPrice * multiplier + 0.5)
      total = unitPrice * count

      local remaining, removed = count, {}
      for _, slot in ipairs(matchingSlots) do
        if remaining <= 0 then break end
        local amount = math.min(slot.count or 0, remaining)
        local metadata = slot.metadata or {}
        if amount > 0 and not exports.ox_inventory:RemoveItem(source, itemId, amount, metadata, slot.slot, false, true) then
          for _, entry in ipairs(removed) do
            exports.ox_inventory:AddItem(source, itemId, entry.count, entry.metadata)
          end
          notify(source, Config.Text.tradeInvalid)
          return
        end
        if amount > 0 then
          removed[#removed + 1] = { count = amount, metadata = metadata }
          remaining = remaining - amount
        end
      end

      if remaining > 0 then
        for _, entry in ipairs(removed) do
          exports.ox_inventory:AddItem(source, itemId, entry.count, entry.metadata)
        end
        notify(source, Config.Text.tradeInvalid)
        return
      end

      if not exports.qbx_core:AddMoney(source, Config.Economy.moneyType, total, 'mediora-logistics-sale') then
        for _, entry in ipairs(removed) do
          exports.ox_inventory:AddItem(source, itemId, entry.count, entry.metadata)
        end
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
    if not hasFullServices(hospital) or not isAllowed(source) or not isNear(source, hospital) then return {} end
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
    if not hasFullServices(hospital) or not recipe or not isAllowed(source) or not isNear(source, hospital) then return end
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
    if not hasFullServices(hospital) or not isAllowed(source) or not isNear(source, hospital) then return nil end
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
    if (not hasFullServices(hospital)) or (not target) or (not isAllowed(source)) or (not isNear(source, hospital)) then return end

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
    local stackKey = specialStackKey(target.id)
    local metadata = boxMetadata(
      target,
      source,
      stackKey,
      'special'
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
    local metadata = slotData and slotData.metadata
    local destinationId = metadata and metadata.destinationId
    local hospital = destinationId and hospitalById[destinationId]
    if not slotData or (slotData.name ~= Config.Procurement.boxItem and slotData.name ~= Config.Procurement.specialBoxItem)
      or not hospital or metadata.ownerId ~= ownerId(source) or not metadata.stackKey then return false end

    TriggerClientEvent('ptech_mediora_logistics:client:showBoxMenu', source, slot, hospital.label,
      hospital.coords.x, hospital.coords.y)
    return false -- 使用時は選択メニューを開き、選択後にサーバーで開封する
  end
) -- openDeliveryBox

RegisterNetEvent('ptech_mediora_logistics:server:openDeliveryBox', function(slot)
  local source = source
  if not isAllowed(source) or type(slot) ~= 'number' then return end
  local slotData = exports.ox_inventory:GetSlot(source, slot)
  local metadata = slotData and slotData.metadata
  local destinationId = metadata and metadata.destinationId
  local hospital = destinationId and hospitalById[destinationId]
  if not slotData or (slotData.name ~= Config.Procurement.boxItem and slotData.name ~= Config.Procurement.specialBoxItem)
    or not hospital or metadata.ownerId ~= ownerId(source) or not metadata.stackKey then return end

  local queue = getQueue(source, destinationId, metadata.stackKey)
  local parcel = queue[1]
  if not parcel then return end
  for _, entry in ipairs(parcel.contents or {}) do
    local itemMetadata = {}
    if not exports.ox_inventory:CanCarryItem(source, entry.item, entry.count, itemMetadata) then
      notify(source, Config.Text.inventoryFull)
      return
    end
  end

  if not exports.ox_inventory:RemoveItem(source, slotData.name, 1, metadata, slot, false, true) then return end
  table.remove(queue, 1)
  setQueue(source, destinationId, metadata.stackKey, queue)
  local added = {}
  for _, entry in ipairs(parcel.contents) do
    local itemMetadata = {}
    if not exports.ox_inventory:AddItem(source, entry.item, entry.count, itemMetadata) then
      for _, addedEntry in ipairs(added) do
        exports.ox_inventory:RemoveItem(source, addedEntry.item, addedEntry.count, addedEntry.metadata)
      end
      table.insert(queue, 1, parcel)
      setQueue(source, destinationId, metadata.stackKey, queue)
      exports.ox_inventory:AddItem(source, slotData.name, 1, metadata)
      notify(source, Config.Text.inventoryFull)
      return
    end
    added[#added + 1] = { item = entry.item, count = entry.count, metadata = itemMetadata }
  end
  notify(source, Config.Text.boxOpened:format(parcel.serial))
end)



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
