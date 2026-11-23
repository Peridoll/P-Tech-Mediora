---@param text string
function Framework.Client.ShowTextUI(text)
  if (Config.DrawText == "auto" and GetResourceState("jg-textui") == "started") or Config.DrawText == "jg-textui" then
    exports["jg-textui"]:DrawText(text)
  elseif (Config.DrawText == "auto" and GetResourceState("ox_lib") == "started") or Config.DrawText == "ox_lib" then
    exports["ox_lib"]:showTextUI(text, {
      position = "left-center"
    })
  elseif (Config.DrawText == "auto" and GetResourceState("okokTextUI") == "started") or Config.DrawText == "okokTextUI" then
    exports["okokTextUI"]:Open(text, "lightblue", "left")
  elseif (Config.DrawText == "auto" and GetResourceState("ps-ui") == "started") or Config.DrawText == "ps-ui" then
    exports["ps-ui"]:DisplayText(text, "primary")
  elseif Config.Framework == "QBCore" then
    exports["qb-core"]:DrawText(text)
  else
    error("You do not have a TextUI system set up!")
  end
end

function Framework.Client.HideTextUI()
  if (Config.DrawText == "auto" and GetResourceState("jg-textui") == "started") or Config.DrawText == "jg-textui" then
    exports["jg-textui"]:HideText()
  elseif (Config.DrawText == "auto" and GetResourceState("ox_lib") == "started") or Config.DrawText == "ox_lib" then
    exports["ox_lib"]:hideTextUI()
  elseif (Config.DrawText == "auto" and GetResourceState("okokTextUI") == "started") or Config.DrawText == "okokTextUI" then
    exports["okokTextUI"]:Close()
  elseif (Config.DrawText == "auto" and GetResourceState("ps-ui") == "started") or Config.DrawText == "ps-ui" then
    exports["ps-ui"]:HideText()
  elseif Config.Framework == "QBCore" then
    exports["qb-core"]:HideText()
  else
    error("You do not have a TextUI system set up!")
  end
end

---@param garageId string
---@param text string
---@param onSelect function
function Framework.Client.RadialMenuAdd(garageId, text, onSelect)
  if not Config.UseRadialMenu then return end

  if (Config.RadialMenu == "auto" and GetResourceState("ox_lib") == "started") or Config.RadialMenu == "ox_lib" then
    lib.addRadialItem({
      id = garageId,
      icon = "warehouse",
      label = text,
      onSelect = onSelect
    })
  else
    error("You do not have a radial menu system set up!")
  end
end

---@param garageId string
function Framework.Client.RadialMenuRemove(garageId)
  if not Config.UseRadialMenu then return end

  if (Config.RadialMenu == "auto" and GetResourceState("ox_lib") == "started") or Config.RadialMenu == "ox_lib" then
    lib.removeRadialItem(garageId)
  else
    error("You do not have a radial menu system set up!")
  end
end

---@param entity? integer|false
---@param coords vector4|vector3
---@param garageId string
---@param vehicleType "car"|"air"|"sea"
---@param garageType "personal"|"job"|"gang"|"impound"
---@return integer
function Framework.Client.RegisterTarget(entity, coords, garageId, vehicleType, garageType)
  if not entity then
    entity = createPedForTarget(coords)
  end

  if (Config.Target == "auto" and GetResourceState("ox_target") == "started") or Config.Target == "ox_target" then
    exports.ox_target:addLocalEntity(entity, {
      {
        label = garageType == "impound" and Config.OpenImpoundPrompt or Config.OpenGaragePrompt,
        icon = "warehouse",
        onSelect = function()
          TriggerEvent("jg-advancedgarages:client:open-garage", garageId, vehicleType, false)
        end
      },
      garageType ~= "impound" and {
        label = Config.InsertVehiclePrompt,
        icon = "warehouse",
        onSelect = function()
          TriggerEvent("jg-advancedgarages:client:store-vehicle", garageId, vehicleType, false)
        end
      } or nil
    })
  elseif (Config.Target == "auto" and GetResourceState("qb-target") == "started") or Config.Target == "qb-target" then
    exports["qb-target"]:AddTargetEntity(entity, {
      options = {
        {
          label = garageType == "impound" and Config.OpenImpoundPrompt or Config.OpenGaragePrompt,
          targeticon = "fas fa-warehouse",
          action = function()
            TriggerEvent("jg-advancedgarages:client:open-garage", garageId, vehicleType, false)
          end
        },
        garageType ~= "impound" and {
          label = Config.InsertVehiclePrompt,
          targeticon = "fas fa-warehouse",
          action = function()
            TriggerEvent("jg-advancedgarages:client:store-vehicle", garageId, vehicleType, false)
          end
        } or nil
      },
      distance = 10.0
    })
  else
    error("You do not have a target system set up!")
  end

  return entity
