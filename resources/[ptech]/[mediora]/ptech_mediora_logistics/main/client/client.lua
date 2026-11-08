local function isAllowed()
  local player = exports.qbx_core:GetPlayerData()
  local job = player and player.job
  if not job then return false end
  if Config.AllowedJobs and next(Config.AllowedJobs) ~= nil and Config.AllowedJobs[job.name] ~= true then
    return false
  end
  return not Config.RequireOnDuty or job.onduty == true
end

--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 ヘルプ表示関数 】
  引数 >> (text)
    text：表示するヘルプメッセージ

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local logisticsProgress
local collectionProps = {}
local propDisplayDistance = Config.Procurement.propDisplayDistance or 10.0

local function removeCollectionProp(entry)
  if entry.entity then
    DeleteEntity(entry.entity)
    entry.entity = nil
  end
  if entry.requested then
    SetModelAsNoLongerNeeded(entry.model)
    entry.requested = nil
  end
end

CreateThread(function()
  for _, point in ipairs(Config.CollectPoints) do
    local prop = point.prop
    if prop then
      local model = type(prop.model) == 'string' and joaat(prop.model) or prop.model
      if type(model) == 'number' and IsModelInCdimage(model) and IsModelValid(model)
          and not IsModelAPed(model) and not IsModelAVehicle(model) then
        collectionProps[point.id] = {
          model = model,
          coords = point.coords + (prop.offset or vector3(0.0, 0.0, 0.0)),
          pointCoords = point.coords,
          heading = prop.heading or 0.0,
        }
      else
        print(('[mediora logistics] Invalid prop model at %s: %s'):format(point.id, tostring(prop.model)))
      end
    end
  end
  if not next(collectionProps) then return end

  while true do
    local coords = GetEntityCoords(PlayerPedId())
    local allowed = isAllowed()
    for pointId, entry in pairs(collectionProps) do
      if allowed and #(coords - entry.pointCoords) <= propDisplayDistance then
        if not entry.readyAt then
          local remaining = lib.callback.await('ptech_mediora_logistics:server:getCollectionCooldown', false, pointId) or 0
          entry.readyAt = math.max(entry.readyAt or 0, GetGameTimer() + remaining * 1000)
        elseif entry.readyAt > GetGameTimer() then
          removeCollectionProp(entry)
        elseif not entry.entity or not DoesEntityExist(entry.entity) then
          if HasModelLoaded(entry.model) then
            local pos = entry.coords
            local entity = CreateObjectNoOffset(entry.model, pos.x, pos.y, pos.z, false, false, false)
            if entity ~= 0 then
              SetEntityHeading(entity, entry.heading)
              FreezeEntityPosition(entity, true)
              SetEntityCollision(entity, false, false)
              entry.entity = entity
            end
            SetModelAsNoLongerNeeded(entry.model)
            entry.requested = nil
          else
            RequestModel(entry.model)
            entry.requested = true
          end
        end
      else
        removeCollectionProp(entry)
        entry.readyAt = nil
      end
    end
    Wait(250)
  end
end)
local collectionPanelId = 'mediora-logistics-cooldown'
local displayedCooldownMinutes

local function updateCollectionPanel(minutes)
  if minutes == displayedCooldownMinutes then return end
  if minutes then
    local ok, accepted = pcall(function()
      return exports.ptech_mediora_core:setActionPanel({
        id = collectionPanelId,
        title = '物資回収',
        icon = '▦',
        state = 'cooldown',
        text = ('再度物資回収まで、あと%d分'):format(minutes),
      })
    end)
    if not ok or not accepted then return end
  else
    pcall(function() exports.ptech_mediora_core:removeActionPanel(collectionPanelId) end)
  end
  displayedCooldownMinutes = minutes
end

local function hideLogisticsProgress(operation)
  pcall(function() exports.ptech_mediora_core:hideProgress(operation.progressId) end)
end

