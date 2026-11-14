local ready = false
print(('[mediora orders] build=20261111-catalog-2 path=%s'):format(GetResourcePath(GetCurrentResourceName())))
local ttl = 24 * 60 * 60
local ox = exports.ox_inventory
local qbx = exports.qbx_core
local locks = {}
local pickupOwners = {}
local prefix = 'ptech_mediora_logistics:orders:'

local function failure(message)
  return { ok = false, error = message }
end

local function character(source, access)
  local player = qbx:GetPlayer(source)
  local data = player and player.PlayerData
  if not data then return end
  if access then
    local job = data.job
    if not job or (next(Config.AllowedJobs or {}) and not Config.AllowedJobs[job.name])
        or (access == 'pickup' and Config.RequireOnDuty and not job.onduty) then return end
  end
  return data
end

local function locked(citizen, work)
  if locks[citizen] then return failure('注文を処理中です。') end
  locks[citizen] = true
  local ok, result = pcall(work)
  locks[citizen] = nil
  if not ok then
    print(('[mediora orders] %s: %s'):format(citizen, result))
    return failure('処理結果を確認できません。注文履歴を確認してください。')
  end
  return result
end

local function transition(id, from, to)
  return MySQL.update.await('UPDATE mediora_logistics_orders SET status = ? WHERE id = ? AND status = ?',
    { to, id, from }) == 1
end

local function expire()
  MySQL.update.await([[
    UPDATE mediora_logistics_orders SET status = 'refund_due'
    WHERE status = 'waiting' AND expires_at <= ?
  ]], { os.time() })
end

local function saveBalance(source, citizen, account, expected)
  qbx:Save(source)
  for _ = 1, 20 do
    local raw = MySQL.scalar.await('SELECT money FROM players WHERE citizenid = ?', { citizen })
    local money = raw and json.decode(raw)
    if money and tonumber(money[account]) == expected then return true end
    Wait(250)
  end
  return false
end

local function refund(source, citizen)
  local rows = MySQL.query.await([[
    SELECT id, total, account FROM mediora_logistics_orders
    WHERE citizenid = ? AND status = 'refund_due' ORDER BY id LIMIT 10
  ]], { citizen })
  for _, row in ipairs(rows) do
    local data = character(source)
    local balance = data and data.citizenid == citizen and data.money[row.account]
    if type(balance) ~= 'number' then return end
    if transition(row.id, 'refund_due', 'refunding') then
      data = character(source)
      if not data or data.citizenid ~= citizen then
        transition(row.id, 'refunding', 'refund_due')
        return
      end
      balance = data.money[row.account]
      if not qbx:AddMoney(source, row.account, row.total, 'mediora-order-refund-' .. row.id) then
        transition(row.id, 'refunding', 'refund_due')
        return
      end
      if not saveBalance(source, citizen, row.account, balance + row.total) then
        print(('[mediora orders] refund #%s requires reconciliation'):format(row.id))
        return
      end
      transition(row.id, 'refunding', 'refunded')
    end
  end
end

