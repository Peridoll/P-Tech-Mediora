"""FiveM APIを置き換え、実際のLua診察・保存・UIコードを通して確認する。"""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

HARNESS = """
callbacks, events, nuiCallbacks, commands, exported = {}, {}, {}, {}, {}
messages, notices, contexts, shownContexts, timers = {}, {}, {}, {}, {}
clock, focused = 10000, false
players = {}
for id = 1, 3 do
    players[id] = { PlayerData = {
        citizenid = 'citizen-' .. id, charinfo = {firstname = '患者', lastname = tostring(id)},
        job = { name = 'ambulance', onduty = true }, metadata = {isdead = false, inlaststand = false}
    }}
end
function AddEventHandler(name, fn)
    events[name] = events[name] or {}
    table.insert(events[name], fn)
end
RegisterNetEvent = AddEventHandler
function emit(name, ...) for _, fn in ipairs(events[name] or {}) do fn(...) end end
function RegisterNUICallback(name, fn) nuiCallbacks[name] = fn end
function RegisterCommand(name, fn) commands[name] = fn end
function CreateThread(fn) fn() end
function GetCurrentResourceName() return 'ptech_mediora_medical' end
function GetGameTimer() return clock end
function SetTimeout(ms, fn) timers[#timers + 1] = {ms = ms, fn = fn} end
function GetResourceState(name) return name == 'wasabi_ambulance' and 'started' or 'missing' end
function TriggerClientEvent(...) end
function TriggerServerEvent(name, ...) source = 1; emit(name, ...) end
function Player() return { state = {dead = false} } end
function GetPlayerPed(id) return id end
function PlayerPedId() return 1 end
function PlayerId() return 1 end
function GetEntityHealth() return 200 end
function GetPlayerRoutingBucket() return 0 end
function GetEntityCoords()
    return setmetatable({}, {__sub = function() return setmetatable({}, {__len = function() return 0 end}) end})
end
function IsPedAPlayer() return true end
function NetworkGetPlayerIndexFromPed(ped) return ped end
function GetPlayerServerId(id) return id end
function SetNuiFocus(active) focused = active end
function SendNUIMessage(message) messages[#messages + 1] = message end
exports = setmetatable({
    qbx_core = {
        GetPlayer = function(_, id) return players[id] end,
        GetPlayerData = function() return players[1].PlayerData end
    },
    wasabi_ambulance = {diagnosePlayer = function() return injuries end},
    ox_target = {
        addGlobalPlayer = function(_, options) targets = options end,
        removeGlobalPlayer = function() end
    },
    ptech_mediora_manager = {openCharts = function() error('legacy unavailable') end}
}, {__call = function(_, name, fn) exported[name] = fn end})
lib = {
    callback = {
        register = function(name, fn) callbacks[name] = fn end,
        await = function(name, _, ...) return callbacks[name](1, ...) end
    },
    notify = function(data) notices[#notices + 1] = data end,
    hideContext = function() end,
    registerContext = function(context) contexts[context.id] = context end,
    showContext = function(id) shownContexts[#shownContexts + 1] = id end,
    progressCircle = function(data) clock = clock + data.duration; return true end,
    progressActive = function() return false end
}
injuries = {left_arm = {type = 'beat', data = {level = 2, bleed = 1}}}
function invoke(name, src, ...) return callbacks['ptech_mediora_medical:' .. name](src, ...) end
function diagnose() commands.pmedical(nil, {'diagnose', '2'}) end
function latest() return messages[#messages] end
function nui(name, data)
    local result
    nuiCallbacks[name](data, function(value) result = value end)
    return result
end
"""


class ChartsTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for file in [
            "config/config.lua", "main/shared/shared.lua", "main/server/server.lua",
            "main/client/nui.lua", "main/client/ui.lua", "main/client/client.lua",
        ]:
            self.lua.execute((ROOT / file).read_text())

    def check(self, script):
        self.lua.execute(script)

    def test_diagnosis_opens_saved_chart_and_shares_with_other_medic(self):
        self.check("""
        diagnose()
        assert(focused and latest().action == 'charts:open')
        assert(latest().data.targetId == 2)
        local result = nui('getCharts', {targetId = 2})
        assert(#result.charts == 1 and result.charts[1].chartId == latest().data.chartId)
        assert(result.charts[1].injuries[1].part == 'left_arm')
        assert(invoke('getPatientCharts', 3, '2').charts[1].chartId == result.charts[1].chartId)
        clock = clock + 1000
        diagnose()
        assert(#nui('getCharts', {targetId = 2}).charts == 2)
        assert(invoke('createChart', 1, 2).error) -- 保存の再実行は不可
        """)

    def test_target_only_offers_diagnosis(self):
        self.check("""
        assert(#targets == 1 and targets[1].name == 'ptech_mediora_medical:diagnose')
        """)

    def test_unsupported_format_saves_patient_state_without_inventing_injuries(self):
        self.check("""
        injuries = {unexpected = {wounds = 'unknown'}}
        diagnose()
        assert(latest().action == 'charts:open')
        local chart = invoke('getPatientCharts', 1, 2).charts[1]
        assert(chart and #chart.injuries == 0)
        assert(chart.observationStatus:find('未取得', 1, true))
        """)

    def test_empty_observation_never_creates_healthy_chart(self):
        self.check("""
        injuries = {}
        diagnose()
        assert(latest().action == 'open' and latest().data.mode == 'empty')
        assert(#invoke('getPatientCharts', 1, 2).charts == 0)
        """)

    def test_permissions_are_rechecked_on_each_search(self):
        self.check("""
        assert(MedicalUI.openCharts(2))
        players[1].PlayerData.job.onduty = false
        assert(nui('getCharts', {targetId = 2}).error)
        assert(not MedicalUI.openCharts(2) and not focused)
        players[1].PlayerData.job = {name = 'police', onduty = true}
        assert(invoke('getPatientCharts', 1, 2).error)
        """)

    def test_id_reuse_does_not_show_other_citizens_charts(self):
        self.check("""
        diagnose()
        players[2].PlayerData.citizenid = 'new-citizen'
        assert(#nui('getCharts', {targetId = 2}).charts == 0)
        assert(nui('getCharts', {targetId = 999}).error)
        assert(nui('getCharts', {targetId = -1}).error)
        assert(nui('getCharts', {targetId = 1.5}).error)
        """)

    def test_context_mode_lists_and_opens_selected_chart(self):
        self.check("""
        diagnose()
        local chart = invoke('getPatientCharts', 1, 2).charts[1]
        Config.UI = 'context'
        assert(MedicalUI.openCharts(2, chart.chartId))
        local detail = contexts['ptech_mediora_medical:chartDetail']
        assert(detail and detail.options[4].title == '左腕 / 打撲')
        assert(detail.options[4].readOnly)
        assert(MedicalUI.openCharts(2))
        contexts['ptech_mediora_medical:charts'].options[1].onSelect()
        assert(shownContexts[#shownContexts] == 'ptech_mediora_medical:chartDetail')
        """)

    def test_closed_screen_and_new_search_discard_delayed_response(self):
        self.check("""
        MedicalUI.openCharts(2)
        local original = lib.callback.await
        lib.callback.await = function(name, ...)
            if name == 'ptech_mediora_medical:getPatientCharts' then coroutine.yield() end
            return original(name, ...)
        end
        local first, second
        local co = coroutine.create(function()
            nuiCallbacks.getCharts({targetId = 2}, function(value) first = value end)
        end)
        assert(coroutine.resume(co))
        lib.callback.await = original
        second = nui('getCharts', {targetId = 3})
        assert(second.patient.serverId == 3)
        assert(coroutine.resume(co))
        assert(first.error)
        lib.callback.await = function(name, ...)
            if name == 'ptech_mediora_medical:getPatientCharts' then coroutine.yield() end
            return original(name, ...)
        end
        co = coroutine.create(function()
            nuiCallbacks.getCharts({targetId = 2}, function(value) first = value end)
        end)
        assert(coroutine.resume(co))
        emit('QBCore:Client:OnPlayerUnload')
        assert(coroutine.resume(co))
        assert(first.error and not focused)
        assert(nui('getCharts', {targetId = 2}).error)
        """)

    def test_logout_during_access_does_not_reopen_diagnosis(self):
        self.check("""
        local original = lib.callback.await
        lib.callback.await = function(name, ...)
            if name == 'ptech_mediora_medical:managerAccess' then
                emit('QBCore:Client:OnPlayerUnload')
            end
            return original(name, ...)
        end
        diagnose()
        assert(not focused and latest().action == 'examination:status')
        assert(not latest().data.active)
        """)

    def test_callback_failure_is_reported_without_leaking_old_chart(self):
        self.check("""
        MedicalUI.openCharts(2)
        lib.callback.await = function() error('server unavailable') end
        assert(nui('getCharts', {targetId = 2}).error)
        MedicalUI.close()
        assert(nui('getCharts', {targetId = 2}).error)
        """)

    def test_legacy_manager_failure_falls_back_to_medical(self):
        self.check("""
        GetResourceState = function() return 'started' end
        diagnose()
        assert(focused and latest().action == 'charts:open')
        """)


if __name__ == "__main__":
    unittest.main()
