local busy = {}
local function eligible(src)
  local p = exports.qbx_core:GetPlayer(src)
  local job = p and p.PlayerData and p.PlayerData.job
  if not job or (Config.RequireDuty and not job.onduty) then return false end
  local grade = job.grade and (job.grade.level or job.grade) or 0
  return Config.Jobs[job.name] ~= nil and tonumber(grade) >= Config.Jobs[job.name]
end
local function validPosition(src)
  local ped = GetPlayerPed(src)
  return ped and ped ~= 0 and #(GetEntityCoords(ped) - Config.Location) <= Config.Distance
end
lib.callback.register('ptech_mediora_pharmacy:craft', function(src, key)
  if busy[src] then return { ok = false, message = '処理中です' } end
  local recipe = type(key) == 'string' and Config.Recipes[key]
  if not recipe or not eligible(src) or not validPosition(src) then return { ok = false, message = '権限・場所・レシピを確認してください' } end
  busy[src] = true
  local success, result = pcall(function()
    for item, quantity in pairs(recipe.ingredients) do
      if exports.ox_inventory:GetItemCount(src, item) < quantity then return { ok = false, message = '素材不足' } end
    end
    if not exports.ox_inventory:CanCarryItem(src, recipe.output, recipe.quantity) then
      return { ok = false, message = '所持品の容量が不足しています' }
    end
    local removed = {}
    for item, quantity in pairs(recipe.ingredients) do
      if not exports.ox_inventory:RemoveItem(src, item, quantity) then
        for name, amount in pairs(removed) do
          if not exports.ox_inventory:AddItem(src, name, amount) then
            print(('[Mediora Pharmacy] CRITICAL refund failure for %s item %s'):format(src, name))
          end
        end
        return { ok = false, message = '素材消費に失敗しました' }
      end
      removed[item] = quantity
    end
    if not exports.ox_inventory:AddItem(src, recipe.output, recipe.quantity) then
      for name, amount in pairs(removed) do
        if not exports.ox_inventory:AddItem(src, name, amount) then
          print(('[Mediora Pharmacy] CRITICAL refund failure for %s item %s'):format(src, name))
        end
      end
      return { ok = false, message = '製造失敗。返却状況を管理者へ確認してください' }
    end
    return { ok = true, message = recipe.label .. 'を製造しました' }
  end)
  busy[src] = nil
  return success and result or { ok = false, message = 'サーバー処理エラー' }
end)
AddEventHandler('playerDropped', function() busy[source] = nil end)
