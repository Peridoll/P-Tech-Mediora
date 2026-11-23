-- NOVILL: Qbox（qbx_core）対応
if not Framework.Qbox() then return end

local client = client

local PlayerData = exports.qbx_core:GetPlayerData() or {}

local function getRankInputValues(rankList)
    local rankValues = {}
    for k, v in pairs(rankList or {}) do
        rankValues[#rankValues + 1] = {
            label = v.name,
            value = tonumber(k) or k
        }
    end
    table.sort(rankValues, function(a, b)
        return (tonumber(a.value) or 0) < (tonumber(b.value) or 0)
    end)
    return rankValues
end

local function setClientParams()
    client.job = PlayerData.job
    client.gang = PlayerData.gang
    client.citizenid = PlayerData.citizenid
end

setClientParams()

function Framework.GetPlayerGender()
    if PlayerData.charinfo and tonumber(PlayerData.charinfo.gender) == 1 then
        return "Female"
    end
    return "Male"
end

function Framework.UpdatePlayerData()
    PlayerData = exports.qbx_core:GetPlayerData() or {}
    setClientParams()
end

function Framework.HasTracker()
    local data = exports.qbx_core:GetPlayerData()
    return data and data.metadata and data.metadata.tracker
end

function Framework.CheckPlayerMeta()
    local metadata = PlayerData.metadata or {}
    return metadata.isdead or metadata.inlaststand or metadata.ishandcuffed
        or LocalPlayer.state.isDead or IsPedCuffed(cache.ped)
end

function Framework.IsPlayerAllowed(citizenid)
    return citizenid == PlayerData.citizenid
end

function Framework.GetRankInputValues(type)
    if type == "gang" then
        local gang = exports.qbx_core:GetGangs()[client.gang.name]
        return getRankInputValues(gang and gang.grades)
    end
    local job = exports.qbx_core:GetJobs()[client.job.name]
    return getRankInputValues(job and job.grades)
end

function Framework.GetJobGrade()
    return client.job.grade.level
end

function Framework.GetGangGrade()
    return client.gang.grade.level
end

RegisterNetEvent("QBCore:Player:SetPlayerData", function(data)
    PlayerData = data
    setClientParams()
end)

RegisterNetEvent("QBCore:Client:OnJobUpdate", function(JobInfo)
    PlayerData.job = JobInfo
    client.job = JobInfo
    ResetBlips()
end)

RegisterNetEvent("QBCore:Client:OnGangUpdate", function(GangInfo)
    PlayerData.gang = GangInfo
    client.gang = GangInfo
    ResetBlips()
end)

RegisterNetEvent("QBCore:Client:SetDuty", function(duty)
    if PlayerData and PlayerData.job then
        PlayerData.job.onduty = duty
        client.job = PlayerData.job
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Framework.UpdatePlayerData()
    InitAppearance()
end)

-- qbx_core のキャラクター新規作成時に呼ばれる
RegisterNetEvent("qb-clothes:client:CreateFirstCharacter", function()
    Framework.UpdatePlayerData()
    InitializeCharacter(Framework.GetGender(true))
end)

function Framework.CachePed()
    return nil
end

function Framework.RestorePlayerArmour()
    Framework.UpdatePlayerData()
    if PlayerData and PlayerData.metadata then
        Wait(1000)
        SetPedArmour(cache.ped, PlayerData.metadata.armor or 0)
    end
end
