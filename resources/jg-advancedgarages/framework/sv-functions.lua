--
-- Core Functions
--

---@param src integer
---@param msg string
---@param type "success" | "warning" | "error"
function Framework.Server.Notify(src, msg, type)
  TriggerClientEvent("jg-advancedgarages:client:notify", src, msg, type, 5000)
end

---@param src integer
---@returns boolean
function Framework.Server.IsAdmin(src)
  return IsPlayerAceAllowed(tostring(src), "command") or false
end

function Framework.Server.PayIntoSocietyFund(jobName, money)
  local usingNewQBBanking = GetResourceState("qb-banking") == "started" and tonumber(string.sub(GetResourceMetadata("qb-banking", "version", 0), 1, 3)) >= 2

  if (Config.Banking == "auto" and GetResourceState("RxBanking") == "started") or Config.Banking == "RxBanking" then
    exports['RxBanking']:AddSocietyMoney(jobName, money)
  elseif (Config.Banking == "auto" and GetResourceState("Renewed-Banking") == "started") or Config.Banking == "Renewed-Banking" then
    exports['Renewed-Banking']:addAccountMoney(jobName, money)
  elseif (Config.Banking == "auto" and GetResourceState("okokBanking") == "started") or Config.Banking == "okokBanking" then
    exports['okokBanking']:AddMoney(jobName, money)
  elseif (Config.Banking == "auto" and GetResourceState("fd_banking") == "started") or Config.banking == "fd_banking" then
    exports.fd_banking:AddMoney(jobName, money)
  elseif (Config.Banking == "auto" and GetResourceState("tgg-banking") == "started") or Config.Banking == "tgg-banking" then
    exports['tgg-banking']:AddSocietyMoney(jobName, money)
  elseif (Config.Banking == "auto" and (Config.Framework == "QBCore" or Config.Framework == "Qbox")) then
    if usingNewQBBanking then
      exports["qb-banking"]:AddMoney(jobName, money)
    else
      exports["qb-management"]:AddMoney(jobName, money)
    end
  elseif Config.Banking == "qb-banking" then
    exports["qb-banking"]:AddMoney(jobName, money)
  elseif Config.Banking == "qb-management" then
    exports["qb-management"]:AddMoney(jobName, money)
  elseif (Config.Banking == "auto" and Config.Framework == "ESX") or Config.Banking == "esx_addonaccount" then
    TriggerEvent("esx_society:getSociety", jobName, function(society)
      TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
        account.addMoney(money)
      end)
    end)
  end
end

--
-- Player Functions
--

---@param src integer
function Framework.Server.GetPlayer(src)
  if Config.Framework == "QBCore" then
    return QBCore.Functions.GetPlayer(src)
  elseif Config.Framework == "Qbox" then
    return exports.qbx_core:GetPlayer(src)
  elseif Config.Framework == "ESX" then
    return ESX.GetPlayerFromId(src)
  end
end

---@param src integer
function Framework.Server.GetPlayerInfo(src)
  local player = Framework.Server.GetPlayer(src)
  if not player then return false end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return {
      name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    }
  elseif Config.Framework == "ESX" then
    return {
      name = player.getName()
    }
  end
end

---@param src integer
---@return {name:string,label:string,grade:number} | false
function Framework.Server.GetPlayerJob(src)
  local player = Framework.Server.GetPlayer(src)
  if not player then return false end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    if not player.PlayerData then return false end

    return {
      name = player.PlayerData.job.name,
      label = player.PlayerData.job.label,
      grade = player.PlayerData.job.grade?.level or 0,
    }
  elseif Config.Framework == "ESX" then
    return {
      name = player.job.name,
      label = player.job.label,
      grade = player.job.grade
    }
  end

  return false
end

