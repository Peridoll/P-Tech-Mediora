exports.ox_target:addSphereZone({
  coords = Config.Location, radius = 1.5,
  options = {{ name = 'ptech_mediora_pharmacy:workbench', label = '医薬品を調薬', icon = 'fa-solid fa-pills', distance = Config.Distance,
    groups = Config.Jobs, onSelect = function()
      local options = {}
      for key, recipe in pairs(Config.Recipes) do
        local id = key
        options[#options+1] = { title = recipe.label, description = '必要な素材を消費して製造',
          onSelect = function()
            local r = lib.callback.await('ptech_mediora_pharmacy:craft', false, id)
            lib.notify({ title = 'Mediora Pharmacy', description = r and r.message or '通信エラー', type = r and r.ok and 'success' or 'error' })
          end }
      end
      lib.registerContext({ id = 'ptech_mediora_pharmacy:menu', title = 'Mediora Pharmacy', options = options })
      lib.showContext('ptech_mediora_pharmacy:menu')
    end }}
})