end

---@param entity integer
function Framework.Client.RemoveTarget(entity)
  if not entity then return end

  DeleteEntity(entity)

  if (Config.Target == "auto" and GetResourceState("ox_target") == "started") or Config.Target == "ox_target" then
    exports.ox_target:removeLocalEntity(entity)
  elseif (Config.Target == "auto" and GetResourceState("qb-target") == "started") or Config.Target == "qb-target" then
    exports["qb-target"]:RemoveTargetEntity(entity)
  else
    error("You do not have a target system set up!")
  end
end

---@param msg string
---@param type? "success" | "warning" | "error"
---@param time? number
function Framework.Client.Notify(msg, type, time)
  type = type or "success"
  time = time or 5000

  if (Config.Notifications == "auto" and GetResourceState("RxNotify") == "started") or Config.Notifications == "RxNotify" then
    exports['RxNotify']:Notify("Garages", msg, type, time)
  elseif (Config.Notifications == "auto" and GetResourceState("okokNotify") == "started") or Config.Notifications == "okokNotify" then
    exports["okokNotify"]:Alert("Garages", msg, time, type)
  elseif (Config.Notifications == "auto" and GetResourceState("ps-ui") == "started") or Config.Notifications == "ps-ui" then
    exports["ps-ui"]:Notify(msg, type, time)
  elseif (Config.Notifications == "auto" and GetResourceState("ox_lib") == "started") or Config.Notifications == "ox_lib" then
    exports["ox_lib"]:notify({
      title = "Garages",
      description = msg,
      type = type
    })
  else
    if Config.Framework == "QBCore" then
      return QBCore.Functions.Notify(msg, type, time)
    elseif Config.Framework == "Qbox" then
      exports.qbx_core:Notify(msg, type, time)
    elseif Config.Framework == "ESX" then
      return ESX.ShowNotification(msg, type)
    end
  end
end

RegisterNetEvent("jg-advancedgarages:client:notify", function(...)
  Framework.Client.Notify(...)
end)

--
-- Player Functions
--

---@return table | false playerData
function Framework.Client.GetPlayerData()
  if Config.Framework == "QBCore" then
    return QBCore.Functions.GetPlayerData()
  elseif Config.Framework == "Qbox" then
    return exports.qbx_core:GetPlayerData()
  elseif Config.Framework == "ESX" then
    return ESX.GetPlayerData()
  end

  return false
end

---@return string | false identifier
function Framework.Client.GetPlayerIdentifier()
  local playerData = Framework.Client.GetPlayerData()
  if not playerData then return false end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return playerData.citizenid
  elseif Config.Framework == "ESX" then
    return playerData.identifier
  end

  return false
end

---@param type "cash" | "bank" | "money"
function Framework.Client.GetBalance(type)
  if Config.Framework == "QBCore" then
    return QBCore.Functions.GetPlayerData().money[type]
  elseif Config.Framework == "Qbox" then
    return exports.qbx_core:GetPlayerData().money[type]
  elseif Config.Framework == "ESX" then
    if type == "cash" then type = "money" end

    for _, acc in pairs(ESX.GetPlayerData().accounts) do
      if acc.name == type then
        return acc.money
      end
    end

    return 0
  end
end