---@param src integer
---@return {name:string,label:string,grade:number} | false
function Framework.Server.GetPlayerGang(src)
  if (Config.Gangs == "auto" and GetResourceState("rcore_gangs") == "started") or Config.Gangs == "rcore_gangs"  then
    local gang = exports.rcore_gangs:GetPlayerGang(src)
    if not gang then return {} end

    return {
      name = gang.name,
      label = gang.name,
      grade = 0 -- rcore_gangs' grade system are only strings
    }
  elseif (Config.Gangs == "auto" and GetResourceState("qb-gangs") == "started") or Config.Gangs == "qb-gangs" or Config.Framework == "QBCore" or Config.Framework == "Qbox" then

    local player = Framework.Server.GetPlayer(src)
    if not player then return false end

    return {
      name = player.PlayerData.gang.name,
      label = player.PlayerData.gang.label,
      grade = player.PlayerData.gang.grade.level
    }
  elseif Config.Framework == "ESX" then
    -- To implement gangs in ESX, enable Config.GangEnableCustomESXIntegration & then add the necessary exports here.
    -- It must return the same data structure as QB/X above, with { name, label, grade }
    -- Heads up, you must also add the exports to cl-functions.lua -> Framework.Client.GetPlayerGang
    error("ESX does not natively support gangs.");
  end

  return false
end

---@param src integer
function Framework.Server.GetPlayerIdentifier(src)
  local player = Framework.Server.GetPlayer(src)
  if not player then return false end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return player.PlayerData.citizenid
  elseif Config.Framework == "ESX" then
    return player.getIdentifier()
  end
end

---@param identifier string
function Framework.Server.GetSrcFromIdentifier(identifier)
  if Config.Framework == "QBCore" then
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then return false end
    return player.PlayerData.source
  elseif Config.Framework == "Qbox" then
    local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
    if not player then return false end
    return player.PlayerData.source
  elseif Config.Framework == "ESX" then
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then return false end
    return xPlayer.source
  end
end

---@param src integer
---@param type "cash" | "bank" | "money"
function Framework.Server.GetPlayerBalance(src, type)
  local player = Framework.Server.GetPlayer(src)
  if not player then return 0 end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return player.PlayerData.money[type]
  elseif Config.Framework == "ESX" then
    if type == "cash" then type = "money" end

    for _, acc in pairs(player.getAccounts()) do
      if acc.name == type then
        return acc.money
      end
    end

    return 0
  end
end

---@param src integer
---@param amount number
---@param account "cash" | "bank" | "money"
---@return boolean success
function Framework.Server.PlayerRemoveMoney(src, amount, account)
  local player = Framework.Server.GetPlayer(src)
  account = account or "bank"

  if Framework.Server.GetPlayerBalance(src, account) < amount then
    Framework.Server.Notify(src, Locale.notEnoughMoneyError, "error")
    return false
  end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    player.Functions.RemoveMoney(account, round(amount, 0))
  elseif Config.Framework == "ESX" then
    if account == "cash" then account = "money" end
    player.removeAccountMoney(account, round(amount, 0))
  end

  return true
end

---@return {id:number,identifier:string,name:string}[] players
function Framework.Server.GetPlayers()
  local players = {}

  for _, playerId in ipairs(GetPlayers()) do
    players[#players+1] = {
      id = tonumber(playerId),
      identifier = Framework.Server.GetPlayerIdentifier(tonumber(playerId, 10)),
      name = Framework.Server.GetPlayerInfo(tonumber(playerId, 10))?.name
    }
  end

  return players
end

---@return table | false jobs
function Framework.Server.GetJobs()
  if Config.Framework == "QBCore" then
    return QBCore.Shared.Jobs
  elseif Config.Framework == "Qbox" then
    return exports.qbx_core:GetJobs()
  elseif Config.Framework == "ESX" then
    return ESX.GetJobs()
  end

  return false
end

---@return table | false gangs
function Framework.Server.GetGangs()
  if (Config.Gangs == "auto" and GetResourceState("rcore_gangs") == "started") or Config.Gangs == "rcore_gangs" then
    local gangs = {}
    for _, gang in ipairs(MySQL.query.await("SELECT name FROM gangs") or {}) do
      gangs[gang.name] = gang.name
    end
    return gangs
  elseif (Config.Gangs == "auto" and GetResourceState("qb-gangs") == "started") or Config.Gangs == "qb-gangs" then
    if Config.Framework == "QBCore" then
      return QBCore.Shared.Gangs
    elseif Config.Framework == "Qbox" then
      return exports.qbx_core:GetGangs()
    end
  elseif Config.Framework == "ESX" then
    error("ESX does not natively support gangs.");
  end

  return false
