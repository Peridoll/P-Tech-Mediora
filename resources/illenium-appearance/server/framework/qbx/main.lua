-- NOVILL: Qbox（qbx_core）対応
if not Framework.Qbox() then return end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function Framework.GetPlayerID(src)
    local Player = getPlayer(src)
    if Player then
        return Player.PlayerData.citizenid
    end
end

function Framework.HasMoney(src, type, money)
    local Player = getPlayer(src)
    if not Player then return false end
    return (Player.PlayerData.money[type] or 0) >= money
end

function Framework.RemoveMoney(src, type, money)
    local Player = getPlayer(src)
    if not Player then return false end
    return Player.Functions.RemoveMoney(type, money, "illenium-appearance")
end

function Framework.GetJob(src)
    local Player = getPlayer(src)
    return Player and Player.PlayerData.job
end

function Framework.GetGang(src)
    local Player = getPlayer(src)
    return Player and Player.PlayerData.gang
end

function Framework.SaveAppearance(appearance, citizenID)
    Database.PlayerSkins.UpdateActiveField(citizenID, 0)
    Database.PlayerSkins.DeleteByModel(citizenID, appearance.model)
    Database.PlayerSkins.Add(citizenID, appearance.model, json.encode(appearance), 1)
end

function Framework.GetAppearance(citizenID, model)
    local result = Database.PlayerSkins.GetByCitizenID(citizenID, model)
    if result then
        return json.decode(result)
    end
end