---@return {name: string, grade: number} | false job
function Framework.Client.GetPlayerJob()
  local player = Framework.Client.GetPlayerData()
  if not player or not player.job then return {} end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    return {
      name = player.job.name,
      label = player.job.label,
      grade = player.job.grade.level
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

---@return {name: string, grade: number} | false gang
function Framework.Client.GetPlayerGang()
  if (Config.Gangs == "auto" and GetResourceState("rcore_gangs") == "started") or Config.Gangs == "rcore_gangs" then
    local gang = exports.rcore_gangs:GetPlayerGang()
    if not gang then return {} end

    return {
      name = gang.name,
      label = gang.name,
      grade = 0 -- rcore_gangs' grade system are only strings
    }
  elseif (Config.Gangs == "auto" and GetResourceState("qb-gangs") == "started") or Config.Gangs == "qb-gangs" or Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    local player = Framework.Client.GetPlayerData()
    if not player or not player.gang then return {} end

    return {
      name = player.gang.name,
      label = player.gang.label,
      grade = player.gang.grade.level
    }
  elseif Config.Framework == "ESX" then
    -- To implement gangs in ESX, enable Config.GangEnableCustomESXIntegration & then add the necessary exports here.
    -- It must return the same data structure as QB/X above, with { name, label, grade }
    -- Heads up, you must also add the exports to sv-functions.lua -> Framework.Server.GetPlayerGang
    error("ESX does not natively support gangs.");
  end

  return false
end

---@return boolean dead
function Framework.Client.IsPlayerDead()
  if GetResourceState("wasabi_ambulance") == "started" then
    if LocalPlayer.state.isDead or LocalPlayer.state.dead then
      return true
    end
  end

  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    if Config.Framework == "Qbox" and LocalPlayer.state.isDead then
      return true
    end

    local player = Framework.Client.GetPlayerData()
    if not player then return false end

    if player.metadata.isdead or player.metadata.inlaststand then
      return true
    end
  elseif Config.Framework == "ESX" then
    return IsEntityDead(cache.ped)
  end

  return false
end

--
-- Vehicle Functions
--

---@param vehicle integer
---@return number fuelLevel
function Framework.Client.VehicleGetFuel(vehicle)
  if not DoesEntityExist(vehicle) then return 0 end

  if (Config.FuelSystem == "LegacyFuel" or Config.FuelSystem == "ps-fuel" or Config.FuelSystem == "lj-fuel" or Config.FuelSystem == "cdn-fuel" or Config.FuelSystem == "hyon_gas_station" or Config.FuelSystem == "okokGasStation" or Config.FuelSystem == "nd_fuel" or Config.FuelSystem == "myFuel" or Config.FuelSystem == "lc_fuel") then
    return exports[Config.FuelSystem]:GetFuel(vehicle)
  elseif Config.FuelSystem == "ti_fuel" then
    local level, type = exports["ti_fuel"]:getFuel(vehicle)
    TriggerServerEvent("jg-advancedgarages:server:save-ti-fuel-type", Framework.Client.GetPlate(vehicle), type)
    return level
  elseif Config.FuelSystem == "ox_fuel" or Config.FuelSystem == "Renewed-Fuel" then
    return GetVehicleFuelLevel(vehicle)
  elseif Config.FuelSystem == "rcore_fuel" then
    return exports.rcore_fuel:GetVehicleFuelPercentage(vehicle)
  else
    return 65 -- or set up custom fuel system here...
  end
end

---@param vehicle integer
---@param fuel number
function Framework.Client.VehicleSetFuel(vehicle, fuel)
  if not DoesEntityExist(vehicle) then return false end

  if (Config.FuelSystem == "LegacyFuel" or Config.FuelSystem == "ps-fuel" or Config.FuelSystem == "lj-fuel" or Config.FuelSystem == "cdn-fuel" or Config.FuelSystem == "hyon_gas_station" or Config.FuelSystem == "okokGasStation" or Config.FuelSystem == "nd_fuel" or Config.FuelSystem == "myFuel" or Config.FuelSystem == "Renewed-Fuel" or Config.FuelSystem == "lc_fuel") then
    exports[Config.FuelSystem]:SetFuel(vehicle, fuel)
  elseif Config.FuelSystem == "ti_fuel" then
    local fuelType = lib.callback.await("jg-advancedgarages:server:get-ti-fuel-type", false, Framework.Client.GetPlate(vehicle))
    exports["ti_fuel"]:setFuel(vehicle, fuel, fuelType or nil)
  elseif Config.FuelSystem == "ox_fuel" then
    return
  elseif Config.FuelSystem == "rcore_fuel" then
    exports.rcore_fuel:SetVehicleFuel(vehicle, fuel)
  else
    -- Setup custom fuel system here
  end
end

---[NOVA] Config.NvForcedLooks にあるモデルの見た目（リバリー/エクストラ）を固定する
---（jg が見た目データを適用し終わった後に上書きするため、出してから数秒間かけ直す）
---@param vehicleEntity integer
function NvApplyForcedLivery(vehicleEntity)
  if not Config.NvForcedLooks then return end

  local look
  local model = GetEntityModel(vehicleEntity)
  for name, value in pairs(Config.NvForcedLooks) do
    if joaat(name) == model then look = value break end
  end
  if not look then return end

  local enabledExtras
  if look.extras then
    enabledExtras = {}
    for _, id in ipairs(look.extras) do enabledExtras[id] = true end
  end

  CreateThread(function()
    for _ = 1, 15 do
      if not DoesEntityExist(vehicleEntity) then return end

      if look.livery and GetVehicleLivery(vehicleEntity) ~= look.livery then
        SetVehicleLivery(vehicleEntity, look.livery)
      end
      if GetNumVehicleMods(vehicleEntity, 48) > 0 and GetVehicleMod(vehicleEntity, 48) ~= -1 then
        SetVehicleMod(vehicleEntity, 48, -1, false) -- 改造リバリーは外す
      end

      if enabledExtras then
        for id = 0, 20 do
          if DoesExtraExist(vehicleEntity, id) then
            local shouldBeOn = enabledExtras[id] == true
            if IsVehicleExtraTurnedOn(vehicleEntity, id) ~= shouldBeOn then
              SetVehicleExtra(vehicleEntity, id, not shouldBeOn) -- 第3引数 true = オフ
            end
          end
        end
      end

      Wait(200)
    end
  end)
end

---Returns the network id of a vehicle, waiting briefly for it to be networked (used for qbx_vehiclekeys)
---@param vehicleEntity integer
---@return integer|false
function NvGetVehicleNetId(vehicleEntity)
  local timeout = GetGameTimer() + 3000
  while not NetworkGetEntityIsNetworked(vehicleEntity) do
    if GetGameTimer() > timeout or not DoesEntityExist(vehicleEntity) then
      print("^1[ERROR] qbx_vehiclekeys: vehicle is not networked, could not give/remove keys^0")
      return false
    end
    Wait(50)
  end
  return NetworkGetNetworkIdFromEntity(vehicleEntity)
end

---@param plate string
---@param vehicleEntity integer
---@param origin "personal" | "job" | "gang"
function Framework.Client.VehicleGiveKeys(plate, vehicleEntity, origin)
  if not DoesEntityExist(vehicleEntity) then return false end
  NvApplyForcedLivery(vehicleEntity)
  if not plate or plate == "" then
    print("^1[ERROR] No plate provided to VehicleGiveKeys function^0")
    return false
  end

  plate = plate:upper()

  if Config.VehicleKeys == "qb-vehiclekeys" then
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
  elseif Config.VehicleKeys == "qbx_vehiclekeys" then
    -- qbx_vehiclekeys はサーバー側でカギを管理するため、サーバー経由でカギを渡す
    local netId = NvGetVehicleNetId(vehicleEntity)
    if netId then
      lib.callback.await("jg-advancedgarages:server:qbx-give-keys", false, netId)
    end
  elseif Config.VehicleKeys == "jaksam-vehicles-keys" and origin ~= "personal" then
    TriggerServerEvent("vehicles_keys:selfGiveVehicleKeys", plate)
  elseif Config.VehicleKeys == "jc_vehiclekeys" then
    exports["jc_vehiclekeys"]:GiveKeys(plate)
  elseif Config.VehicleKeys == "mk_vehiclekeys" then
    exports["mk_vehiclekeys"]:AddKey(vehicleEntity)
  elseif Config.VehicleKeys == "qs-vehiclekeys" then
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleEntity))
    exports["qs-vehiclekeys"]:GiveKeys(plate, model)
  elseif Config.VehicleKeys == "wasabi_carlock" then
    exports.wasabi_carlock:GiveKey(plate)
  elseif Config.VehicleKeys == "cd_garage" then
    TriggerEvent("cd_garage:AddKeys", plate)
  elseif Config.VehicleKeys == "okokGarage" then
    TriggerServerEvent("okokGarage:GiveKeys", plate)
  elseif Config.VehicleKeys == "t1ger_keys" then
    if origin == "job" then
      local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleEntity))
      exports['t1ger_keys']:GiveJobKeys(plate, vehicleName, true)
    else
      TriggerServerEvent("t1ger_keys:updateOwnedKeys", plate, true)
    end
  elseif Config.VehicleKeys == "MrNewbVehicleKeys" then
    exports.MrNewbVehicleKeys:GiveKeys(vehicleEntity)
  elseif Config.VehicleKeys == "Renewed" then
    exports["Renewed-Vehiclekeys"]:addKey(plate)
  elseif Config.VehicleKeys == "tgiann-hotwire" then
    exports["tgiann-hotwire"]:CheckKeyInIgnitionWhenSpawn(vehicleEntity, plate)
  else
    -- Setup custom key system here...
  end
