local GARAGE_ZONE_Z_DIST = 4.0
local inVehicle, blips, zones, peds = nil, {}, {}, {}
local cachedGarageLocations
local instantStoreZones = {}
local promptZone

function getAvailableGarageLocations()
  if not cachedGarageLocations then
    cachedGarageLocations = lib.callback.await("jg-advancedgarages:server:get-available-garage-locations", false)
  end

  return cachedGarageLocations or {}
end

---@param coords vector3
---@param marker table
function drawMarkerOnFrame(coords, marker)
  ---@diagnostic disable-next-line: missing-parameter
  DrawMarker(marker.id, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0, marker.size.x,  marker.size.y, marker.size.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, marker.bobUpAndDown, marker.faceCamera, 0, marker.rotate, marker.drawOnEnts)
end

---@param name string
---@param coords vector3
---@param blipId integer
---@param blipColour integer
---@param blipScale number
local function createBlip(name, coords, blipId, blipColour, blipScale)
  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(blip, blipId)
  SetBlipColour(blip, blipColour)
  SetBlipScale(blip, blipScale)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(name)
  EndTextCommandSetBlipName(blip)
  return blip
end

---@param garageId string
---@param coords vector3|vector4
---@param dist number
---@param marker? table | false | nil
---@param onEnter? function
---@param onExit? function
---@param inside? function
local function createLocation(garageId, coords, dist, marker, onEnter, onExit, inside)
  local point = lib.zones.box({
    coords = coords,
    size = vector3(dist, dist, GARAGE_ZONE_Z_DIST),
    rotation = coords.w or 0,
    garageId = garageId,
    onEnter = onEnter,
    onExit = onExit,
    inside = inside
  })

  zones[#zones+1] = point

  local markerPoint = lib.points.new({
    coords = coords,
    distance = dist * 4,
    garageId = garageId
  })

  if not marker then return point end

  function markerPoint:nearby()
    drawMarkerOnFrame(coords, marker)
  end

  zones[#zones+1] = markerPoint
  return point
end

---Runs on tick while ped is in a garage zone
---@param garageId string
---@param garageType "car"|"sea"|"air"
---@param isImpound boolean
local function pedIsInGarageZone(garageId, garageType, isImpound, mode, zone)
  local pedIsInVehicle = cache.vehicle and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped
  local instantGarageId = pedIsInVehicle and Entity(cache.vehicle).state.nvInstantGarage
  local priorityZone
  local origin = instantGarageId and Config.JobGarageLocations[instantGarageId]
  if origin then
    local coords = GetEntityCoords(cache.ped)
    local closestDistance = math.huge
    for id, storeZone in pairs(instantStoreZones) do
      local destination = Config.JobGarageLocations[id]
      if (id == instantGarageId or (origin.instantReturnGroup and origin.instantReturnGroup == destination.instantReturnGroup))
        and storeZone:contains(coords) then
        local distance = #(coords - storeZone.coords.xyz)
        if distance < closestDistance or (distance == closestDistance and storeZone.id < priorityZone.id) then
          priorityZone = storeZone
          closestDistance = distance
        end
      end
    end
  end
  if priorityZone and priorityZone ~= zone then return end

  if (mode == "store" and not pedIsInVehicle) or (mode == "open" and cache.vehicle) then
    if promptZone == zone then
      promptZone = nil
      if Config.UseRadialMenu then
        Framework.Client.RadialMenuRemove(garageId)
      else
        Framework.Client.HideTextUI()
      end
      inVehicle = nil
    end
    return
  end
  local prompt = isImpound and Config.OpenImpoundPrompt or (pedIsInVehicle and Config.InsertVehiclePrompt or Config.OpenGaragePrompt)
  local action = function()
    local pedIsInVehicle = cache.vehicle and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped
    if (mode == "store" and not pedIsInVehicle) or (mode == "open" and cache.vehicle) then return end
    -- [NOVA] すぐ出しガレージ
    if priorityZone == zone and mode == "store" then
      return CreateThread(function() NvInstantStore(garageId) end)
    end
    if Config.InstantSpawnGarages and Config.InstantSpawnGarages[garageId] then
      if not pedIsInVehicle then
        return CreateThread(function() NvInstantSpawn(garageId) end)
      elseif Entity(cache.vehicle).state.nvInstantGarage == garageId then
        return CreateThread(function() NvInstantStore(garageId) end)
      end
    end

    if pedIsInVehicle then
      TriggerEvent("jg-advancedgarages:client:store-vehicle", garageId, garageType, false)
    else
      TriggerEvent("jg-advancedgarages:client:open-garage", garageId, garageType, false)
    end
  end

  if inVehicle ~= pedIsInVehicle or (priorityZone == zone and promptZone ~= zone) then
    promptZone = zone
    if Config.UseRadialMenu then
      Framework.Client.RadialMenuAdd(garageId, prompt, action)
    else
      Framework.Client.ShowTextUI(prompt)
    end

    inVehicle = pedIsInVehicle
  end

  if Config.UseRadialMenu then return end
  if IsControlJustPressed(0, isImpound and Config.OpenImpoundKeyBind or (pedIsInVehicle and Config.InsertVehicleKeyBind or Config.OpenGarageKeyBind)) then
    action()
  end
end

---@param garages table
local function createTargetZones(garages)
  -- [NOVA] 以前は更新のたびに古い受付NPCが消されず増え続けていたため、削除してから作り直す
  for _, ped in ipairs(peds) do
    Framework.Client.RemoveTarget(ped)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
  end
  peds = {}

  for _, zone in ipairs(zones) do zone:remove() end  -- Remove existing zones
  zones = {}

  for garageId, garage in pairs(garages) do
    local entity = Framework.Client.RegisterTarget(false, garage.coords, garageId, garage.type, garage.garageType)

    peds[#peds+1] = entity
  end
end

---@param garages table
local function createZones(garages)
  instantStoreZones = {}
  promptZone = nil
  for _, zone in ipairs(zones) do zone:remove() end  -- Remove existing zones
  zones = {}
  -- [NOVA] ゾーン作り直し時に表示中の案内が残らないようにする
  if inVehicle ~= nil then
    if Config.UseRadialMenu then
      for garageId in pairs(garages) do Framework.Client.RadialMenuRemove(garageId) end
    else
      Framework.Client.HideTextUI()
    end
    inVehicle = nil
  end

  for garageId, garage in pairs(garages) do
    if garage then
      local definition = Config.JobGarageLocations[garageId]
        or Config.GangGarageLocations[garageId]
        or Config.GarageLocations[garageId]
      local storeCoords = garage.garageType ~= "impound" and definition and definition.storeCoords

      local function addZone(coords, mode)
        local zone
        zone = createLocation(
          garageId,
          coords,
          garage.distance,
          not garage.hideMarkers and garage.markers or false,
          nil,
          function()
            if promptZone ~= zone then return end
            promptZone = nil
            if Config.UseRadialMenu then
              Framework.Client.RadialMenuRemove(garageId)
            else
              Framework.Client.HideTextUI()
            end
            inVehicle = nil
          end,
          function()
            pedIsInGarageZone(garageId, garage.type, garage.garageType == "impound", mode, zone)
          end
        )
        return zone
      end

      addZone(garage.coords, storeCoords and "open" or nil)
      if storeCoords then
        local zone = addZone(storeCoords, "store")
        if Config.JobGarageLocations[garageId] and (definition.instantReturnGroup
          or (Config.InstantSpawnGarages and Config.InstantSpawnGarages[garageId])) then
          instantStoreZones[garageId] = zone
        end
      end
    end
  end
end

local function createGarageZonesAndBlips()
  for _, blip in ipairs(blips) do RemoveBlip(blip) end -- Remove existing blips
  blips = {}

  local garages = getAvailableGarageLocations()

  if Config.UseTarget then
    createTargetZones(garages)
  else
    createZones(garages)
  end

  for garageId, garage in pairs(garages) do
    if garage then
      -- Blip
      if not garage.hideBlip then
        local blipName = garage.garageType == "impound" and Locale.impound or garage.garageType == "job" and Locale.jobGarage or garage.garageType == "gang" and Locale.gangGarage or Locale.garage
        if garage.uniqueBlips then blipName = blipName .. ": " .. garageId end
        local blip = createBlip(blipName, garage.coords, garage.blip.id, garage.blip.color, garage.blip.scale)
        blips[#blips + 1] = blip
      end
    end
  end
end

RegisterNetEvent("jg-advancedgarages:client:update-blips-text-uis", function()
  cachedGarageLocations = lib.callback.await("jg-advancedgarages:server:get-available-garage-locations", false)
  createGarageZonesAndBlips()
end)

CreateThread(function()
  Wait(2500)
  createGarageZonesAndBlips()
end)

-- Delete peds in case the script restarts
AddEventHandler("onResourceStop", function(resourceName)
  if (GetCurrentResourceName() == resourceName) then
    for _, ped in ipairs(peds) do DeleteEntity(ped) end
  end
end)