MySQL.ready(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS mediora_logistics_orders (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      citizenid VARCHAR(50) NOT NULL,
      request_key VARCHAR(64) NOT NULL,
      items LONGTEXT NOT NULL,
      total INT UNSIGNED NOT NULL,
      account VARCHAR(20) NOT NULL,
      expires_at BIGINT UNSIGNED NOT NULL,
      status VARCHAR(20) NOT NULL,
      UNIQUE KEY mediora_order_request (citizenid, request_key),
      KEY mediora_order_expiry (status, expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  expire()
  MySQL.update.await("UPDATE mediora_logistics_orders SET status = 'waiting' WHERE status = 'handing_over'")
  local pending = MySQL.query.await("SELECT id, status FROM mediora_logistics_orders WHERE status IN ('paying', 'refunding')")
  for _, row in ipairs(pending) do
    print(('[mediora orders] order #%s requires reconciliation (%s)'):format(row.id, row.status))
  end
  ready = true
  print('[mediora orders] build=20261111-catalog-2 database ready')
  CreateThread(function()
    while true do
      local ok, err = pcall(function()
        expire()
        for source, player in pairs(qbx:GetQBPlayers()) do
          local citizen = player.PlayerData.citizenid
          if not locks[citizen] then locked(citizen, function() refund(source, citizen) end) end
        end
      end)
      if not ok then print('[mediora orders] ' .. tostring(err)) end
      Wait(30000)
    end
  end)
end)

RegisterCommand('mediora_resolve_order', function(source, args)
  if source ~= 0 or not ready then return end
  local id, target = tonumber(args[1]), args[2]
  local states = { waiting = 'paying', declined = 'paying', refunded = 'refunding', refund_due = 'refunding' }
  if not id or id < 1 or id % 1 ~= 0 or not states[target] then
    print('Usage: mediora_resolve_order <id> <waiting|declined|refunded|refund_due>')
    return
  end
  local row = MySQL.single.await('SELECT citizenid FROM mediora_logistics_orders WHERE id = ?', { id })
  if not row then return end
  local result = locked(row.citizenid, function()
    return { ok = transition(id, states[target], target) }
  end)
  print(('[mediora orders] #%d -> %s: %s'):format(id, target, result.ok and 'ok' or 'unchanged'))
end, true)

local function history(citizen, pickupOnly)
  local filter = pickupOnly and " AND status IN ('waiting', 'handed_over')" or ''
  local rows = MySQL.query.await(
    'SELECT id, items, total, status, expires_at AS expiresAt FROM mediora_logistics_orders WHERE citizenid = ?'
      .. filter .. ' ORDER BY id DESC LIMIT 50', { citizen })
  for _, row in ipairs(rows) do
    row.items = json.decode(row.items)
    if row.status == 'waiting' and row.expiresAt <= os.time() then row.status = 'refund_due' end
  end
  return rows
end

local injuryLabels = {
  fracture = '骨折',
  beat = '打撲',
  shot = '銃創',
  stabbed = '刺し傷',
  burned = '火傷',
}

lib.callback.register(prefix .. 'catalog', function(source)
  if not ready then return failure('注文データベースの準備ができていません。') end
  local data = character(source, 'tablet')
  if not data then return failure('救急職で利用できます。') end
  local catalog = {}
  for id, item in pairs(Config.Items) do
    if item.buyPrice and item.buyPrice > 0 then
      local available = type(ox:Items(id)) == 'table'
      local effect = item.effect or {}
      local treatment = item.treatment or injuryLabels[effect.injury]
      if effect.type == 'heal' then
        treatment = effect.clearBleeding and '出血・体力回復' or '体力回復'
      end
      catalog[#catalog + 1] = {
        id = id,
        label = item.label,
        description = item.description,
        image = item.client and item.client.image or item.image,
        treatment = treatment,
        price = item.buyPrice,
        available = available,
        owned = available and (ox:GetItemCount(source, id) or 0) or 0,
      }
    end
  end
  table.sort(catalog, function(a, b) return a.label < b.label end)
  local ok, orders = pcall(history, data.citizenid)
  if not ok then print(('[mediora orders] history unavailable: %s'):format(orders)) end
  return { ok = true, items = catalog, orders = ok and orders or {}, historyUnavailable = not ok,
    limit = Config.Economy.maxTransactionItems }
end)

lib.callback.register(prefix .. 'place', function(source, payload)
  local data = ready and character(source, 'tablet')
  if not data then return failure('現在、注文できません。') end
  if type(payload) ~= 'table' or type(payload.key) ~= 'string' or #payload.key > 64
      or not payload.key:match('^[%w-]+$') or type(payload.cart) ~= 'table' then
    return failure('注文内容を確認してください。')
  end
  local citizen = data.citizenid
  return locked(citizen, function()
    local previous = MySQL.single.await(
      'SELECT id, status FROM mediora_logistics_orders WHERE citizenid = ? AND request_key = ?', { citizen, payload.key })
    if previous then
      if previous.status == 'declined' then
        return { ok = false, error = '前回の決済は不成立でした。もう一度購入できます。', retryWithNewKey = true }
      end
      if previous.status == 'paying' then
        return failure('この注文の決済状況を履歴で確認してください。')
      end
      return { ok = true, id = previous.id }
    end
    local items, quantity, total = {}, 0, 0
    for id, count in pairs(payload.cart) do
      local item = Config.Items[id]
      if not item or not item.buyPrice or item.buyPrice <= 0 or not ox:Items(id)
          or type(count) ~= 'number' or count < 1 or count % 1 ~= 0 then
        return failure('注文内容を確認してください。')
      end
      quantity = quantity + count
      if quantity > Config.Economy.maxTransactionItems then return failure('注文できる数量を超えています。') end
      total = total + item.buyPrice * count
      items[#items + 1] = { name = id, count = count, label = item.label }
    end
    if #items == 0 or total % 1 ~= 0 or total > 2147483647 then return failure('注文内容を確認してください。') end
    if payload.total ~= total then return failure('価格が変わりました。ストアを開き直してください。') end
    local account = Config.Economy.moneyType
    if (data.money[account] or 0) < total then return failure('所持金が不足しています。') end
    local id = MySQL.insert.await([[
      INSERT INTO mediora_logistics_orders (citizenid, request_key, items, total, account, expires_at, status)
      VALUES (?, ?, ?, ?, ?, ?, 'paying')
    ]], { citizen, payload.key, json.encode(items), total, account, os.time() + ttl })
    if not id then return failure('注文を保存できませんでした。') end
    local current = character(source, 'tablet')
    local balance = current and current.citizenid == citizen and current.money[account]
    if not balance or balance < total or not qbx:RemoveMoney(source, account, total, 'mediora-order-' .. id) then
      assert(transition(id, 'paying', 'declined'))
      print(('[mediora orders] payment declined: order=%s account=%s amount=%s'):format(id, account, total))
      return { ok = false, error = '支払いが成立しませんでした。残高を確認してください。', retryWithNewKey = true }
    end
    if not saveBalance(source, citizen, account, balance - total) then
      print(('[mediora orders] payment #%s requires reconciliation'):format(id))
      return failure('決済結果を確認中です。再注文する前に履歴を確認してください。')
    end
    assert(transition(id, 'paying', 'waiting'))
    return { ok = true, id = id }
  end)
end)

local function pickupLocation(source)
  local ped = GetPlayerPed(source)
  if ped == 0 then return end
  for _, hospital in ipairs(Config.Hospitals) do
    if hospital.id == 'pillbox' and #(GetEntityCoords(ped) - hospital.coords) <= Config.Procurement.interactDistance + 1 then
      return hospital.coords
    end
  end
end

ox:registerHook('openInventory', function(payload)
  local stash = tostring(payload.inventoryId):match('^(mediora_order_%d+)')
  if not stash then return end
  local data = character(payload.source, 'pickup')
  if not data or pickupOwners[stash] ~= data.citizenid or not pickupLocation(payload.source) then return false end
end)

ox:registerHook('swapItems', function(payload)
  if tostring(payload.toInventory):match('^mediora_order_%d+') then return false end
end)

lib.callback.register(prefix .. 'pickupList', function(source)
  local data = ready and character(source, 'pickup')
  if not data or not pickupLocation(source) then return failure('ピルボックスの窓口で受け取れます。') end
  return { ok = true, orders = history(data.citizenid, true) }
end)

lib.callback.register(prefix .. 'pickup', function(source, id)
  local data = ready and character(source, 'pickup')
  if not data or not pickupLocation(source) or type(id) ~= 'number' or id < 1 or id % 1 ~= 0 then
    return failure('ピルボックスの窓口で受け取れます。')
  end
  local citizen = data.citizenid
  return locked(citizen, function()
    local order = MySQL.single.await([[
      SELECT items, status, expires_at FROM mediora_logistics_orders WHERE id = ? AND citizenid = ?
    ]], { id, citizen })
    local coords = pickupLocation(source)
    local current = character(source, 'pickup')
    if not order or not coords or not current or current.citizenid ~= citizen then return failure('注文を確認できません。') end
    local stash = ('mediora_order_%d'):format(id)
    local items = json.decode(order.items)
    local slotLimit = 0
    for _, item in ipairs(items) do slotLimit = slotLimit + item.count end
    if order.status == 'waiting' and order.expires_at > os.time() then
      local slots = {}
      for _, item in ipairs(items) do
        local definition = ox:Items(item.name)
        if not definition then return failure('現在渡せない商品があります。') end
        local stacks = definition.stack == false and item.count or 1
        for _ = 1, stacks do
          slots[#slots + 1] = { slot = #slots + 1, name = item.name, count = item.count / stacks }
        end
      end
      if not transition(id, 'waiting', 'handing_over') then return failure('注文を確認できません。') end
      local committed = MySQL.transaction.await({
        { query = 'INSERT INTO ox_inventory (owner, name, data) VALUES (?, ?, ?)', values = { citizen, stash, json.encode(slots) } },
        { query = "UPDATE mediora_logistics_orders SET status = 'handed_over' WHERE id = ? AND status = 'handing_over'", values = { id } },
      })
      if not committed then
        transition(id, 'handing_over', 'waiting')
        return failure('受け取りを準備できませんでした。')
      end
    elseif order.status ~= 'handed_over' then
      return failure('この注文は受取期限を過ぎています。')
    end
    pickupOwners[stash] = citizen
    ox:RegisterStash(stash, ('ピルボックス 注文 #%d'):format(id), slotLimit, 1000000, citizen, nil, coords)
    return { ok = true, stash = stash, owner = citizen }
  end)
end)
