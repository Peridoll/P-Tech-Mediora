RegisterCommand(Config.Command, function()
 local slots = exports.ox_inventory:Search('slots', Config.ReceiptItem)
 local options = {}
 for _, item in pairs(slots or {}) do
  local slot = item.slot
  options[#options+1] = { title = ('領収書（スロット %s）'):format(slot), onSelect = function()
   local r = lib.callback.await('ptech_mediora_settlement:submit', false, slot)
   lib.notify({ description = r and r.message or '通信エラー', type = r and r.ok and 'success' or 'error' })
  end }
 end
 if #options == 0 then return lib.notify({ description = '領収書がありません', type = 'error' }) end
 lib.registerContext({ id = 'ptech_mediora_settlement:menu', title = '精算申請', options = options })
 lib.showContext('ptech_mediora_settlement:menu')
end)