end

---@param plate string
---@param vehicleEntity integer
---@param origin "personal" | "job" | "gang"
function Framework.Client.VehicleRemoveKeys(plate, vehicleEntity, origin)
  if not DoesEntityExist(vehicleEntity) then return false end
  if not plate or plate == "" then
    print("^1[ERROR] No plate provided to VehicleRemoveKeys function^0")
    return false
  end

  plate = plate:upper()

  if Config.VehicleKeys == "qbx_vehiclekeys" then
    -- ガレージにしまった車のカギを回収する
    local netId = NvGetVehicleNetId(vehicleEntity)
    if netId then
      lib.callback.await("jg-advancedgarages:server:qbx-remove-keys", false, netId)
    end
  elseif Config.VehicleKeys == "qs-vehiclekeys" then
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleEntity))
    exports["qs-vehiclekeys"]:RemoveKeys(plate, model)
  elseif Config.VehicleKeys == "jc_vehiclekeys" then
    exports["jc_vehiclekeys"]:RemoveKeys(plate)
  elseif Config.VehicleKeys == "wasabi_carlock" then
    exports.wasabi_carlock:RemoveKey(plate)
  elseif Config.VehicleKeys == "t1ger_keys" then
    TriggerServerEvent("t1ger_keys:updateOwnedKeys", plate, false)
  elseif Config.VehicleKeys == "MrNewbVehicleKeys" then
    exports.MrNewbVehicleKeys:RemoveKeys(vehicleEntity)
  elseif Config.VehicleKeys == "Renewed" then
    exports["Renewed-Vehiclekeys"]:removeKey(plate)
  else
    -- Setup custom key system here...
  end
