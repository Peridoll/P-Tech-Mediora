-- 中央の透過領域へ実際の患者を映す。Pedの複製・移動・姿勢変更は行わない。
ManagerPatientView = {}
local current

local function status(active, message)
    SendNUIMessage({ action = 'patientView:status', data = { active = active, message = message } })
end

function ManagerPatientView.stop()
    local view = current
    current = nil
    if not view then return end
    -- 別リソースが視点を引き継いでいる場合は、そのカメラを止めない。
    if GetRenderingCam() == view.cam then RenderScriptCams(false, false, 0, true, true) end
    if DoesCamExist(view.cam) then DestroyCam(view.cam, false) end
end

local function patientPed(serverId)
    local player = GetPlayerFromServerId(serverId)
    local ped = player ~= -1 and GetPlayerPed(player) or 0
    if ped == 0 or ped == PlayerPedId() or not DoesEntityExist(ped) then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > Config.PatientView.MaxDistance then return nil end
    if IsPedInAnyVehicle(ped, false) or IsEntityAttached(ped) then return nil end
    return ped
end

local function examinerUnavailable()
    local dead = LocalPlayer.state.dead
    return IsEntityDead(PlayerPedId()) or dead == 'dead' or dead == 'laststand'
        or dead == 1 or dead == 2 or dead == true
end

local function framePatient(view)
    -- 頭と足の中点を注視し、倒れた患者は上方から映す。
    local head = GetPedBoneCoords(view.ped, 31086, 0.0, 0.0, 0.0)
    local foot = (GetPedBoneCoords(view.ped, 14201, 0.0, 0.0, 0.0)
        + GetPedBoneCoords(view.ped, 52301, 0.0, 0.0, 0.0)) * 0.5
    local center = (head + foot) * 0.5
    local lying = math.abs(head.z - foot.z) < 0.7
    local distance = Config.PatientView.CameraDistance
    local horizontal = lying and distance * 0.45 or distance
    local height = lying and distance or distance * 0.15
    SetCamCoord(view.cam, center.x + view.dx * horizontal, center.y + view.dy * horizontal, center.z + height)
    PointCamAtCoord(view.cam, center.x, center.y, center.z)
end

function ManagerPatientView.start(serverId)
    ManagerPatientView.stop()
    local ped = patientPed(serverId)
    if not ped or examinerUnavailable() then
        return { active = false, message = '近くの患者を確認できません。カルテのみ表示しています。' }
    end
    local other = GetRenderingCam()
    if other ~= -1 and DoesCamExist(other) then
        return { active = false, message = '別の視点を使用中です。カルテのみ表示しています。' }
    end
    local relative = GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped)
    local length = math.sqrt(relative.x * relative.x + relative.y * relative.y)
    local dx, dy = 0.0, 1.0
    if length > 0.1 then dx, dy = relative.x / length, relative.y / length end
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not cam or not DoesCamExist(cam) then
        return { active = false, message = '患者の視点を開けませんでした。' }
    end
    -- 医療者自身が患者に重なりにくいよう、医療者側から少し斜めの角度へ置く。
    local angle = math.rad(30)
    local view = { cam = cam, ped = ped, serverId = serverId,
        dx = dx * math.cos(angle) - dy * math.sin(angle),
        dy = dx * math.sin(angle) + dy * math.cos(angle), examiner = PlayerPedId() }
    current = view
    SetCamFov(cam, Config.PatientView.FieldOfView)
    framePatient(view)
    RenderScriptCams(true, false, 0, true, true)
    CreateThread(function()
        while current == view do
            Wait(0)
            if current ~= view then return end
            if GetRenderingCam() ~= cam or not DoesCamExist(cam) or PlayerPedId() ~= view.examiner
                or patientPed(serverId) ~= ped or examinerUnavailable() then
                ManagerPatientView.stop()
                status(false, '患者の表示を終了しました。カルテは引き続き確認できます。')
                return
            end
            framePatient(view)
        end
    end)
    return { active = true, message = '患者本人を表示中' }
end
