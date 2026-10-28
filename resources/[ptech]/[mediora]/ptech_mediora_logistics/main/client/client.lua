local function showHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

local function findNearest(points, coords, maxDistance)
    local nearest, nearestDistance
    for _, point in ipairs(points) do
        local distance = #(coords - point.coords)
        if distance <= maxDistance and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = point, distance
        end
    end
    return nearest, nearestDistance
end

local function requestDelivery(hospital)
    local maximum = lib.callback.await(
        'ptech_mediora_logistics:server:getDeliverableCount', false, hospital.id
    ) or 0
    if maximum < 1 then
        notify(Config.Text.noDestinationBoxes, 'error')
        return
    end

    local input = lib.inputDialog(hospital.label, {
        {
            type = 'number',
            label = Config.Text.deliveryCountLabel,
            description = Config.Text.deliveryCountDescription,
            default = maximum,
            min = 1,
            max = maximum,
            step = 1,
            required = true,
        },
    })

    if input and input[1] then
        TriggerServerEvent('ptech_mediora_logistics:server:deliver', hospital.id, input[1])
    end
end

local function requestTrade(hospital, mode)
    local catalog = lib.callback.await(
        'ptech_mediora_logistics:server:getTradeCatalog', false, hospital.id, mode
    ) or {}
    if #catalog == 0 then
        notify(mode == 'buy' and Config.Text.noItemsForSale or Config.Text.noItemsToSell, 'error')
        return
    end

    local options = {}
    for _, item in ipairs(catalog) do
        local suffix = mode == 'buy'
            and ('$%s'):format(item.price)
            or ('$%s / 所持 %s'):format(item.price, item.count)
        options[#options + 1] = {
            label = ('%s (%s)'):format(item.label, suffix),
            value = item.id,
        }
    end

    local selection = lib.inputDialog(mode == 'buy' and Config.Text.menuBuy or Config.Text.menuSell, {
        {
            type = 'select',
            label = '医療道具',
            options = options,
            required = true,
        },
    })
    if not selection or not selection[1] then return end

    local selected
    for _, item in ipairs(catalog) do
        if item.id == selection[1] then selected = item break end
    end
    if not selected then return end

    local maximum = mode == 'buy' and Config.Economy.maxTransactionItems
        or math.min(selected.count, Config.Economy.maxTransactionItems)
    local amountInput = lib.inputDialog(selected.label, {
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
    })
    if amountInput and amountInput[1] then
        TriggerServerEvent(
            'ptech_mediora_logistics:server:tradeItem',
            hospital.id,
            mode,
            selected.id,
            amountInput[1]
        )
    end
end

