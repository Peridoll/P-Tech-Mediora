-- Only server-owned bag slots are resolved. No client-provided container IDs are accepted.
MedicalInventory = {}
local I=MedicalInventory
local busy={}
local function copy(value)
    if type(value)~='table'then return value end
    local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function validCount(value)return type(value)=='number'and value==value and value>=0 and value<math.huge and value%1==0 end
local function citizen(src)
    local player=exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid
end
local function bagSlot(src,slot,id)
    local item=exports.ox_inventory:GetSlot(src,slot)
    return item and item.name=='pmediora_medicalbag'and item.count==1
        and type(item.metadata)=='table'and item.metadata.container
        and tostring(item.metadata.container)==tostring(id)and item or nil
end
local function sources(src)
    local inventory=exports.ox_inventory
    local items=inventory:GetInventoryItems(src)
    if type(items)~='table'then error('inventory_unavailable')end
    local result={{id=src,items=items}};local seen={[tostring(src)]=true}
    local bags={}
    for key,item in pairs(items)do
        if type(item)=='table'and item.name=='pmediora_medicalbag'and item.count==1 and type(item.metadata)=='table'and item.metadata.container then
            local slot=tonumber(item.slot or key)
            if slot then bags[#bags+1]={slot=slot,id=item.metadata.container}end
        end
    end
    table.sort(bags,function(a,b)return a.slot<b.slot end)
    for _,bag in ipairs(bags)do
            local slot,id=bag.slot,bag.id
            if not seen[tostring(id)]then
                local container=inventory:GetContainerFromSlot(src,slot)
                -- Loading a stored bag may yield, so recheck possession afterward.
                if container and container.type=='container'and tostring(container.id)==tostring(id)and bagSlot(src,slot,id)then
                    local contents=inventory:GetInventoryItems(container.id)
                    if type(contents)~='table'then error('bag_unavailable')end
                    seen[tostring(id)]=true
                    result[#result+1]={id=container.id,items=contents,bagSlot=slot}
                end
            end
    end
    return result
end
local function totals(src,onlyBags)
    local counts={}
    local id=citizen(src);if not id then error('character_unavailable')end
    local inventories=sources(src)
    if citizen(src)~=id then error('character_changed')end
    for _,inventory in ipairs(inventories)do
        if not inventory.bagSlot then
            inventory.items=exports.ox_inventory:GetInventoryItems(src)
            if type(inventory.items)~='table'then error('inventory_unavailable')end
        end
        if (not inventory.bagSlot or bagSlot(src,inventory.bagSlot,inventory.id))and (not onlyBags or inventory.bagSlot)then
            for _,item in pairs(inventory.items)do
                if type(item)=='table'and type(item.name)=='string'and validCount(item.count)then
                    counts[item.name]=(counts[item.name]or 0)+item.count
                end
            end
        end
    end
    if citizen(src)~=id then error('character_changed')end
    return counts
end
function I.counts(src)
    if GetResourceState('ox_inventory')~='started'then return nil,'inventory_unavailable'end
    local ok,result=pcall(totals,src,false)
    if not ok then return nil,'inventory_unavailable'end
    return result
end
function I.count(src,name)local counts=I.counts(src);return counts and counts[name]or 0 end

local function syncBagWeight(src,entry)
    if not entry.bagSlot then return end
    local item=bagSlot(src,entry.bagSlot,entry.id)
    if not item then return end
    local container=exports.ox_inventory:GetContainerFromSlot(src,entry.bagSlot)
    if not container or tostring(container.id)~=tostring(entry.id)then return end
    local metadata=copy(item.metadata)
    metadata.weight=container.weight or 0
    exports.ox_inventory:SetMetadata(src,entry.bagSlot,metadata)
end
function I.refund(receipt)
    if type(receipt)~='table'or receipt.citizenId~=citizen(receipt.source)then return false end
    local allReturned=true
    for _,entry in ipairs(receipt.entries)do
        if not entry.returned then
            local inv=entry.id
            if entry.bagSlot and not bagSlot(receipt.source,entry.bagSlot,entry.id)then inv=receipt.source end
            local ok,added=pcall(function()
                return exports.ox_inventory:AddItem(inv,entry.name,entry.count,copy(entry.metadata),inv==entry.id and entry.slot or nil)
            end)
            if not ok or not added then
                ok,added=pcall(function()return exports.ox_inventory:AddItem(receipt.source,entry.name,entry.count,copy(entry.metadata))end)
            end
            if ok and added then entry.returned=true else
                allReturned=false
                print(('[Medical inventory] refund failed source=%s item=%s count=%d'):format(receipt.source,entry.name,entry.count))
            end
        end
        pcall(syncBagWeight,receipt.source,entry)
    end
    return allReturned
end
function I.remove(src,name,count)
    if busy[src]or type(name)~='string'or not validCount(count)or count<=0 then return false end
    local id=citizen(src);if not id then return false end
    busy[src]=true
    local receipt={source=src,citizenId=id,entries={}}
    local ok=pcall(function()
        local plan={};local remaining=count
        for _,inventory in ipairs(sources(src))do
            local slots={}
            for key,item in pairs(inventory.items)do
                if type(item)=='table'and item.name==name and validCount(item.count)and item.count>0 then
                    slots[#slots+1]={slot=tonumber(item.slot or key),item=item}
                end
            end
            table.sort(slots,function(a,b)return a.slot<b.slot end)
            for _,entry in ipairs(slots)do
                local amount=math.min(remaining,entry.item.count)
                if amount>0 then
                    plan[#plan+1]={id=inventory.id,bagSlot=inventory.bagSlot,slot=entry.slot,name=name,count=amount,metadata=copy(entry.item.metadata or {})}
                    remaining=remaining-amount
                end
            end
        end
        if remaining>0 then error('not_enough_items')end
        for _,entry in ipairs(plan)do
            if citizen(src)~=id or (entry.bagSlot and not bagSlot(src,entry.bagSlot,entry.id))then error('ownership_changed')end
            local current=exports.ox_inventory:GetSlot(entry.id,entry.slot)
            if not current or current.name~=name or current.count<entry.count then error('slot_changed')end
            if not exports.ox_inventory:RemoveItem(entry.id,name,entry.count,entry.metadata,entry.slot,false,true)then error('remove_failed')end
            receipt.entries[#receipt.entries+1]=entry
        end
        for _,entry in ipairs(receipt.entries)do syncBagWeight(src,entry)end
    end)
    if not ok then I.refund(receipt)end
    busy[src]=nil
    if not ok then return false end
    return true,receipt
end

lib.callback.register('ptech_mediora_medical:bagToolCounts',function(src)
    local id=citizen(src)
    if not id then return {error='キャラクター情報を取得できません'}end
    local ok,counts=pcall(totals,src,true)
    return {citizenId=id,counts=ok and counts or {}}
end)
AddEventHandler('playerDropped',function()busy[source]=nil end)
