"""骨折の発生・独立保持・診察・キャラ分離・行動障害を実際のLuaで確認する。"""
import unittest

from test_charts import HARNESS, ROOT, LuaRuntime

PHYSICS = """
native = {health = 200, dead = false, vehicle = false, swim = false, underwater = false,
    attached = false, jump = false, climb = false, vault = false, ragdoll = false, canRagdoll = true}
LocalPlayer = {state = {dead = false}}
trips, packets, fractureThreads = {}, {}, {}
function IsPedInAnyVehicle() return native.vehicle end
function IsPedSwimming() return native.swim end
function IsPedSwimmingUnderWater() return native.underwater end
function IsEntityAttached() return native.attached end
function IsPedDeadOrDying() return native.dead end
function IsPedJumping() return native.jump end
function IsPedClimbing() return native.climb end
function IsPedVaulting() return native.vault end
function IsPedRagdoll() return native.ragdoll end
function CanPedRagdoll() return native.canRagdoll end
function GetEntityHealth() return native.health end
function SetPedToRagdoll(ped, minimum, maximum, kind)
    assert(ped == 1 and minimum == Config.Fracture.RagdollDuration and kind == 0)
    trips[#trips + 1] = clock
end
function TriggerClientEvent(name, target, value)
    packets[#packets + 1] = {name = name, target = target, value = value}
    if name == 'ptech_mediora_medical:fractures' and target == 1 then
        source = 65535
        emit(name, value)
    end
end
exports.wasabi_ambulance.diagnosePlayer = function(_, target)
    assert(target == true or type(target) == 'number')
    return injuries
end
function heavy(part, severity)
    return {[part or 'right_leg'] = {type = 'beat', data = {level = severity or 3, bleed = 0}}}
end
function observe(id, wounds, success)
    return MedicalFractureServer.observe(id, wounds, success ~= false)
end
"""


