local session, taskBlip, patient, testPed, testPreset = nil, nil, nil, nil, 1
local function notify(msg, kind)
    if msg and msg ~= '' then lib.notify({ title = 'Mediora Patients', description = msg, type = kind or 'inform' }) end
end
local function cleanupBlip()
    if taskBlip then RemoveBlip(taskBlip); taskBlip = nil end
end
local function deletePed(ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end
local function spawnLocal(modelName, coords)
    local model = joaat(modelName)
    lib.requestModel(model, 10000)
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    if ped == 0 then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    return ped
end
local function update(state)
    session = state
    cleanupBlip()
    deletePed(patient)
    patient = nil
    if not session then return end
    local point = session.stage == 'visit' and Config.Patients[session.index] and Config.Patients[session.index].coords or Config.Hospital
    if not point then return end
    taskBlip = AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(taskBlip, session.stage == 'visit' and 153 or 61)
    SetBlipColour(taskBlip, 2)
    SetBlipRoute(taskBlip, true)
    if session.stage == 'visit' then
        local entry = Config.Patients[session.index]
        patient = spawnLocal(entry.model, entry.coords)
        if patient then
            exports.ox_target:addLocalEntity(patient, {{
                name = 'ptech_mediora_patients:inspect', label = 'NPC患者を診察', icon = 'fa-solid fa-stethoscope',
                distance = Config.InteractionDistance,
                onSelect = function()
                    local case = Config.Cases[entry.case]
                    if not case then return end
                    if lib.progressCircle({ duration = case.duration, label = case.description,
                        canCancel = true, disable = { move = true, car = true, combat = true } }) then
                        local result = lib.callback.await('ptech_mediora_patients:job', false, 'inspect')
                        notify(result.message, result.ok and 'success' or 'error')
                        update(result.session)
                    end
                end,
            }})
        end
    end
end
local function action(kind)
    local r = lib.callback.await('ptech_mediora_patients:job', false, kind)
    if not r then return notify('通信エラー', 'error') end
    notify(r.message, r.ok and 'success' or 'error')
    if r.ok or r.session then update(r.session) end
end
local terminal = exports.ox_target:addSphereZone({
    coords = Config.Hospital, radius = 1.5,
    options = {
        { name = 'ptech_mediora_patients:terminal', icon = 'fa-solid fa-briefcase-medical',
          label = 'NPC診療依頼を確認', distance = Config.InteractionDistance, groups = Config.Jobs,
          onSelect = function()
              local r = lib.callback.await('ptech_mediora_patients:job', false, 'status')
              if not r or not r.ok then return notify(r and r.message or '通信エラー', 'error') end
              update(r.session)
              local options = {}
              if not session then options[1] = { title = '診療依頼を受注', onSelect = function() action('start') end }
              else
                  if session.stage == 'return' then
                      options[#options+1] = { title = '診療完了を報告', onSelect = function() action('finish') end }
                  end
                  options[#options+1] = { title = '依頼をキャンセル', onSelect = function() action('cancel') end }
              end
              lib.registerContext({ id = 'ptech_mediora_patients:terminal', title = 'NPC診療業務', options = options })
              lib.showContext('ptech_mediora_patients:terminal')
          end },
    },
})
local function removeTest()
    deletePed(testPed)
    testPed = nil
end
local function showTest()
    if not testPed or not DoesEntityExist(testPed) then return notify('テスト患者がいません', 'error') end
    local preset = Config.Test.Presets[testPreset]
    lib.registerContext({ id = 'ptech_mediora_patients:testDetail', title = 'テスト患者: ' .. preset.label,
        options = {
            { title = '現在の模擬状態', description = preset.label .. ' / ' .. tostring(preset.death), readOnly = true },
            { title = '模擬負傷データをF8へ出力', onSelect = function()
                print('[ptech_mediora_patients] synthetic fixture ' .. json.encode(preset))
                notify('F8へ模擬データを出力しました（実際の負傷状態には未反映）')
            end },
        } })
    lib.showContext('ptech_mediora_patients:testDetail')
end
local function testMenu()
    if not lib.callback.await('ptech_mediora_patients:testAccess', false) then
        return notify('勤務中の医療職のみ利用できます', 'error')
    end
    local options = {
        { title = '目の前にテスト患者を配置', onSelect = function()
            removeTest()
            local me = PlayerPedId()
            local pos = GetOffsetFromEntityInWorldCoords(me, 0, Config.Test.SpawnDistance, 0)
            local heading = GetEntityHeading(me) + 180
            testPed = spawnLocal(Config.Test.Model, vec4(pos.x, pos.y, pos.z, heading))
            notify(testPed and 'テスト患者を配置しました（自分にのみ表示）' or '配置に失敗しました', testPed and 'success' or 'error')
        end },
        { title = '現在の状態を確認', onSelect = showTest },
        { title = 'テスト患者を削除', onSelect = removeTest },
    }
    for i, v in ipairs(Config.Test.Presets) do
        options[#options+1] = { title = v.label .. (i == testPreset and ' [選択中]' or ''),
            onSelect = function()
                testPreset = i
                notify('模擬データを変更しました。実際のNPCの負傷状態は変更しません。')
                showTest()
            end }
    end
    lib.registerContext({ id = 'ptech_mediora_patients:test', title = 'Mediora Patients / テストモード', options = options })
    lib.showContext('ptech_mediora_patients:test')
end
RegisterCommand(Config.Test.Command, testMenu, false)
CreateThread(function()
    Wait(1500)
    local r = lib.callback.await('ptech_mediora_patients:job', false, 'status')
    if r and r.ok then update(r.session) end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() update(nil); removeTest() end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    update(nil)
    removeTest()
    exports.ox_target:removeZone(terminal)
end)
