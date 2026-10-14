local function permitted(src, target)
  local medic = exports.qbx_core:GetPlayer(src)
  local patient = type(target) == 'number' and exports.qbx_core:GetPlayer(target)
  local job = medic and medic.PlayerData and medic.PlayerData.job
  if not job or not Config.Jobs[job.name] or (Config.RequireDuty and not job.onduty) or not patient then return nil end
  local a, b = GetPlayerPed(src), GetPlayerPed(target)
  if not a or not b or a == 0 or b == 0 or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then return nil end
  if #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.Distance then return nil end
  return medic, patient
end
local sequence = 0
lib.callback.register('ptech_mediora_billing:draft', function(src, target, services)
  local medic, patient = permitted(src, target)
  if not medic then return { ok = false, message = '診療対象・権限・距離を確認してください' } end
  if type(services) ~= 'table' or #services == 0 or #services > 12 then return { ok = false, message = '請求項目が不正です' } end
  local total, lines = 0, {}
  for _, code in ipairs(services) do
    if type(code) ~= 'string' or not Config.Price[code] then return { ok = false, message = '項目が不正です' } end
    total = total + Config.Price[code]
    lines[#lines+1] = { code = code, price = Config.Price[code] }
  end
  sequence = sequence + 1
  local id = ('MED-%d-%d-%d'):format(os.time(), src, sequence)
  local success, inserted = pcall(MySQL.insert.await, 'INSERT INTO ptech_mediora_billing (id, issuer, patient, items, total, status) VALUES (?, ?, ?, ?, ?, ?)', {
    id, medic.PlayerData.citizenid, patient.PlayerData.citizenid, json.encode(lines), total, 'draft'
  })
  if not success or not inserted then
    print(('[Mediora Billing] draft insert failed: %s'):format(tostring(inserted)))
    return { ok = false, message = '保存できませんでした' }
  end
  return { ok = true, id = id, total = total, status = 'draft' }
end)