class FractureTest(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for name in [
            "config.lua", "main/shared/shared.lua", "main/server/fractures.lua", "main/server/server.lua",
            "main/client/nui.lua", "main/client/ui.lua", "main/client/client.lua",
        ]:
            self.lua.execute((ROOT / name).read_text(encoding='utf-8'))
        self.lua.execute(PHYSICS)
        self.lua.execute("CreateThread = function(fn) fractureThreads[#fractureThreads + 1] = fn end")
        self.lua.execute((ROOT / "main/client/fractures.lua").read_text(encoding='utf-8'))
        self.lua.execute("CreateThread = function(fn) fn() end")

    def check(self, code):
        self.lua.execute(code)

    def test_only_heavy_bruises_in_three_lower_parts_cause_fractures(self):
        self.check("""
        local wounds = {
            head = {type='beat',data={level=4}}, left_arm = {type='beat',data={level=4}},
            lower_body = {type='beat',data={level=3}}, left_leg = {type='beat',data={level=4}},
            right_leg = {type='beat',data={level=2}},
        }
        local result = observe(2, wounds)
        assert(result.parts.lower_body == 3 and result.parts.left_leg == 4)
        assert(not result.parts.head and not result.parts.left_arm and not result.parts.right_leg)
        wounds.right_leg.type = 'shot'; wounds.right_leg.data.level = 4
        assert(not observe(2, wounds).parts.right_leg)
        """)

    def test_malformed_and_failed_observations_cannot_create_fracture(self):
        self.check("""
        assert(not next(observe(2, heavy('left_leg', '4')).parts))
        assert(not next(observe(2, heavy('left_leg', 5)).parts))
        assert(not next(observe(2, heavy('left_leg', 3.5)).parts))
        assert(not next(observe(2, heavy(), false).parts))
        assert(not next(observe(2, {unknown={injuries='bad'}}).parts))
        """)

    def test_bruise_disappearance_or_unknown_data_does_not_clear_fracture(self):
        self.check("""
        observe(2, heavy())
        assert(observe(2, {}).parts.right_leg == 3)
        assert(observe(2, nil, false).parts.right_leg == 3)
        assert(observe(2, {unknown='data'}).parts.right_leg == 3)
        """)

    def test_cleared_fracture_does_not_recur_from_same_bruise_but_new_bruise_does(self):
        self.check("""
        observe(2, heavy())
        assert(exported.clearFractures(2, 'right_leg'))
        assert(not observe(2, heavy()).parts.right_leg)
        observe(2, {})
        assert(observe(2, heavy()).parts.right_leg == 3)
        assert(not exported.clearFractures(2, 'head'))
        assert(exported.getFractures(2).parts.right_leg == 3)
        """)

    def test_diagnosis_keeps_bruise_and_fracture_in_one_part_without_extra_time(self):
        self.check("""
        injuries = heavy('left_leg', 3)
        local started = clock
        diagnose()
        local rows = invoke('getPatientCharts', 1, 2).charts[1].injuries
        assert(#rows == 2 and rows[1].kind == 'beat' and rows[2].kind == 'fracture')
        assert(rows[1].part == rows[2].part and clock - started == 2000)
        exported.clearFractures(2)
        assert(rows[2].kind == 'fracture') -- 過去のカルテは書き換えない
        """)

    def test_self_observation_cannot_target_another_citizen(self):
        self.check("""
        assert(invoke('fractures:observe', 1, 'citizen-2', heavy(), true).error)
        assert(not next(exported.getFractures(2).parts))
        local result = invoke('fractures:observe', 1, 'citizen-1', heavy(), true)
        assert(result.parts.right_leg == 3 and not next(exported.getFractures(2).parts))
        """)

    def test_server_state_is_separated_by_character_and_survives_reconnect(self):
        self.check("""
        observe(1, heavy())
        players[1].PlayerData.citizenid = 'different-character'
        assert(not next(exported.getFractures(1).parts))
        players[1].PlayerData.citizenid = 'citizen-1'
        assert(exported.getFractures(1).parts.right_leg == 3)
        source = 1; emit('playerDropped')
        assert(exported.getFractures(1).parts.right_leg == 3)
        """)

    def test_local_export_is_polled_and_causes_jump_ragdoll_before_diagnosis(self):
        self.check("""
        exports.wasabi_ambulance.diagnosePlayer = function(_, target)
            assert(target == true)
            return heavy()
        end
        MedicalFractureClient.refresh()
        native.jump = true
        MedicalFractureClient.step()
        assert(#trips == 1 and exported.getFractures(1).parts.right_leg == 3)
        assert(#invoke('getPatientCharts', 1, 2).charts == 0)
        """)

    def test_climb_vault_and_cooldown_without_repeated_ragdoll(self):
        self.check("""
        MedicalFractureClient.refresh()
        observe(1, heavy())
        native.climb = true; MedicalFractureClient.step()
        MedicalFractureClient.step()
        assert(#trips == 1)
        native.climb = false; MedicalFractureClient.step()
        native.vault = true; MedicalFractureClient.step()
        assert(#trips == 1)
        native.vault = false; MedicalFractureClient.step()
        clock = clock + Config.Fracture.RagdollCooldown
        native.vault = true; MedicalFractureClient.step()
        assert(#trips == 2)
        """)

    def test_walking_and_protected_states_do_not_ragdoll(self):
        self.check("""
        MedicalFractureClient.refresh()
        observe(1, heavy())
        MedicalFractureClient.step()
        native.jump = true
        for _, flag in ipairs({'dead','vehicle','swim','underwater','attached','ragdoll'}) do
            native[flag] = true
            MedicalFractureClient.step()
            native[flag] = false
            native.jump = false; MedicalFractureClient.step(); native.jump = true
        end
        native.canRagdoll = false; MedicalFractureClient.step()
        assert(#trips == 0)
        """)

    def test_off_duty_patients_are_still_affected(self):
        self.check("""
        players[1].PlayerData.job = {name='police',onduty=false}
        injuries = heavy()
        MedicalFractureClient.refresh()
        native.jump = true; MedicalFractureClient.step()
        assert(#trips == 1)
        """)

    def test_clear_event_removes_effect_and_stale_revision_is_ignored(self):
        self.check("""
        MedicalFractureClient.refresh()
        local before = observe(1, heavy())
        exported.clearFractures(1)
        assert(not MedicalFractureClient.apply(before))
        native.jump = true; MedicalFractureClient.step()
        assert(#trips == 0)
        assert(not MedicalFractureClient.apply({citizenId='citizen-2',revision=999,parts={right_leg=4}}))
        """)

    def test_logout_suppresses_late_poll_and_old_character_updates(self):
        self.check("""
        exports.wasabi_ambulance.diagnosePlayer = function()
            emit('QBCore:Client:OnPlayerUnload')
            return heavy()
        end
        MedicalFractureClient.refresh()
        native.jump = true; MedicalFractureClient.step()
        assert(#trips == 0 and not next(exported.getFractures(1).parts))
        MedicalFractureClient.refresh()
        assert(not next(exported.getFractures(1).parts))
        """)

    def test_initial_sync_failure_is_retried_even_if_wasabi_is_unavailable(self):
        self.check("""
        observe(1, heavy())
        GetResourceState = function() return 'missing' end
        local original, calls = lib.callback.await, 0
        lib.callback.await = function(name, ...)
            calls = calls + 1
            if calls == 1 then error('temporary network failure') end
            return original(name, ...)
        end
        MedicalFractureClient.refresh()
        MedicalFractureClient.refresh()
        native.jump = true; MedicalFractureClient.step()
        assert(calls == 2 and #trips == 1)
        """)

    def test_climbing_retries_when_ragdoll_becomes_possible(self):
        self.check("""
        MedicalFractureClient.refresh()
        observe(1, heavy())
        native.climb, native.canRagdoll = true, false
        MedicalFractureClient.step()
        assert(#trips == 0)
        native.canRagdoll = true
        MedicalFractureClient.step()
        assert(#trips == 1)
        """)


if __name__ == "__main__":
    unittest.main()