end

---@param vehicle integer
---@return string | false plate
function Framework.Server.GetPlate(vehicle)
  local plate = GetVehicleNumberPlateText(vehicle)
  if not plate or plate == nil or plate == "" then return false end

  if GetResourceState("brazzers-fakeplates") == "started" then
    local originalPlate = MySQL.scalar.await("SELECT plate FROM player_vehicles WHERE fakeplate = ?", {plate})
    if originalPlate then plate = originalPlate end
  end

  local trPlate = string.gsub(plate, "^%s*(.-)%s*$", "%1")
  return trPlate
end

---@param vehicle boolean|QueryResult|unknown|{ [number]: { [string]: unknown  }|{ [string]: unknown }}
---@return string | number | false model
function Framework.Server.GetModelColumn(vehicle)
  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return vehicle.vehicle or tonumber(vehicle.hash) or false
  elseif Config.Framework == "ESX" then
    if not vehicle or not vehicle.vehicle then return false end

    if type(vehicle.vehicle) == "string" then
      if not json.decode(vehicle.vehicle) then return false end
      return json.decode(vehicle.vehicle).model
    else
      return vehicle.vehicle.model
    end
  end

  return false
end

--
-- ti_fuel
--

RegisterNetEvent("jg-advancedgarages:server:save-ti-fuel-type", function(plate, type)
  MySQL.query.await("ALTER TABLE " .. Framework.VehiclesTable .. " ADD COLUMN IF NOT EXISTS `ti_fuel_type` VARCHAR(100) DEFAULT '';")
  MySQL.update.await("UPDATE " .. Framework.VehiclesTable .. " SET ti_fuel_type = ? WHERE plate = ?", {type, plate});
end)

lib.callback.register("jg-advancedgarages:server:get-ti-fuel-type", function(src, plate)
  MySQL.query.await("ALTER TABLE " .. Framework.VehiclesTable .. " ADD COLUMN IF NOT EXISTS `ti_fuel_type` VARCHAR(100) DEFAULT '';")
  return MySQL.scalar.await("SELECT ti_fuel_type FROM  " .. Framework.VehiclesTable .. " WHERE plate = ?", {plate}) or false
end)

--
-- Brazzers-FakePlates
--

if GetResourceState("brazzers-fakeplates") == "started" then
  lib.callback.register("jg-advancedgarages:server:brazzers-get-plate-from-fakeplate", function(_, fakeplate)
    local result = MySQL.scalar.await("SELECT plate FROM player_vehicles WHERE fakeplate = ?", {fakeplate})
    if result then return result end
    return false
  end)

  lib.callback.register("jg-advancedgarages:server:brazzers-get-fakeplate-from-plate", function(_, plate)
    local result = MySQL.scalar.await("SELECT fakeplate FROM player_vehicles WHERE plate = ?", {plate})
    if result then return result end
    return false
  end)
end

--
-- qbx_vehiclekeys
--

if Config.VehicleKeys == "qbx_vehiclekeys" then
  ---ガレージから出した/しまう車がプレイヤーの近くにある本物の車両か確認する
  ---@param src integer
  ---@param netId integer
  ---@return integer|false
  local function getNearbyVehicle(src, netId)
    if type(netId) ~= "number" then return false end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 50.0 then return false end

    return vehicle
  end

  lib.callback.register("jg-advancedgarages:server:qbx-give-keys", function(src, netId)
    local vehicle = getNearbyVehicle(src, netId)
    if not vehicle then return false end
    exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    return true
  end)

  lib.callback.register("jg-advancedgarages:server:qbx-remove-keys", function(src, netId)
    local vehicle = getNearbyVehicle(src, netId)
    if not vehicle then return false end
    exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true)
    return true
  end)
end

--
-- [NOVA] すぐ出しガレージ（Config.InstantSpawnGarages）
--