local function runLogisticsProgress(options)
  if logisticsProgress then return false end
  local ped = PlayerPedId()
  if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return false end
  local templates = Config.ProgressAnimations or {}
  local ok, shown, progressId = pcall(function()
    return exports.ptech_mediora_core:showProgress({
      duration = options.duration,
      style = Config.ProgressBarStyle,
      template = templates[options.progressAnimation or 'logistics'],
      label = options.label or '物資を回収中',
    })
  end)
  if not ok or not shown or not progressId then
    lib.notify({ description = 'Coreのプログレスバーを表示できません。少し待ってから再試行してください。', type = 'error' })
    return false
  end

  local animation = options.anim
  local operation = { ped = ped, animation = animation, progressId = progressId }
  logisticsProgress = operation
  RequestAnimDict(animation.dict)
  local deadline = GetGameTimer() + options.duration
  local finished = false
  while logisticsProgress == operation and PlayerPedId() == ped and not IsEntityDead(ped) and isAllowed() do
    DisableAllControlActions(0)
    EnableControlAction(0, 1, true)
    EnableControlAction(0, 2, true)
    if GetGameTimer() >= deadline then
      finished = true
      break
    end
    if HasAnimDictLoaded(animation.dict) and not operation.playing then
      TaskPlayAnim(ped, animation.dict, animation.clip, 3.0, -3.0, -1, animation.flag or 1, 0.0, false, false, false)
      operation.playing = true
    end
    Wait(0)
  end
  StopAnimTask(ped, animation.dict, animation.clip, 1.0)
  RemoveAnimDict(animation.dict)
  hideLogisticsProgress(operation)
  logisticsProgress = nil
  return finished
end

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  updateCollectionPanel(nil)
  for _, entry in pairs(collectionProps) do removeCollectionProp(entry) end
  if not logisticsProgress then return end
  local operation = logisticsProgress
  logisticsProgress = nil
  StopAnimTask(operation.ped, operation.animation.dict, operation.animation.clip, 1.0)
  RemoveAnimDict(operation.animation.dict)
  hideLogisticsProgress(operation)
end)

