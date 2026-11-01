"""Marine server-side emergency flotation behavior tests (requires lupa)."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MARINE = ROOT / 'resources' / '[ptech]' / '[mediora]' / 'ptech_mediora_marine'

HARNESS = r'''
callbacks, events, sent, threads, timeouts = {}, {}, {}, {}, {}
now = 1000
local vector = {}
vector.__index = vector
function vec(x, y, z) return setmetatable({x=x, y=y, z=z}, vector) end
vector.__sub = function(a, b) return vec(a.x-b.x, a.y-b.y, a.z-b.z) end
vector.__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end

players = {
  [1] = {ped=11, bucket=0, coords=vec(0, 0, -10), state={dead='dead'},
    data={citizenid='patient-1', metadata={isdead=true, inlaststand=false}}},
  [2] = {ped=22, bucket=0, coords=vec(20, 0, 0), state={},
    data={citizenid='alive-2', metadata={isdead=false, inlaststand=false}}},
}
exports = {qbx_core = {GetPlayer=function(_, id)
  return players[id] and {PlayerData=players[id].data} or nil
end}}
lib = {callback={
  register=function(name, fn) callbacks[name] = fn end,
  await=function(name, id)
    if duringProbe then duringProbe() end
    local player = players[id]
    if not player then return nil end
    return observation or {water=true, x=player.coords.x, y=player.coords.y, z=player.coords.z, surface=0}
  end,
}}
function Player(id) return {state=players[id].state} end
function GetPlayerPed(id) return players[id] and players[id].ped or 0 end
function GetPlayerRoutingBucket(id) return players[id] and players[id].bucket or -1 end
function GetEntityCoords(ped)
  for _, player in pairs(players) do if player.ped == ped then return player.coords end end
  error('unknown ped')
end
function GetVehiclePedIsIn() return 0 end
function GetGameTimer() return now end
function GetPlayers()
  local result = {}
  for id in pairs(players) do result[#result + 1] = tostring(id) end
  return result
end
function TriggerClientEvent(name, id, ...) sent[#sent + 1] = {name=name, id=id, args={...}} end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function SetTimeout(_, fn) timeouts[#timeouts + 1] = fn end
function AddEventHandler(name, fn) events[name] = fn end
function GetCurrentResourceName() return 'ptech_mediora_marine' end
function runServerLoop()
  for _, thread in ipairs(threads) do assert(coroutine.resume(thread)) end
  for _, thread in ipairs(threads) do assert(coroutine.resume(thread)) end
end
function activate(id) return callbacks['ptech_mediora_marine:activateFlotation'](id) end
function snapshot() return callbacks['ptech_mediora_marine:flotationSnapshot'](1) end
'''


class MarineFlotationRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for rel in ('config/config.lua', 'main/shared/rules.lua', 'config/server.lua', 'main/server/flotation.lua'):
            self.lua.execute((MARINE / rel).read_text(encoding='utf-8'))
        self.lua.execute('runServerLoop(); now = now + Config.Flotation.Countdown * 1000')

    def test_eligible_dead_player_activates_once_without_an_item(self):
        self.lua.execute('''
        assert(activate(1))
        local state = snapshot()
        assert(state.floats[1].x == 0 and state.floats[1].y == 0)
        assert(state.floats[1].surface == Config.Flotation.SurfaceOffset)
        assert(not activate(1))
        assert(sent[#sent].name == 'ptech_mediora_marine:flotation')
        assert(sent[#sent].id == -1)
        ''')

    def test_accepts_numeric_and_boolean_wasabi_dead_states(self):
        self.lua.execute('''
        players[1].state.dead=1
        players[1].data.metadata.isdead=false
        assert(Medical.down(players[1].state, players[1].data.metadata))
        assert(Medical.death(players[1].state.dead, players[1].data.metadata) == '瀕死（laststand）')
        assert(activate(1))
        ''')

        self.setUp()
        self.lua.execute('''
        players[1].state.dead=true
        players[1].data.metadata.isdead=false
        assert(Medical.down(players[1].state, players[1].data.metadata))
        assert(Medical.death(players[1].state.dead, players[1].data.metadata) == '死亡')
        assert(activate(1))
        ''')

    def test_rejects_alive_escorted_or_invalid_water_observation(self):
        self.lua.execute('players[1].state.dead=false; players[1].data.metadata.isdead=false; assert(not activate(1))')

        self.setUp()
        self.lua.execute('players[1].state.emsEscortedBy=2; assert(not activate(1))')

        self.setUp()
        self.lua.execute('observation={water=false, x=0, y=0, z=-10, surface=0}; assert(not activate(1))')

        self.setUp()
        self.lua.execute('observation={water=true, x=100, y=0, z=-10, surface=0}; assert(not activate(1))')

    def test_rechecks_state_after_water_observation(self):
        self.lua.execute('''
        duringProbe=function()
          players[1].state.emsEscortedBy=2
        end
        assert(not activate(1))
        assert(snapshot().floats[1] == nil)
        ''')


if __name__ == '__main__':
    unittest.main()