if Config.InstantSpawnGarages then
  local spawned = {} -- [src] = vehicle

  ---@param src integer
  ---@param garageId string
  ---@return table|false
  local function getAllowedGarage(src, garageId, storing)
    if type(garageId) ~= "string" then return false end
    local garage = Config.JobGarageLocations[garageId]
    if not garage or not garage.job then return false end
    if not Config.InstantSpawnGarages[garageId] and not (storing and garage.storeCoords and garage.instantReturnGroup) then return false end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local jobName = player.PlayerData.job and player.PlayerData.job.name
    local allowed = false
    for _, job in ipairs(garage.job) do
      if job == jobName then allowed = true break end
    end
    if not allowed then return false end

    local ped = GetPlayerPed(src)
    local position = GetEntityCoords(ped)
    local storeCoords = storing and garage.storeCoords
    if storeCoords then
      local half = (garage.distance or 15) / 2
      if math.abs(position.x - storeCoords.x) > half or math.abs(position.y - storeCoords.y) > half
        or math.abs(position.z - storeCoords.z) > 2.0 then return false end
    elseif #(position - vector3(garage.coords.x, garage.coords.y, garage.coords.z)) > (garage.distance or 15) + 10.0 then
      return false
    end

    return garage
  end

  local function deleteSpawned(src)
    local old = spawned[src]
    if old and DoesEntityExist(old) then DeleteEntity(old) end
    spawned[src] = nil
  end

  lib.callback.register("jg-advancedgarages:server:nv-instant-spawn", function(src, garageId)
    local garage = getAllowedGarage(src, garageId)
    if not garage then return false end
    local cfg = Config.InstantSpawnGarages[garageId]

    -- 前に出したものが残っていれば消す（出しっぱなし防止）
    deleteSpawned(src)

    local spawn = garage.spawn
    if type(spawn) == "table" and spawn[1] then spawn = spawn[1] end

    local vehicle = CreateVehicleServerSetter(joaat(cfg.model), cfg.vehicleType or "automobile", spawn.x, spawn.y, spawn.z, spawn.w)
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(vehicle) do
      if GetGameTimer() > timeout then return false end
      Wait(0)
    end

    local plate = (cfg.platePrefix or "JOB") .. tostring(math.random(10000, 99999))
    SetVehicleNumberPlateText(vehicle, plate:sub(1, 8))
    local state = Entity(vehicle).state
    state:set("nvInstantGarage", garageId, true)
    if cfg.livery ~= nil then state:set("nvInstantLivery", cfg.livery, true) end
    spawned[src] = vehicle

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local passengerSeats = cfg.passengerSeats or 0
    local bucket = GetPlayerRoutingBucket(src)
    if passengerSeats > 0 then SetEntityRoutingBucket(vehicle, bucket) end
    SetPedIntoVehicle(GetPlayerPed(src), vehicle, -1)
    if passengerSeats > 0 then
      local candidates = {}
      local center = garage.coords
      local half = (garage.distance or 15) / 2
      for _, playerId in ipairs(GetPlayers()) do
        local passenger = tonumber(playerId)
        local ped = GetPlayerPed(passenger)
        if passenger ~= src and ped ~= 0 and GetPlayerRoutingBucket(passenger) == bucket
          and GetVehiclePedIsIn(ped, false) == 0 and GetEntityHealth(ped) > 0 then
          local position = GetEntityCoords(ped)
          if math.abs(position.x - center.x) <= half and math.abs(position.y - center.y) <= half
            and math.abs(position.z - center.z) <= 2.0 then
            candidates[#candidates + 1] = { player = passenger, distance = #(position - center.xyz) }
          end
        end
      end
      table.sort(candidates, function(a, b) return a.distance < b.distance end)
      for index = 1, math.min(passengerSeats, #candidates) do
        TriggerClientEvent("jg-advancedgarages:client:nv-instant-board", candidates[index].player,
          netId, index - 1, vector3(spawn.x, spawn.y, spawn.z))
      end
    end

    if Config.VehicleKeys == "qbx_vehiclekeys" then
      exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    end

    return netId
  end)

  lib.callback.register("jg-advancedgarages:server:nv-instant-store", function(src, garageId, netId)
    local garage = getAllowedGarage(src, garageId, true)
    if not garage then return false end
    if type(netId) ~= "number" then return false end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local originId = Entity(vehicle).state.nvInstantGarage
    if not originId or not Config.InstantSpawnGarages[originId] then return false end
    local origin = Config.JobGarageLocations[originId]
    if originId ~= garageId and (not origin or not origin.instantReturnGroup
      or origin.instantReturnGroup ~= garage.instantReturnGroup) then return false end
    if garage.storeCoords and (spawned[src] ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src)) then
      return false
    end

    if Config.VehicleKeys == "qbx_vehiclekeys" then
      exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true)
    end

    local passengers = {}
    if garage.storeCoords then
      for _, playerId in ipairs(GetPlayers()) do
        local passenger = tonumber(playerId)
        local ped = GetPlayerPed(passenger)
        if passenger ~= src and ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle then
          passengers[#passengers + 1] = passenger
        end
      end
    end

    DeleteEntity(vehicle)
    for _, passenger in ipairs(passengers) do
      TriggerClientEvent("jg-advancedgarages:client:nv-instant-return", passenger, garageId)
    end
    for owner, veh in pairs(spawned) do
      if veh == vehicle then spawned[owner] = nil end
    end
    return true
  end)

  AddEventHandler("playerDropped", function()
    deleteSpawned(source)
  end)
end

--
-- [NOVA] /iv：どんな車でも押収（未登録車はその場で消去）
--

---@param src integer
---@return boolean
local function nvCanImpound(src)
  if Framework.Server.IsAdmin(src) then return true end
  local job = Framework.Server.GetPlayerJob(src)
  if not job or not job.name then return false end
  for _, impound in pairs(Config.ImpoundLocations or {}) do
    for _, j in ipairs(impound.job or {}) do
      if j == job.name then return true end
    end
  end
  return false
end

---@param plate string
---@return boolean
local function nvIsOwnedPlate(plate)
  if type(plate) ~= "string" or plate == "" then return false end
  local trimmed = plate:gsub("^%s+", ""):gsub("%s+$", "")
  local result = MySQL.scalar.await(
    ("SELECT 1 FROM %s WHERE plate = ? OR plate = ? LIMIT 1"):format(Framework.VehiclesTable),
    { plate, trimmed }
  )
  return result ~= nil
end

-- 戻り値: "owned"（jgの押収画面へ） / "deleted"（サーバーで消去済み） / "delete_local"（クライアントで消去） / false（不可）
lib.callback.register("jg-advancedgarages:server:nv-impound-check", function(src, netId, plate)
  if not nvCanImpound(src) then return false end

  if nvIsOwnedPlate(plate) then return "owned" end

  if type(netId) == "number" and netId ~= 0 then
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2 then
      local ped = GetPlayerPed(src)
      if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 15.0 then return false end
      if Config.VehicleKeys == "qbx_vehiclekeys" then
        pcall(function() exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true) end)
      end
      DeleteEntity(vehicle)
      return "deleted"
    end
  end

  -- ネットワーク化されていないNPC車両など
  return "delete_local"
end)

