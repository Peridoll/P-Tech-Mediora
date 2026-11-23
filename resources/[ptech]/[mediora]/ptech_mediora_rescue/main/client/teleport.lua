-- 切り分け用: 死亡後にRを3秒長押しして、現在地から20m上へ移動するだけ。
local HOLD_MS = 3000
local HEIGHT = 20.0
local heldAt, heldPed
local awaitingRelease = false

local keybind = lib.addKeybind({
    name = 'ptech_mediora_rescue_activate',
    description = 'Mediora Rescue：上空へテレポート（長押し検証）',
    defaultKey = 'R',
    onReleased = function()
        heldAt, heldPed = nil, nil
        awaitingRelease = false
    end,
})

local function isDown(ped)
    if IsEntityDead(ped) then return true end
    local dead = LocalPlayer.state.dead
    if dead == true or dead == 1 or dead == 2 or dead == 'dead' or dead == 'laststand' then
        return true
    end
    -- 医療スクリプトがpedを生かしたままダウン状態を管理する場合にも対応する。
    if GetResourceState('qbx_core') == 'started' then
        local data = exports.qbx_core:GetPlayerData()
        local metadata = data and data.metadata or {}
        return metadata.isdead == true or metadata.inlaststand == true
    end
    return false
end

local function drawHint(percent)
    local key = keybind.currentKey or 'R'
    local text = ('%s HOLD 3s - TELEPORT UP 20m (%d%%)'):format(key, percent)
    SetTextFont(0)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 240)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.02, 0.76)
    DrawRect(0.15, 0.805, 0.26, 0.009, 30, 30, 30, 200)
    if percent > 0 then
        local width = 0.26 * percent / 100
        DrawRect(0.02 + width / 2, 0.805, width, 0.009, 70, 175, 255, 240)
    end
end

CreateThread(function()
    print('[rescue_teleport] READY build=teleport-v1 hold=3 height=20')
    while true do
        local ped = PlayerPedId()
        local held = keybind:isControlPressed()
        if IsPauseMenuActive() or (IsNuiFocused() and not IsNuiFocusKeepingInput()) then
            keybind.isPressed = false
            held = false
        end
        if not held then awaitingRelease = false end

        if not isDown(ped) then
            heldAt, heldPed = nil, nil
            Wait(100)
        else
            local percent = 0
            if held and not awaitingRelease then
                if heldPed ~= ped then heldAt, heldPed = GetGameTimer(), ped end
                heldAt = heldAt or GetGameTimer()
                percent = math.min(100, math.floor((GetGameTimer() - heldAt) / HOLD_MS * 100))
                if percent >= 100 then
                    -- 通信・要請・ヘリ生成を挟まず、この場で本人の座標だけを変更する。
                    local pos = GetEntityCoords(ped)
                    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z + HEIGHT, true, true, true)
                    print(('[rescue_teleport] TELEPORT ped=%s from=%.2f,%.2f,%.2f to=%.2f,%.2f,%.2f')
                        :format(ped, pos.x, pos.y, pos.z, pos.x, pos.y, pos.z + HEIGHT))
                    awaitingRelease = true
                    heldAt, heldPed = nil, nil
                end
            else
                heldAt, heldPed = nil, nil
            end
            drawHint(percent)
            Wait(0)
        end
    end
end)