local function showHelp(text)
  BeginTextCommandDisplayHelp('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayHelp(0, false, true, -1)
end -- showHelp



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 通知を表示する関数 】

  引数 >> (message, kind)
    message：表示するメッセージ
    kind   ：通知の種類 ( 指定がない場合は、"inform" を設定 )

  _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function notify(message, kind)
  lib.notify(
    {
      description = message,
      type        = kind or 'inform'
    }
  )
end -- notify



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 最も近いポイントを探す関数 】

  引数 >> (points, coords, maxDistance)
    points         ：ポイントのリスト
    coords         ：現在の座標
    maxDistance    ：最大距離

  戻り値 >> (nearest, nearestDistance)
    nearest        ：最も近いポイント
    nearestDistance：最も近いポイントまでの距離

    _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function findNearest(points, coords, maxDistance)

  local nearest;         -- 最も近いポイント
  local nearestDistance; -- 最も近いポイントまでの距離

  for _, point in ipairs(points) do
    local distance = #(coords - point.coords)
    if distance <= maxDistance and (not nearestDistance or distance < nearestDistance) then
      nearest = point
      nearestDistance = distance
    end
  end
  return nearest, nearestDistance
end -- findNearest



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 物資を納品する 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function requestDelivery(hospital)

  -- 最大納品可能数を取得
  local maximum = lib.callback.await('ptech_mediora_logistics:server:getDeliverableCount', false, hospital.id) or 0

  -- 最大納品可能数が1未満の場合は処理を中断
  if maximum < 1 then
    notify(Config.Text.noDestinationBoxes, 'error')
    return
  end

  -- 納品数を入力
  local input = lib.inputDialog(
    hospital.label,
    {
      {
        type        = 'number',
        label       = Config.Text.deliveryCountLabel,
        description = Config.Text.deliveryCountDescription,
        default     = maximum,
        min         = 1,
        max         = maximum,
        step        = 1,
        required    = true,
      },
    }
  )

  -- 入力がある場合はサーバーに納品リクエストを送信
  if input and input[1] then
    TriggerServerEvent('ptech_mediora_logistics:server:deliver', hospital.id, input[1])
  end

end -- requestDelivery



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 医療道具を売買する 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function requestTrade(hospital, mode)

  -- トレードカタログを取得
  local catalog = lib.callback.await('ptech_mediora_logistics:server:getTradeCatalog', false, hospital.id, mode) or {}

  -- カタログが空の場合はエラー通知して終了
  if (#catalog == 0) then
    notify(mode == 'buy' and Config.Text.noItemsForSale or Config.Text.noItemsToSell, 'error')
    return
  end

  -- トレードオプションを作成
  local options = {}

  -- カタログからトレードオプションを作成
  for _, item in ipairs(catalog) do

    -- トレードオプションのサフィックスを作成（購入時は価格、販売時は価格と所持数）
    local suffix = mode == 'buy' and ('$%s'):format(item.price) or ('$%s / 所持 %s'):format(item.price, item.count)

    -- トレードオプションを追加
    options[#options + 1] = {
      label = ('%s (%s)'):format(item.label, suffix),
      value = item.key or item.id,
    }

  end -- for catalog

  -- トレードオプションを選択
  local selection = lib.inputDialog(
    mode == 'buy' and Config.Text.menuBuy or Config.Text.menuSell,
    {
      {
          type = 'select',
          label = '医療道具',
          options = options,
          required = true,
      },
    }
  )

  -- 選択がない場合は処理を終了
  if not selection or not selection[1] then return end

  -- 選択されたアイテムを取得
  local selected

  -- 選択されたアイテムがカタログに存在しない場合は処理を終了
  for _, item in ipairs(catalog) do
    if (item.key or item.id) == selection[1] then
      selected = item
      break
    end
  end

  -- 選択されたアイテムが存在しない場合は処理を終了
  if not selected then return end

  -- 購入可能な最大数を計算
  local maximum = mode == 'buy' and Config.Economy.maxTransactionItems or math.min(selected.count, Config.Economy.maxTransactionItems)

  -- 個数入力ダイアログを表示
  local amountInput = lib.inputDialog(
    selected.label,
    {
      {
        type = 'number',
        label = '個数',
        description = ('$%s / 個'):format(selected.price),
        default = 1,
        min = 1,
        max = maximum,
        step = 1,
        required = true,
      },
    }
  )

  -- 入力がある場合はサーバーにトレードリクエストを送信
  if ( amountInput and amountInput[1] ) then
    TriggerServerEvent(
        'ptech_mediora_logistics:server:tradeItem',
        hospital.id,
        mode,
        selected.id,
        amountInput[1],
        selected.grade
    )
  end

end -- requestTrade



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【  】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function requestDailySpecial(hospital)

  -- サーバーから本日の特別レシピを取得
  local recipe = lib.callback.await(
    'ptech_mediora_logistics:server:getDailySpecial', false, hospital.id
  )

  -- 特別レシピが存在しない場合は通知して終了
  if not recipe then
    notify(Config.Text.specialUnavailable, 'error')
    return
  end

  -- 材料リストを作成
  local ingredientLines = {}

  -- 材料リストを作成
  for itemId, count in pairs(recipe.ingredients) do
    local item = Config.Items[itemId]
    ingredientLines[#ingredientLines + 1] = ('%s × %s'):format(item and item.label or itemId, count)
  end
  table.sort(ingredientLines)

  -- 特別レシピの確認ダイアログを表示
  local result = lib.alertDialog({
    header = recipe.label,
    content = ('本日のレシピ (%s)\n%s\n納品先: %s'):format(
      recipe.date,
      table.concat(ingredientLines, '\n'),
      recipe.targetLabel
    ),
    centered = true,
    cancel   = true,
  })

  -- ユーザーが確認した場合はサーバーにクラフトリクエストを送信
  if result == 'confirm' then
    TriggerServerEvent('ptech_mediora_logistics:server:craftDailySpecial', hospital.id)
  end

end -- requestDailySpecial



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 医療道具を作成する 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function requestCraftItem(hospital)

  -- 医療道具作成用のカタログをサーバーから取得
  local catalog = lib.callback.await('ptech_mediora_logistics:server:getCraftingCatalog', false, hospital.id) or {}

  -- カタログが空の場合はエラーを通知して終了
  if ( #catalog == 0 ) then -- カタログの配列件数が0の場合は作成できるアイテムがない
    notify(Config.Text.noCatalogItems, 'error')
    return
  end

  local options = {} -- 選択肢用の配列

  -- カタログの各レシピを選択肢として整形
  for _, recipe in ipairs(catalog) do

    local ingredients = {} -- 材料のリスト

    -- 材料のリストを作成
    for itemId, count in pairs(recipe.ingredients) do
      local item = Config.Items[itemId]
      ingredients[#ingredients + 1] = ('%s × %s'):format(item and item.label or itemId, count)
    end
    table.sort(ingredients)

    -- 選択肢用のラベルを作成
    options[#options + 1] = {
      label = ('%s (最大 %s個) — %s'):format(
        recipe.label,
        recipe.maxCount,
        table.concat(ingredients, ', ')
      ),
      value = recipe.id,
    }
  end

  -- 選択肢を表示してユーザーに選ばせる
  local selection = lib.inputDialog(
    Config.Text.menuCraftTools,
    {
      {
        type     = 'select',
        label    = '作成する道具',
        options  = options,
        required = true
      },
    }
  )

  -- 選択されたレシピを取得
  if ( (not selection) or (not selection[1]) ) then return end

  -- 選択されたレシピを取得
  local selected
  for _, recipe in ipairs(catalog) do
    if recipe.id == selection[1] then
      selected = recipe
      break
    end -- if recipe.id == selection[1] then
  end -- for _, recipe in ipairs(catalog) do
  if not selected then return end

  -- 作成する個数をユーザーに入力させる
  local amountInput = lib.inputDialog(
    selected.label,
    {
      {
        type     = 'number',
        label    = '作成個数',
        default  = 1,
        min      = 1,
        max      = selected.maxCount,
        step     = 1,
        required = true,
      },
    }
  )

  -- 入力された作成個数がある場合はサーバーに作成リクエストを送信
  if amountInput and amountInput[1] then
    TriggerServerEvent('ptech_mediora_logistics:server:craftItem', hospital.id, selected.id, amountInput[1])
  end

end -- requestCraftItem



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 病院メニューの設定 】

  hospital: コンフィグから取得した病院情報

  医療道具の購入・売却はピルボックス限定。納品とクラフトは全病院で利用できる。

  | 物資を納品する
  |   宛先がこの病院の物資を納品する
  |
  | 特注物資を作成する
  |   日替わりレシピで特注物資を作成する
  |
  | 医療道具を購入する
  |   病院価格で医療道具を購入する
  |
  | 医療道具を売却する
  |   所持している医療道具を売却する
  |
  | 医療道具を作成する
  |   レシピに応じて医療道具を作成する

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
local function openOrderPickup(hospital)
  local result = lib.callback.await('ptech_mediora_logistics:orders:pickupList', false)
  if not result or not result.ok then
    notify(result and result.error or '注文を確認できませんでした。', 'error')
    return
  end
  local options = {}
  for _, order in ipairs(result.orders) do
    if order.status == 'waiting' or order.status == 'handed_over' then
      local labels = {}
      for _, item in ipairs(order.items) do labels[#labels + 1] = ('%s × %d'):format(item.label, item.count) end
      options[#options + 1] = {
        title = ('注文 #%d'):format(order.id),
        description = table.concat(labels, '、'),
        icon = 'box-open',
        onSelect = function()
          local pickup = lib.callback.await('ptech_mediora_logistics:orders:pickup', false, order.id)
          if not pickup or not pickup.ok then
            notify(pickup and pickup.error or '受け取りを開始できませんでした。', 'error')
            return
          end
          exports.ox_inventory:openInventory('stash', { id = pickup.stash, owner = pickup.owner })
        end,
      }
    end
  end
  if #options == 0 then notify('受け取れる注文はありません。'); return end
  lib.registerContext({ id = 'mediora-order-pickup', title = hospital.label .. ' · 注文受取', options = options })
  lib.showContext('mediora-order-pickup')
end


local function openHospitalMenu(hospital)

  -- 病院メニューのコンテキストIDを生成
  local id = ('mediora_hospital_%s'):format(hospital.id)

  -- 本日の納品倍率を取得。倍率は全員共通で、サーバーが計算する。
  local dailyMultiplier = lib.callback.await('ptech_mediora_logistics:server:getHospitalMultiplier', false, hospital.id)
  local deliverDescription = Config.Text.menuDeliverDesc
  if dailyMultiplier then
    deliverDescription = ('%s / 本日の納品倍率 ×%.2f'):format(deliverDescription, dailyMultiplier)
  end

  -- すべての病院で納品できる。納品以外の機能はフルサービス拠点だけに表示する。
  local options = {
    {
      title       = Config.Text.menuDeliver,
      description = deliverDescription,
      icon        = 'truck-medical',
      onSelect    = function() requestDelivery(hospital) end,
    },
  }

  if hospital.id == (Config.Economy.fullServiceHospitalId or Config.Economy.tradeHospitalId) then
    options[#options + 1] = {
      title       = Config.Text.menuCraftSpBox,
      description = Config.Text.menuCraftSpBoxDesc,
      icon        = 'box',
      onSelect    = function() requestDailySpecial(hospital) end,
    }
    options[#options + 1] = {
      title       = Config.Text.menuCraftTools,
      description = Config.Text.menuCraftToolsDesc,
      icon        = 'screwdriver-wrench',
      onSelect    = function() requestCraftItem(hospital) end,
    }
  end

  if hospital.id == 'pillbox' then
    options[#options + 1] = {
      title = '注文品を受け取る',
      description = 'タブレットで購入した物資の受け取り',
      icon = 'box-open',
      onSelect = function() openOrderPickup(hospital) end,
    }
  end

  if hospital.id == Config.Economy.tradeHospitalId then
    options[#options + 1] = {
      title       = Config.Text.menuBuy,
      description = Config.Text.menuBuyDesc,
      icon        = 'cart-shopping',
      onSelect    = function() requestTrade(hospital, 'buy') end,
    }
    options[#options + 1] = {
      title       = Config.Text.menuSell,
      description = Config.Text.menuSellDesc,
      icon        = 'hand-holding-dollar',
      onSelect    = function() requestTrade(hospital, 'sell') end,
    }
  end

  -- 病院メニューのコンテキストを登録
  lib.registerContext({
    id      = id,
    title   = Config.Text.hospitalMenu,
    options = options,
  })
  lib.showContext(id) -- 設定した病院のコンテキストメニューを表示
end -- openHospitalMenu



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 操作ポイントの設定 】

  | 収集ポイント
  |   Eキーを押して物資を収集
  |
  | 病院ポイント
  |   Eキーを押して病院メニューを開く

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
CreateThread(
  function() -- 無名関数：ここでのみしか使用しないため名称のいらない関数

    -- 多数の収集地点を毎フレーム総当たりしないため、近傍の探索結果を一定時間キャッシュする。
    local nextScanAt = 0
    local cachedCollectPoint, cachedHospital
    local nearbyCollectionId
    local collectionReadyAt = 0

    while ( true ) do -- メインループ、スレッド内の処理を繰り返す


      --【 変数宣言 】

      -- 変数初期化
      local waitTime             = math.min(Config.Procurement.scanIntervalMs or 750, 250)                              -- デフォルトの待機時間 ( 何もしない時の再探索までの時間 ) を設定

      -- コンフィグ情報の取得
      local table_CollectPoints  = Config.CollectPoints              -- 収集ポイントの場所の情報テーブルを参照
      local table_Hospitals      = Config.Hospitals                  -- 病院の場所の情報テーブルを参照
      local markerDistance       = Config.Procurement.markerDistance -- マーカーの表示距離を取得
      local interactDistance     = Config.Procurement.interactDistance -- Eキー操作が可能な距離

      -- 動的情報取得
      local playerPed            = PlayerPedId()                     -- プレイヤーの Ped (エンティティデータ) を取得
      local playerCoords         = GetEntityCoords( playerPed )      -- プレイヤーの Coords (現在座標) を取得

      -- 探索は一定間隔で実行。近接時のマーカー描画とEキー判定は毎フレーム継続する。
      local now = GetGameTimer()
      local allowed = isAllowed()
      if not allowed then
        cachedCollectPoint, cachedHospital = nil, nil
        nextScanAt = 0
      elseif now >= nextScanAt then
        cachedCollectPoint = findNearest(table_CollectPoints, playerCoords, markerDistance)
        cachedHospital = findNearest(table_Hospitals, playerCoords, markerDistance)
        nextScanAt = now + (Config.Procurement.scanIntervalMs or 750)
      end


      --【 収集ポイント探索 】

      -- 最寄りの収集ポイントを探索
      local collectPoint = cachedCollectPoint
      local pointDistance = collectPoint and #(playerCoords - collectPoint.coords)
      local nearbyId = pointDistance and pointDistance <= interactDistance and collectPoint.id or nil
      if nearbyId ~= nearbyCollectionId then
        nearbyCollectionId = nearbyId
        local remaining = nearbyId
          and lib.callback.await('ptech_mediora_logistics:server:getCollectionCooldown', false, nearbyId) or 0
        collectionReadyAt = GetGameTimer() + remaining * 1000
      end
      local remainingMs = collectionReadyAt - GetGameTimer()
      local onCooldown = nearbyId ~= nil and remainingMs > 0
      updateCollectionPanel(onCooldown and math.ceil(remainingMs / 60000) or nil)

      if ( collectPoint and pointDistance <= markerDistance ) then -- 探索した収集ポイントがまだ描画範囲内にある場合

        waitTime = 0 -- プレイヤーが収集ポイントに近いため、待機時間を短縮

        local prop = collectionProps[collectPoint.id]
        local waitingForProp = prop and prop.readyAt and prop.readyAt <= GetGameTimer()
          and pointDistance <= propDisplayDistance and (not prop.entity or not DoesEntityExist(prop.entity))
        if not prop or (not onCooldown and waitingForProp) then
          DrawMarker( -- 収集ポイントのマーカーを描画
            Config.Procurement.markerType,
            collectPoint.coords.x,
            collectPoint.coords.y,
            collectPoint.coords.z - 0.9,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            Config.Procurement.markerScale.x,
            Config.Procurement.markerScale.y,
            Config.Procurement.markerScale.z,
            35, 145, 210, 150,
            false,
            true,
            2,
            false,
            nil, nil,
            false
          )
        end

        -- プレイヤーが収集ポイントにいるとき、操作方法を表示し、収集イベントをトリガーする
        if nearbyId and not onCooldown then

          showHelp(Config.Text.collect .. ' [E]') -- 回収地点の操作方法を表示

          if IsControlJustReleased(0, 38) then -- プレイヤーが収集ポイントで操作した場合 (38:Eキー)

            local completed = runLogisticsProgress({
              duration = Config.Procurement.collectDurationMs or 5000,
              label = '物資を回収中...',
              position = 'bottom',
              useWhileDead = false,
              disable = { move = true, car = true, combat = true },
              anim = {
                dict = 'amb@prop_human_bum_bin@base',
                clip = 'base',
                flag = 1,
              },
            })

            if completed and isAllowed() then
              local remaining = lib.callback.await('ptech_mediora_logistics:server:collect', false, collectPoint.id) or 0
              collectionReadyAt = GetGameTimer() + remaining * 1000
              if remaining > 0 then
                if prop then
                  prop.readyAt = collectionReadyAt
                  removeCollectionProp(prop)
                end
                updateCollectionPanel(math.ceil(remaining / 60))
              end
            elseif not completed then
              notify('回収を中止しました。', 'inform')
            end
            Wait(700) -- 操作後の待機時間を設定

          end -- if IsControlJustReleased(0, 38) then

        end -- if pointDistance <= interactDistance then

      end -- if ( collectPoint ) then


      --【 病院ポイント探索 】

      -- 最寄りの病院ポイントを探索
      local hospital = cachedHospital
      local hospitalDistance = hospital and #(playerCoords - hospital.coords)

      if ( hospital and hospitalDistance <= markerDistance ) then -- 探索した病院がまだ描画範囲内にある場合

        waitTime = 0 -- プレイヤーが病院ポイントに近いため、待機時間を短縮

        DrawMarker( -- 病院ポイントのマーカーを描画
          Config.Procurement.markerType,
          hospital.coords.x,
          hospital.coords.y,
          hospital.coords.z - 0.9,
          0.0, 0.0, 0.0,
          0.0, 0.0, 0.0,
          Config.Procurement.markerScale.x,
          Config.Procurement.markerScale.y,
          Config.Procurement.markerScale.z,
          70, 190, 120, 150,
          false,
          true,
          2,
          false,
          nil, nil,
          false
        )

        -- プレイヤーが病院ポイントにいるとき、操作方法を表示し、病院メニューを開く
        if hospitalDistance <= interactDistance then -- プレイヤーがEキー操作可能な距離にいる場合

          -- 病院ポイントでの操作方法を表示
          showHelp(Config.Text.openHospitalMenu .. ' [E]') -- 病院ポイントでの操作方法を表示

          if IsControlJustReleased(0, 38) then -- プレイヤーが病院ポイントで操作した場合 (38:Eキー)

            openHospitalMenu(hospital) -- 病院メニューを開く
            Wait(700) -- 操作後の待機時間を設定

          end -- if IsControlJustReleased(0, 38) then

        end -- if hospitalDistance <= interactDistance then

      end -- if ( hospital ) then

      Wait(waitTime) -- ループ待機

    end -- while true do

  end -- function()
) -- CreateThread



--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  【 クライアント通知イベントの登録 】

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]
RegisterNetEvent(
  'ptech_mediora_logistics:client:notify',
  function(message)
    notify(message)
  end -- function(message)
) -- RegisterNetEvent

RegisterNetEvent('ptech_mediora_logistics:client:showBoxMenu', function(slot, destinationLabel, x, y)
  local contextId = ('mediora_box_%s'):format(slot)
  lib.registerContext({
    id = contextId,
    title = Config.Text.boxMenu,
    options = {
      {
        title = Config.Text.boxNavigate,
        description = destinationLabel,
        icon = 'location-dot',
        onSelect = function()
          SetNewWaypoint(x + 0.0, y + 0.0)
          notify(('%sをマップに設定しました。'):format(destinationLabel))
        end,
      },
      {
        title = Config.Text.boxOpen,
        description = destinationLabel,
        icon = 'box-open',
        onSelect = function()
          local completed = runLogisticsProgress({
            duration = Config.Procurement.boxOpenDurationMs,
            label = Config.Text.boxOpening,
            progressAnimation = 'boxOpening',
            position = 'bottom',
            useWhileDead = false,
            disable = { move = true, car = true, combat = true },
            anim = {
              dict = 'anim@amb@business@coc@coc_unpack_cut@',
              clip = 'fullcut_cycle_v1_cokepacker',
              flag = 1,
            },
          })

          if completed then
            TriggerServerEvent('ptech_mediora_logistics:server:openDeliveryBox', slot)
          else
            notify(Config.Text.boxOpenCancelled, 'inform')
          end
        end,
      },
    },
  })
  lib.showContext(contextId)
end)