--
-- [NOVA] ジョブ所有車両の自動登録（Config.NvJobVehiclesAutoRegister）
--

CreateThread(function()
  if not Config.NvJobVehiclesAutoRegister then return end
  Wait(3000) -- DB 準備待ち

  local idCol = Framework.PlayerIdentifier -- Qbox: citizenid（ジョブ車両はここにジョブ名が入る）
  local tbl = Framework.VehiclesTable

  -- citizenid → players の外部キー制約を外す（ジョブ/ギャング所有車を登録するため）
  if Config.NvDropVehicleOwnerForeignKey then
    local fks = MySQL.query.await([[
      SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? AND REFERENCED_TABLE_NAME IS NOT NULL
    ]], { tbl, idCol }) or {}

    for _, fk in ipairs(fks) do
      local ok, err = pcall(function()
        MySQL.query.await(("ALTER TABLE `%s` DROP FOREIGN KEY `%s`"):format(tbl, fk.CONSTRAINT_NAME))
      end)
      if ok then
        print(("^2[NOVA] %s の外部キー制約 %s を外しました（ジョブ所有車の登録用）^0"):format(tbl, fk.CONSTRAINT_NAME))
      else
        print(("^1[NOVA] 外部キー制約 %s を外せませんでした: %s^0"):format(fk.CONSTRAINT_NAME, tostring(err)))
      end
    end
  end

  for _, entry in ipairs(Config.NvJobVehiclesAutoRegister) do
    local hash = joaat(entry.model)
    local added = 0

    for i = 1, entry.count do
      local plate = ("%s%02d"):format(entry.platePrefix, i):sub(1, 8)
      local exists = MySQL.scalar.await(("SELECT 1 FROM %s WHERE plate = ? LIMIT 1"):format(tbl), { plate })

      if not exists then
        local props = json.encode({ model = hash, plate = plate, livery = entry.livery or 0, fuelLevel = 100.0, bodyHealth = 1000.0, engineHealth = 1000.0 })
        local ok, err = pcall(function()
          MySQL.insert.await(
            ("INSERT INTO %s (%s, vehicle, hash, mods, plate, fuel, engine, body, in_garage, garage_id, job_vehicle, job_vehicle_rank, nickname) VALUES (?, ?, ?, ?, ?, 100, 1000, 1000, 1, ?, 1, ?, ?)"):format(tbl, idCol),
            { entry.job, entry.model, tostring(hash), props, plate, entry.garage, entry.minJobGrade or 0,
              entry.nickname and (entry.count > 1 and (entry.nickname .. " " .. i) or entry.nickname)
                or ((entry.nicknamePrefix or "") .. i .. (entry.nicknameSuffix or "")) }
          )
        end)
        if ok then
          added = added + 1
        else
          print(("^1[NOVA] %s の登録に失敗しました: %s^0"):format(plate, tostring(err)))
        end
      end
    end

    if added > 0 then
      print(("^2[NOVA] %s の %s を %d 台登録しました（ガレージ: %s）^0"):format(entry.job, entry.model, added, entry.garage))
    end

    -- 存在しないガレージ名（以前の "Police" など）で登録済みの車両は、どのガレージにも出てこないため
    -- entry.garage に移す（ガレージ内にあるもの・外に出ているもの両方）
    if Config.JobGarageLocations[entry.garage] then
      local garageNames = {}
      for name in pairs(Config.JobGarageLocations) do garageNames[#garageNames + 1] = name end
      local orphanParams = { entry.garage, entry.job, entry.platePrefix .. "%" }
      for _, name in ipairs(garageNames) do orphanParams[#orphanParams + 1] = name end
      local moved = MySQL.update.await(
        ("UPDATE %s SET garage_id = ? WHERE %s = ? AND job_vehicle = 1 AND plate LIKE ? AND (garage_id IS NULL OR garage_id NOT IN (%s))")
          :format(tbl, idCol, ("?,"):rep(#garageNames):sub(1, -2)),
        orphanParams
      )
      if moved and moved > 0 then
        print(("^3[NOVA] %s の %s %d 台を、存在しないガレージから %s に移しました^0"):format(entry.job, entry.model, moved, entry.garage))
      end
    else
      print(("^1[NOVA] ジョブ車両 %s のガレージ \"%s\" が Config.JobGarageLocations にありません^0"):format(entry.model, tostring(entry.garage)))
    end

    -- count を減らした場合：範囲外の番号を削除
    local validPlates = {}
    for i = 1, entry.count do
      validPlates[#validPlates + 1] = ("%s%02d"):format(entry.platePrefix, i):sub(1, 8)
    end
    local placeholders = ("?,"):rep(#validPlates):sub(1, -2)
    local params = { entry.job, entry.platePrefix .. "%" }
    for _, p in ipairs(validPlates) do params[#params + 1] = p end

    local removed = MySQL.update.await(
      ("DELETE FROM %s WHERE %s = ? AND job_vehicle = 1 AND plate LIKE ? AND plate NOT IN (%s)"):format(tbl, idCol, placeholders),
      params
    )
    if removed and removed > 0 then
      print(("^3[NOVA] %s の %s を %d 台削除しました（count = %d に合わせて）^0"):format(entry.job, entry.model, removed, entry.count))
    end
  end
end)
