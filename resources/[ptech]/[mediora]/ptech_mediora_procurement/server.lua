local prefix = 'ptech_mediora_procurement:'
local orders, actions, locks, blocked = {}, {}, {}, {}
local sequence = 0
local function eligible(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local d = player.PlayerData
    local j = d.job
    local grade = j and Config.Jobs[j.name]
    if grade == nil or not j.onduty or j.grade.level < grade then return end
    if d.metadata and (d.metadata.isdead or d.metadata.inlaststand) then return end
    if GetPlayerRoutingBucket(source) ~= Config.Bucket then return end
    return player
end
local function near(source, coords)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetEntityHealth(ped) > 0 and #(GetEntityCoords(ped) - coords) <= Config.Radius
end
local function current(source, player)
    local list = orders[source]
    if list and list.citizenid ~= player.PlayerData.citizenid then
        orders[source], actions[source] = nil, nil
        list = nil
    end
    return list
end
local function count(source, item)
    return exports.ox_inventory:GetItemCount(source, item) or 0
end
local function result(source, ok, message)
    local player = eligible(source)
    local list = player and current(source, player)
    local first = list and list.entries[1]
    return { ok = ok, message = message or '',
        mission = first and { id = first.id, supplier = first.supplier, stage = 'pickup' } or false }
end
local function registerStash()
    local s = Config.Stash
    exports.ox_inventory:RegisterStash(s.id, s.label, s.slots, s.weight, false, Config.Jobs, Config.StashCoords)
end
registerStash()
AddEventHandler('onResourceStart', function(r) if r == 'ox_inventory' then registerStash() end end)
local function dashboard(source)
    local player = eligible(source)
    if not player then return result(source, false, '勤務中のEMSのみ利用できます。') end
    local list = current(source, player)
    local r = result(source, true)
    r.orderCount, r.maxOrders = list and #list.entries or 0, Config.MaxOrders
    r.cargoCount, r.receiptCount = count(source, Config.CargoItem), count(source, Config.ReceiptItem)
    r.receiptAmount, r.materialCount = Config.ReceiptAmount, Config.MaterialCount
    r.blocked = blocked[player.PlayerData.citizenid] == true
    r.supplierLabel = r.mission and Config.Suppliers[r.mission.supplier].label or false
    return r
end
lib.callback.register(prefix .. 'dashboard', dashboard)
lib.callback.register(prefix .. 'status', function(source) return result(source, eligible(source) ~= nil) end)
local function safe(source, fn)
    local p = eligible(source)
    if not p then return result(source, false, '勤務中のEMSのみ利用できます。') end
    local cid = p.PlayerData.citizenid
    if locks[source] or blocked[cid] then return result(source, false, '処理中、または管理者の確認が必要です。') end
    locks[source] = true
    local ok, response = pcall(fn, p, cid)
    locks[source] = nil
    if not ok then
        blocked[cid] = true
        print(('[ptech_mediora_procurement] inventory settlement error citizenid=%s: %s'):format(cid, response))
        return result(source, false, '物資処理を停止しました。管理者へ連絡してください。')
    end
    return response
end
lib.callback.register(prefix .. 'start', function(source)
    return safe(source, function(p, cid)
        if not near(source, Config.Hospital) then return result(source, false, '病院で受注してください。') end
        local list = current(source, p) or { citizenid = cid, entries = {} }
        if #list.entries >= Config.MaxOrders then return result(source, false, '同時受注の上限です。') end
        for _, item in ipairs({Config.CargoItem, Config.ReceiptItem, Config.Material}) do
            if not exports.ox_inventory:Items(item) then return result(source, false, '必要なアイテムが未登録です。') end
        end
        sequence = sequence + 1
        list.entries[#list.entries + 1] = { id = sequence, supplier = math.random(#Config.Suppliers) }
        orders[source] = list
        return result(source, true, '仕入れ先で物資を受け取ってください。受取期限はありません。')
    end)
end)
lib.callback.register(prefix .. 'cancel', function(source, id)
    return safe(source, function(p)
        local list = current(source, p)
        if not list then return result(source, false, '受注がありません。') end
        for i, order in ipairs(list.entries) do
            if order.id == id then table.remove(list.entries, i); actions[source] = nil
                return result(source, true, '未受取の受注を中止しました。') end
        end
        return result(source, false, '受注がありません。')
    end)
end)
lib.callback.register(prefix .. 'begin', function(source, kind, id)
    return safe(source, function(p, cid)
        local list = current(source, p)
        local order = list and list.entries[1]
        if kind == 'pickup' then
            if not order or order.id ~= id or not near(source, Config.Suppliers[order.supplier].coords) then
                return result(source, false, '受注した仕入れ先で操作してください。') end
        elseif kind == 'delivery' then
            if not near(source, Config.Hospital) or count(source, Config.CargoItem) < 1 then
                return result(source, false, '物資を持って病院で納品してください。') end
        else return result(source, false, '無効な操作です。') end
        actions[source] = { kind = kind, id = id, citizenid = cid, ready = GetGameTimer() + Config.Duration }
        return result(source, true)
    end)
end)
lib.callback.register(prefix .. 'finish', function(source, kind, id)
    return safe(source, function(p, cid)
        local a = actions[source]
        if not a or a.kind ~= kind or a.id ~= id or a.citizenid ~= cid or GetGameTimer() < a.ready then
            return result(source, false, '作業が完了していません。') end
        actions[source] = nil -- 一回限り。失敗時は作業から再試行
        if kind == 'pickup' then
            local list = current(source, p)
            local order = list and list.entries[1]
            if not order or order.id ~= id or not near(source, Config.Suppliers[order.supplier].coords) then
                return result(source, false, '有効な受注がありません。') end
            if not exports.ox_inventory:CanCarryItem(source, Config.CargoItem, 1) then
                return result(source, false, '所持品に空きを作ってください。') end
            if not exports.ox_inventory:AddItem(source, Config.CargoItem, 1) then
                return result(source, false, '物資の受取に失敗しました。') end
            table.remove(list.entries, 1)
            return result(source, true, '物資を受け取りました。後から病院へ納品できます。')
        end
        if not near(source, Config.Hospital) then return result(source, false, '病院で納品してください。') end
        local inv = exports.ox_inventory:GetInventory(Config.Stash.id)
        if not inv or not exports.ox_inventory:CanCarryItem(inv.id, Config.Material, Config.MaterialCount) then
            return result(source, false, '病院倉庫に空きを作ってください。') end
        if not exports.ox_inventory:RemoveItem(source, Config.CargoItem, 1) then
            return result(source, false, '納品する物資がありません。') end
        if not exports.ox_inventory:AddItem(inv.id, Config.Material, Config.MaterialCount) then
            assert(exports.ox_inventory:AddItem(source, Config.CargoItem, 1), 'Cargo rollback failed')
            return result(source, false, '素材納品に失敗しました。物資を返却しました。')
        end
        -- 金額はサーバー設定から発行。受注者による所有制限は設けない。
        local receipt = { amount = Config.ReceiptAmount, category = 'medical_supply',
            description = ('医療物資納品 / 精算予定額 $%s'):format(Config.ReceiptAmount) }
        if not exports.ox_inventory:AddItem(source, Config.ReceiptItem, 1, receipt) then
            assert(exports.ox_inventory:RemoveItem(inv.id, Config.Material, Config.MaterialCount), 'Material rollback failed')
            assert(exports.ox_inventory:AddItem(source, Config.CargoItem, 1), 'Cargo rollback failed')
            return result(source, false, '領収書を渡せませんでした。物資を返却しました。所持品に空きを作ってください。')
        end
        return result(source, true, '納品完了。領収書を発行しました。このリソースから支払いは行いません。')
    end)
end)
AddEventHandler('playerDropped', function() orders[source], actions[source] = nil, nil end)
RegisterNetEvent('ptech_mediora_procurement:unload', function()
    local src = source
    orders[src], actions[src] = nil, nil
end)
-- 支払い・経験値処理はarchive/server.luaのコメント内に隔離。精算は未実装。