local function requestDailySpecial(hospital)
    local recipe = lib.callback.await(
        'ptech_mediora_logistics:server:getDailySpecial', false, hospital.id
    )
    if not recipe then
        notify(Config.Text.specialUnavailable, 'error')
        return
    end

    local ingredientLines = {}
    for itemId, count in pairs(recipe.ingredients) do
        local item = Config.Items[itemId]
        ingredientLines[#ingredientLines + 1] = ('%s × %s'):format(item and item.label or itemId, count)
    end
    table.sort(ingredientLines)

    local result = lib.alertDialog({
        header = recipe.label,
        content = ('本日のレシピ (%s)\n%s\n納品先: %s'):format(
            recipe.date,
            table.concat(ingredientLines, '\n'),
            recipe.targetLabel
        ),
        centered = true,
        cancel = true,
    })

    if result == 'confirm' then
        TriggerServerEvent('ptech_mediora_logistics:server:craftDailySpecial', hospital.id)
    end
end

local function requestCraftItem(hospital)
    local catalog = lib.callback.await(
        'ptech_mediora_logistics:server:getCraftingCatalog', false, hospital.id
    ) or {}
    if #catalog == 0 then
        notify(Config.Text.missingRecipeItems, 'error')
        return
    end

    local options = {}
    for _, recipe in ipairs(catalog) do
        local ingredients = {}
        for itemId, count in pairs(recipe.ingredients) do
            local item = Config.Items[itemId]
            ingredients[#ingredients + 1] = ('%s × %s'):format(item and item.label or itemId, count)
        end
        table.sort(ingredients)
        options[#options + 1] = {
            label = ('%s (最大 %s個) — %s'):format(
                recipe.label,
                recipe.maxCount,
                table.concat(ingredients, ', ')
            ),
            value = recipe.id,
        }
    end

    local selection = lib.inputDialog(Config.Text.menuCraftTools, {
        { type = 'select', label = '作成する道具', options = options, required = true },
    })
    if not selection or not selection[1] then return end

    local selected
    for _, recipe in ipairs(catalog) do
        if recipe.id == selection[1] then selected = recipe break end
    end
    if not selected then return end

    local amountInput = lib.inputDialog(selected.label, {
        {
            type = 'number',
            label = '作成個数',
            default = 1,
            min = 1,
            max = selected.maxCount,
            step = 1,
            required = true,
        },
    })
    if amountInput and amountInput[1] then
        TriggerServerEvent('ptech_mediora_logistics:server:craftItem', hospital.id, selected.id, amountInput[1])
    end
end

local function openHospitalMenu(hospital)
    local id = ('mediora_hospital_%s'):format(hospital.id)
    lib.registerContext({
        id = id,
        title = Config.Text.hospitalMenu,
        options = {
            {
                title = Config.Text.menuDeliver,
                description = 'この病院が納品先の段ボールを精算します',
                icon = 'truck-medical',
                onSelect = function() requestDelivery(hospital) end,
            },
            {
                title = Config.Text.menuSell,
                description = '所持している医療道具を売却します',
                icon = 'hand-holding-dollar',
                onSelect = function() requestTrade(hospital, 'sell') end,
            },
            {
                title = Config.Text.menuBuy,
                description = '病院価格で医療道具を購入します',
                icon = 'cart-shopping',
                onSelect = function() requestTrade(hospital, 'buy') end,
            },
            {
                title = Config.Text.menuCraftTools,
                description = 'レシピに応じて医療道具を作成します',
                icon = 'screwdriver-wrench',
                onSelect = function() requestCraftItem(hospital) end,
            },
            {
                title = Config.Text.menuCraftSpecial,
                description = '日替わりレシピで特注段ボールを作成します',
                icon = 'box',
                onSelect = function() requestDailySpecial(hospital) end,
            },
        },
    })
    lib.showContext(id)
end

CreateThread(function()
    while true do
        local waitTime = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        local point, pointDistance = findNearest(Config.CollectionPoints, playerCoords, Config.Procurement.markerDistance)

        if point then
            waitTime = 0
            DrawMarker(
                Config.Procurement.markerType,
                point.coords.x, point.coords.y, point.coords.z - 0.9,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                Config.Procurement.markerScale.x, Config.Procurement.markerScale.y, Config.Procurement.markerScale.z,
                35, 145, 210, 150, false, true, 2, false, nil, nil, false
            )

            if pointDistance <= Config.Procurement.interactDistance then
                showHelp(Config.Text.collect)
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('ptech_mediora_logistics:server:collect', point.id)
                    Wait(700)
                end
            end
        end

        local hospital, hospitalDistance = findNearest(Config.Hospitals, playerCoords, Config.Procurement.markerDistance)
        if hospital then
            waitTime = 0
            DrawMarker(
                Config.Procurement.markerType,
                hospital.coords.x, hospital.coords.y, hospital.coords.z - 0.9,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                Config.Procurement.markerScale.x, Config.Procurement.markerScale.y, Config.Procurement.markerScale.z,
                70, 190, 120, 150, false, true, 2, false, nil, nil, false
            )

            if hospitalDistance <= Config.Procurement.interactDistance then
                showHelp(Config.Text.hospitalMenu .. ' [E]')
                if IsControlJustReleased(0, 38) then
                    openHospitalMenu(hospital)
                    Wait(700)
                end
            end
        end

        Wait(waitTime)
    end
end)

RegisterNetEvent('ptech_mediora_logistics:client:notify', function(message)
    notify(message)
end)