end


---@param vehicle table
---@return string|number|false model
function Framework.Client.GetModelColumn(vehicle)
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

---@param vehicle integer
---@return table | false
function Framework.Client.GetModsColumn(vehicle)
  if Config.Framework == "QBCore" or Config.Framework == "Qbox" then
    if type(vehicle.mods) == "string" then
      return json.decode(vehicle.mods)
    else
      return vehicle.mods
    end
  elseif Config.Framework == "ESX" then
    if type(vehicle.vehicle) == "string" then
      return json.decode(vehicle.vehicle)
    else
      return vehicle.vehicle
    end
  end

  return false
end

---@param vehicle integer
---@return table|false props
function Framework.Client.GetVehicleProperties(vehicle)
  if GetResourceState("jg-mechanic") == "started" then
    return exports["jg-mechanic"]:getVehicleProperties(vehicle)
  else
    if Config.Framework == "QBCore" then
      return QBCore.Functions.GetVehicleProperties(vehicle)
    elseif Config.Framework == "Qbox" then
      return lib.getVehicleProperties(vehicle) or false
    elseif Config.Framework == "ESX" then
      return ESX.Game.GetVehicleProperties(vehicle)
    end
  end

  return false
end

---@param vehicle integer
---@param props table
function Framework.Client.SetVehicleProperties(vehicle, props)
  if GetResourceState("jg-mechanic") == "started" then
    return exports["jg-mechanic"]:setVehicleProperties(vehicle, props)
  else
    if Config.Framework == "QBCore" then
      return QBCore.Functions.SetVehicleProperties(vehicle, props)
    elseif Config.Framework == "Qbox" then
      return lib.setVehicleProperties(vehicle, props)
    elseif Config.Framework == "ESX" then
      return ESX.Game.SetVehicleProperties(vehicle, props)
    end
  end
