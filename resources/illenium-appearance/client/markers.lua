-- NOVILL: 服屋・床屋・整形外科・更衣室などの判定がある場所の足元に円のマーカーを表示する
-- config.lua に設定が無くても動くように既定値を用意
local defaults = {
    Enable = true,
    Type = 25,
    UseZoneSize = true,
    Size = 2.0,
    Height = 1.0,
    HeightOffset = 0.03,
    Rotate = false,
    DrawDistance = 20.0,
    Color = { r = 255, g = 255, b = 255, a = 150 }
}
Config.ZoneMarker = Config.ZoneMarker or {}
for k, v in pairs(defaults) do
    if Config.ZoneMarker[k] == nil then
        Config.ZoneMarker[k] = v
    end
end

if not Config.ZoneMarker.Enable then
    print("^3[illenium-appearance] 円マーカーは無効です（Config.ZoneMarker.Enable = false）^0")
    return
end

local client = client
local markers = {}
local nearby = {}

local function sameJob(entry)
    if entry.job then
        return client.job and client.job.name == entry.job
    elseif entry.gang then
        return client.gang and client.gang.name == entry.gang
    end
    return true
end

local function getGroundZ(coords)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    if found then
        return groundZ
    end
    return coords.z - 0.98
end

local function getDiameter(entry)
    if Config.ZoneMarker.UseZoneSize and entry.size then
        return math.min(entry.size.x, entry.size.y)
    end
    return Config.ZoneMarker.Size
end

local function addMarker(entry, canSee)
    if not entry.coords then return end
    markers[#markers + 1] = {
        coords = entry.coords,
        diameter = getDiameter(entry),
        canSee = canSee
    }
end

local function setupMarkers()
    markers = {}
    for _, store in pairs(Config.Stores) do
        addMarker(store, function() return sameJob(store) end)
    end
    for _, room in pairs(Config.ClothingRooms) do
        addMarker(room, function() return sameJob(room) and (CheckDuty() or room.gang ~= nil) end)
    end
    for _, room in pairs(Config.PlayerOutfitRooms) do
        addMarker(room, function() return IsPlayerAllowedForOutfitRoom(room) end)
    end
end

CreateThread(function()
    setupMarkers()
    print(("^2[illenium-appearance] 円マーカーを %d か所に設定しました^0"):format(#markers))
    while true do
        local pedCoords = GetEntityCoords(cache.ped)
        local list = {}
        for i = 1, #markers do
            local marker = markers[i]
            local c = marker.coords
            if #(pedCoords - vector3(c.x, c.y, c.z)) < Config.ZoneMarker.DrawDistance and marker.canSee() then
                if not marker.groundZ then
                    marker.groundZ = getGroundZ(c)
                end
                list[#list + 1] = marker
            end
        end
        nearby = list
        Wait(1000)
    end
end)

CreateThread(function()
    local m = Config.ZoneMarker
    while true do
        if #nearby > 0 then
            for i = 1, #nearby do
                local marker = nearby[i]
                local c = marker.coords
                DrawMarker(m.Type, c.x, c.y, marker.groundZ + m.HeightOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    marker.diameter, marker.diameter, m.Height, m.Color.r, m.Color.g, m.Color.b, m.Color.a,
                    false, false, 2, m.Rotate, nil, nil, false)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
