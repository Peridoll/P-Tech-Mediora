import pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]/'resources'/'[ptech]'/'[mediora]'/'ptech_mediora_rescue'
class RescueBeta01Contracts(unittest.TestCase):
    def test_manifest(self):
        x=(ROOT/'fxmanifest.lua').read_text()
        for n in ('client/client.lua','server/server.lua','shared/rules.lua'): self.assertIn(n,x)
    def test_server_gate(self):
        x=(ROOT/'main/server/server.lua').read_text()
        for n in ('Rescue.allowed','Rescue.down','Rescue.remaining','s.used','ptech_mediora_rescue:dispatch','playerDropped'): self.assertIn(n,x)
    def test_flight(self):
        x=(ROOT/'main/client/client.lua').read_text()
        for n in ('CreateVehicle(', 'CreatePedInsideVehicle(', 'TaskHeliMission(', 'SetPedIntoVehicle(', 'SetEntityCollision(', 'SetEntityCoordsNoOffset(', 'cleanup()'): self.assertIn(n,x)
    def test_no_health_revival(self):
        x=''.join(p.read_text() for p in (ROOT/'main').rglob('*.lua'))
        for n in ('SetEntityHealth(', 'NetworkResurrectLocalPlayer(', "TriggerEvent('wasabi_ambulance:revive"): self.assertNotIn(n,x)
    def test_config(self):
        x=(ROOT/'config/config.lua').read_text()
        for n in ('AllowedJobs','Countdown = 480','Control = 45','Helipad','Entrance'): self.assertIn(n,x)
if __name__=='__main__': unittest.main()