end

---@param vehicle integer
---@return string|false plate
function Framework.Client.GetPlate(vehicle)
  local plate = GetVehicleNumberPlateText(vehicle)
  if not plate or plate == nil or plate == "" then return false end

  if GetResourceState("brazzers-fakeplates") == "started" then
    local originalPlate = lib.callback.await("jg-advancedgarages:server:brazzers-get-plate-from-fakeplate", false, plate)
    if originalPlate then plate = originalPlate end
  end

  local trPlate = string.gsub(plate, "^%s*(.-)%s*$", "%1")
  return trPlate
end

-- Get a nice vehicle label from either QBCore shared or GTA natives
---@param model string | number
function Framework.Client.GetVehicleLabel(model)
  local hash = convertModelToHash(model)

  if Config.VehicleLabels[model] then
    return Config.VehicleLabels[model]
  end

  if Config.VehicleLabels[tostring(hash)] then
    return Config.VehicleLabels[tostring(hash)]
  end

  if type(model) == "string" and Config.Framework == "QBCore" then
    local vehShared = QBCore.Shared.Vehicles?[model]
    if vehShared then
      return vehShared.brand .. " " .. vehShared.name
    end
  end

  if Config.Framework == "Qbox" then
    local vehShared = exports.qbx_core:GetVehiclesByHash()?[hash]
    if vehShared then
      return vehShared.brand .. " " .. vehShared.name
    end
  end

  local makeName = GetMakeNameFromVehicleModel(hash)
  local modelName = GetDisplayNameFromVehicleModel(hash)
  local label = GetLabelText(makeName) .. " " .. GetLabelText(modelName)

  if makeName == "CARNOTFOUND" or modelName == "CARNOTFOUND" then
    label = tostring(model)
  else
    if GetLabelText(modelName) == "NULL" and GetLabelText(makeName) == "NULL" then
      label = (makeName or "") .. " " .. (modelName or "")
    elseif GetLabelText(makeName) == "NULL" then
      label = GetLabelText(modelName)
    end
  end

  return label
end

-- rcore_gangs
RegisterNetEvent('rcore_gangs:client:set_gang')
AddEventHandler('rcore_gangs:client:set_gang', function(gang)
  TriggerEvent("jg-advancedgarages:client:update-blips-text-uis")
end)


--
-- [NOVA] すぐ出しガレージ（Config.InstantSpawnGarages）
--

local nvBusy = false

AddStateBagChangeHandler("nvInstantLivery", nil, function(bagName, _, livery)
  if type(livery) ~= "number" then return end

  CreateThread(function()
    for _ = 1, 20 do
      local vehicle = GetEntityFromStateBagName(bagName)
      if vehicle ~= 0 and DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle)
        and Entity(vehicle).state.nvInstantLivery == livery
        and GetVehicleLivery(vehicle) ~= livery then
        SetVehicleLivery(vehicle, livery)
      end
      Wait(200)
    end
  end)
end)

---@param garageId string
function NvInstantSpawn(garageId)
  if nvBusy then return end
  nvBusy = true
  Framework.Client.HideTextUI()

  local netId = lib.callback.await("jg-advancedgarages:server:nv-instant-spawn", false, garageId)
  if netId then
    local ok, vehicle = pcall(lib.waitFor, function()
      if NetworkDoesEntityExistWithNetworkId(netId) then
        local veh = NetToVeh(netId)
        if veh ~= 0 then return veh end
      end
    end, nil, 5000)

    if ok and vehicle then
      local cfg = Config.InstantSpawnGarages[garageId]
      if GetVehiclePedIsIn(cache.ped, false) ~= vehicle then
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
      end
      if cfg.livery ~= nil and NetworkHasControlOfEntity(vehicle) then
        SetVehicleLivery(vehicle, cfg.livery)
      end
      SetVehicleDirtLevel(vehicle, 0.0)
    end
  else
    Framework.Client.Notify("出せませんでした", "error")
  end

  nvBusy = false
