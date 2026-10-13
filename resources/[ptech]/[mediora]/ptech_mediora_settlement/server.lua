local function authorized(src)
 local p = exports.qbx_core:GetPlayer(src)
 local job = p and p.PlayerData and p.PlayerData.job
 if not job or not Config.Jobs[job.name] or (Config.RequireDuty and not job.onduty) then return nil end
 return p.PlayerData.citizenid
end
lib.callback.register('ptech_mediora_settlement:submit', function(src, slot)
 local citizenid = authorized(src)
 if not citizenid or type(slot) ~= 'number' or slot < 1 or slot % 1 ~= 0 then return { ok = false, message = '権限またはスロットが不正です' } end
 local item = exports.ox_inventory:GetSlot(src, slot)
 if not item or item.name ~= Config.ReceiptItem then return { ok = false, message = '領収書がありません' } end
 local meta = item.metadata or {}
 -- The legacy schema is unknown; unverified receipts are never redeemed.
 local order = meta.orderId or meta.id
 local issued = meta.issuedAt or meta.date
 if not order or not issued then return { ok = false, message = 'この領収書の形式は未対応です' } end
 local key = ('%s:%s:%s'):format(citizenid, tostring(order), tostring(issued))
 local id = MySQL.insert.await('INSERT IGNORE INTO ptech_mediora_settlement (receipt_key, citizenid, item_name, status) VALUES (?, ?, ?, ?)', {key, citizenid, item.name, 'review'})
 if not id or id == 0 then return { ok = false, message = '受付済み、または保存失敗です' } end
 return { ok = true, message = '審査受付しました。支払いはまだ発生しません' }
end)
