function CheckDuty()
    return not Config.OnDutyOnlyClothingRooms or (Config.OnDutyOnlyClothingRooms and client.job.onduty)
end

function IsPlayerAllowedForOutfitRoom(outfitRoom)
    local isAllowed = false
    local count = #outfitRoom.citizenIDs
    for i = 1, count, 1 do
        if Framework.IsPlayerAllowed(outfitRoom.citizenIDs[i]) then
            isAllowed = true
            break
        end
    end
    return isAllowed or not outfitRoom.citizenIDs or count == 0
end

function GetPlayerJobOutfits(job)
    local outfits = {}
    local gender = Framework.GetGender()
    local gradeLevel = job and Framework.GetJobGrade() or Framework.GetGangGrade()
    local jobName = job and client.job.name or client.gang.name

    if Config.BossManagedOutfits then
        local mType = job and "Job" or "Gang"
        local result = lib.callback.await("illenium-appearance:server:getManagementOutfits", false, mType, gender)
        for i = 1, #result, 1 do
            outfits[#outfits + 1] = {
                type = mType,
                model = result[i].model,
                components = result[i].components,
                props = result[i].props,
                disableSave = true,
                name = result[i].name
            }
        end
    elseif Config.Outfits[jobName] and Config.Outfits[jobName][gender] then
        for i = 1, #Config.Outfits[jobName][gender], 1 do
            for _, v in pairs(Config.Outfits[jobName][gender][i].grades) do
                if v == gradeLevel then
                    outfits[#outfits + 1] = Config.Outfits[jobName][gender][i]
                    outfits[#outfits].gender = gender
                    outfits[#outfits].jobName = jobName
                end
            end
        end
    end

    return outfits
end

function OpenOutfitRoom(outfitRoom)
    local isAllowed = IsPlayerAllowedForOutfitRoom(outfitRoom)
    if isAllowed then
        OpenMenu(nil, "outfit")
    end
end

function OpenBarberShop()
    local config = GetDefaultConfig()
    config.headOverlays = true
    OpenShop(config, false, "barber")
end

function OpenTattooShop()
    if not Config.EnableTattooShop then return end -- NOVILL: タトゥーショップ無効
    local config = GetDefaultConfig()
    config.tattoos = true
    OpenShop(config, false, "tattoo")
end

local blendFields = {
    "shapeFirst", "shapeSecond", "shapeThird",
    "skinFirst", "skinSecond", "skinThird",
    "shapeMix", "skinMix", "thirdMix"
}
local prefix = "FACE1-"

local function encodeFaceCode(appearance)
    local bytes = { appearance.model == "mp_f_freemode_01" and 1 or 0 }
    for i, field in ipairs(blendFields) do
        local value = appearance.headBlend[field]
        bytes[#bytes + 1] = i <= 6 and value or math.floor(value * 100 + 0.5)
    end
    for _, field in ipairs(constants.FACE_FEATURES) do
        bytes[#bytes + 1] = math.floor((appearance.faceFeatures[field] + 1) * 10 + 0.5)
    end
    for i, value in ipairs(bytes) do
        bytes[i] = ("%02X"):format(value)
    end
    return prefix .. table.concat(bytes)
end

local function decodeFaceCode(code)
    local payload = code:match("^%s*FACE1%-(%x+)%s*$")
    if not payload or #payload ~= 2 * (1 + #blendFields + #constants.FACE_FEATURES) then return end

    local bytes = {}
    for pair in payload:gmatch("%x%x") do
        bytes[#bytes + 1] = tonumber(pair, 16)
    end
    if bytes[1] > 1 then return end

    local face = {
        model = bytes[1] == 1 and "mp_f_freemode_01" or "mp_m_freemode_01",
        headBlend = {},
        faceFeatures = {}
    }
    for i, field in ipairs(blendFields) do
        local value = bytes[i + 1]
        if value > (i <= 6 and 45 or 100) then return end
        face.headBlend[field] = i <= 6 and value or value / 100
    end
    for i, field in ipairs(constants.FACE_FEATURES) do
        local value = bytes[1 + #blendFields + i]
        if value > 20 then return end
        face.faceFeatures[field] = (value - 10) / 10
    end
    return face
end

local function openSurgeonEditor(face)
    local config = GetDefaultConfig()
    config.headBlend = true
    config.faceFeatures = true
    config.faceCodePreview = face
    OpenShop(config, false, "surgeon")
end

function OpenSurgeonShop()
    openSurgeonEditor()
end

AddEventHandler("illenium-appearance:client:generateFaceCode", function()
    if not client.isPedFreemodeModel(cache.ped) then
        return lib.notify({ type = "error", description = "このキャラモデルは顔コードに対応していません。" })
    end
    local code = encodeFaceCode(client.getPedAppearance(cache.ped))
    lib.inputDialog("顔コードをコピー", {
        { type = "input", label = "顔コード", default = code }
    })
end)

AddEventHandler("illenium-appearance:client:importFaceCode", function()
    local input = lib.inputDialog("顔コードを読み込む", {
        { type = "input", label = "顔コード", required = true, max = 128 }
    })
    if not input then return end
    local face = decodeFaceCode(input[1])
    if not face then
        return lib.notify({ type = "error", description = "顔コードの形式が正しくありません。" })
    end
    if GetEntityModel(cache.ped) ~= joaat(face.model) then
        return lib.notify({ type = "error", description = "この顔コードは同じキャラモデルで使えます。" })
    end
    openSurgeonEditor(face)
end)

function OpenFaceCodeMenu()
    lib.registerContext({
        id = "illenium_appearance_surgeon",
        title = "整形",
        options = {
            { title = "顔コードを発行", event = "illenium-appearance:client:generateFaceCode" },
            { title = "顔コードを読み込む", event = "illenium-appearance:client:importFaceCode" }
        }
    })
    lib.showContext("illenium_appearance_surgeon")
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if Config.BossManagedOutfits then
            Management.RemoveItems()
        end
    end
end)