end

local instantBoarding = false
RegisterNetEvent("jg-advancedgarages:client:nv-instant-board", function(netId, seat, coords)
  if source ~= 65535 or instantBoarding or nvBusy then return end
  local ped = cache.ped
  if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end

  instantBoarding = true
  local origin = GetEntityCoords(ped)
  DoScreenFadeOut(250)
  Wait(250)
  FreezeEntityPosition(ped, true)
  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)

  local deadline = GetGameTimer() + 5000
  local boarded = false
  repeat
    if NetworkDoesEntityExistWithNetworkId(netId) then
      local vehicle = NetToVeh(netId)
      if vehicle ~= 0 and seat < GetVehicleMaxNumberOfPassengers(vehicle) and IsVehicleSeatFree(vehicle, seat) then
        SetPedIntoVehicle(ped, vehicle, seat)
        boarded = GetPedInVehicleSeat(vehicle, seat) == ped
      end
    end
    if not boarded then Wait(0) end
  until boarded or GetGameTimer() >= deadline

  if not boarded then
    RequestCollisionAtCoord(origin.x, origin.y, origin.z)
    SetEntityCoordsNoOffset(ped, origin.x, origin.y, origin.z, false, false, false)
    local collisionDeadline = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do Wait(0) end
  end
  FreezeEntityPosition(ped, false)
  DoScreenFadeIn(250)
  instantBoarding = false
end)

local function returnFromInstantGarage(coords)
  DoScreenFadeOut(250)
  Wait(250)
  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
  local deadline = GetGameTimer() + 2000
  while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < deadline do Wait(0) end
  DoScreenFadeIn(250)
end

RegisterNetEvent("jg-advancedgarages:client:nv-instant-return", function(garageId)
  if source ~= 65535 then return end
  local garage = Config.JobGarageLocations[garageId]
  if garage and garage.storeCoords then returnFromInstantGarage(garage.coords) end
end)

---@param garageId string
function NvInstantStore(garageId)
  if nvBusy then return end
  nvBusy = true
  Framework.Client.HideTextUI()

  local vehicle = cache.vehicle
  if vehicle and DoesEntityExist(vehicle) then
    local garage = Config.JobGarageLocations[garageId]
    local returnCoords = garage and garage.storeCoords and garage.coords
    if not returnCoords then
      TaskLeaveVehicle(cache.ped, vehicle, 0)
      Wait(1500)
    end
    local stored = lib.callback.await("jg-advancedgarages:server:nv-instant-store", false, garageId, NetworkGetNetworkIdFromEntity(vehicle))
    if stored and returnCoords then returnFromInstantGarage(returnCoords) end
  end

  nvBusy = false
end


--
-- [NOVA] /iv：どんな車でも押収（未登録車はその場で消去）
--

---@return integer|false
local function nvGetTargetVehicle()
  if cache.vehicle and DoesEntityExist(cache.vehicle) then return cache.vehicle end
  local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
  return vehicle or false
end

RegisterCommand(Config.NvImpoundCommand or "iv", function()
  local vehicle = nvGetTargetVehicle()
  if not vehicle then
    return Framework.Client.Notify(Locale.noVehiclesNearbyError or "近くに車両がありません", "error")
  end

  local plate = GetVehicleNumberPlateText(vehicle)
  local netId = NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or 0
  local result = lib.callback.await("jg-advancedgarages:server:nv-impound-check", false, netId, plate)

  if result == "owned" then
    -- プレイヤー所有車 → jg本体の押収画面（理由・時間・費用）
    ExecuteCommand(Config.ImpoundCommand)
  elseif result == "deleted" then
    Framework.Client.Notify("未登録の車両のため押収して消去しました", "success")
  elseif result == "delete_local" then
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    Framework.Client.Notify("未登録の車両のため押収して消去しました", "success")
  else
    Framework.Client.Notify(Locale.actionNotAllowedError or "この行動は許可されていません", "error")
  end
end, false)

TriggerEvent("chat:addSuggestion", "/" .. (Config.NvImpoundCommand or "iv"), "近くの車両を押収する")
