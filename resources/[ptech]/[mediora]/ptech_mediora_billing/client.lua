RegisterCommand('mbilldraft', function()
  local nearby, distance = nil, Config.Distance
  local here = GetEntityCoords(PlayerPedId())
  for _, id in ipairs(GetActivePlayers()) do
    if id ~= PlayerId() then
      local ped = GetPlayerPed(id)
      if ped ~= 0 then
        local d = #(here - GetEntityCoords(ped))
        if d < distance then nearby, distance = GetPlayerServerId(id), d end
      end
    end
  end
  if not nearby then return lib.notify({ description = '近くに患者がいません', type = 'error' }) end
  local opts = {}
  for code, price in pairs(Config.Price) do opts[#opts+1] = { value = code, label = code .. ' ($' .. price .. ')' } end
  local fields = lib.inputDialog('診療請求ドラフト（支払いは発生しません）', {{ type = 'multi-select', label = '項目', options = opts, required = true }})
  if not fields then return end
  local r = lib.callback.await('ptech_mediora_billing:draft', false, nearby, fields[1])
  lib.notify({ description = r and (r.message or ('保存: '..r.id..' $'..r.total)) or '通信失敗', type = r and r.ok and 'success' or 'error' })
end)
