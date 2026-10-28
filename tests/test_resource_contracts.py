"""Offline source contract checks. Run: python -m unittest discover -s tests -p 'test_*.py'"""
from pathlib import Path
import re
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ROOT = PROJECT_ROOT / 'resources' / '[ptech]' / '[mediora]'
MODULES = ['medical', 'marine', 'manager', 'patients', 'escort', 'procurement', 'pharmacy', 'billing', 'settlement']

class ResourceContractTests(unittest.TestCase):
    def test_all_resources_have_manifests(self):
        for name in MODULES:
            with self.subTest(module=name):
                base = ROOT / f'ptech_mediora_{name}'
                self.assertTrue((base / 'fxmanifest.lua').is_file())
                config = base / ('config/config.lua' if name in ('medical', 'marine', 'manager', 'escort') else 'config.lua')
                self.assertTrue(config.is_file())

    def test_manifest_script_paths_exist(self):
        for name in MODULES:
            with self.subTest(module=name):
                base = ROOT / f'ptech_mediora_{name}'
                text = (base / 'fxmanifest.lua').read_text(encoding='utf-8')
                for group in ('shared_scripts', 'client_scripts', 'server_scripts', 'files'):
                    match = re.search(r'\b' + group + r'\s*\{([^}]*)\}', text, re.S)
                    if match:
                        for rel in re.findall(r"['\"]([^'\"]+)['\"]", match.group(1)):
                            if rel.startswith('@'): continue
                            self.assertTrue((base / rel).is_file(), f'{name}: missing {rel}')

    def test_project_markdown_documents_are_consolidated(self):
        markdown_files = sorted(
            path.relative_to(PROJECT_ROOT).as_posix()
            for path in PROJECT_ROOT.rglob('*.md')
            if '.git' not in path.parts
        )
        self.assertEqual(markdown_files, ['DEVELOPMENT.md', 'README.md'])

    def test_no_legacy_composite_dependency(self):
        for name in MODULES:
            base = ROOT / f'ptech_mediora_{name}'
            for file in base.rglob('*.lua'):
                if file.name == 'README.md': continue
                data = file.read_text(encoding='utf-8')
                with self.subTest(file=str(file.relative_to(ROOT))):
                    self.assertNotIn('MedicalModules.', data)
                    self.assertNotIn('ptech_medicalJobs:', data)

    def test_no_bank_payout_in_draft_modules(self):
        for name in ('billing', 'settlement'):
            server_path = ROOT / f'ptech_mediora_{name}' / 'server.lua'
            server = server_path.read_text(encoding='utf-8')
            for method in ('RemoveMoney(', 'AddMoney(', 'removeAccountMoney(', 'addAccountMoney('):
                self.assertNotIn(method, server)

    def test_medical_diagnosis_entry_contract(self):
        medical = ROOT / 'ptech_mediora_medical'
        config = (medical / 'config/config.lua').read_text(encoding='utf-8')
        client = (medical / 'main/client/client.lua').read_text(encoding='utf-8')
        server = (medical / 'main/server/server.lua').read_text(encoding='utf-8')
        manifest = (medical / 'fxmanifest.lua').read_text(encoding='utf-8')
        self.assertRegex(config, r"Jobs\s*=\s*\{\s*'ambulance'\s*\}")
        self.assertRegex(config, r"Name\s*=\s*'pmedical'")
        self.assertRegex(config, r"Action\s*=\s*'diagnose'")
        self.assertNotIn('RequireDuty', config)
        self.assertNotIn('Aliases', config)
        self.assertNotIn('ShortAction', config)
        self.assertIn("'ox_target'", manifest)
        self.assertIn('local function startDiagnosis(target)', client)
        self.assertIn('RegisterCommand(Config.Commands.Name, handleCommand, false)', client)
        self.assertNotIn('Config.Commands.Aliases', client)
        self.assertNotIn('Config.Commands.ShortAction', client)
        self.assertIn('lib.progressCircle', client)
        self.assertIn('exports.ox_target:addGlobalPlayer', client)
        self.assertIn("ptech_mediora_medical:cancel", client)
        self.assertIn("ptech_mediora_medical:confirm", client)
        self.assertIn("ptech_mediora_medical:cancel", server)
        self.assertIn('noChart = true', server)
        self.assertIn("ptech_mediora_medical:getPatientCharts", server)
        self.assertIn("ptech_mediora_manager:openCharts", client)
        self.assertIn("prop = Config.Examination.Prop", client)
        self.assertNotIn('ptech_diagnosis', config)
        self.assertNotIn("'ox_inventory'", manifest)

    def test_mediora_treatment_item_contract(self):
        medical = ROOT / 'ptech_mediora_medical'
        manifest = (medical / 'fxmanifest.lua').read_text(encoding='utf-8')
        items = (medical / 'config/items.lua').read_text(encoding='utf-8')
        install_items = (medical / 'assets/install/ox_inventory/items.lua').read_text(encoding='utf-8')
        treatments = (medical / 'config/treatment_config.lua').read_text(encoding='utf-8')
        expected = {
            'shot': 'ptech_mediora_tweezers',
            'stabbed': 'ptech_mediora_suturekit',
            'beat': 'ptech_mediora_icepack',
            'burned': 'ptech_mediora_burncream',
        }

        self.assertIn("'config/items.lua'", manifest)
        self.assertIn('MedioraItems = {', items)
        self.assertNotIn('MedioraOxInventoryItems', items)
        self.assertIn('return {', install_items)
        self.assertIn('既存の items.lua を上書きしないこと', install_items)
        self.assertEqual(len(re.findall(r'^\s*consume\s*=\s*0,', install_items, re.M)), len(expected))
        for injury, item in expected.items():
            with self.subTest(injury=injury):
                self.assertIn(f"['{item}'] = {{", items)
                self.assertIn(f"['{item}'] = {{", install_items)
                self.assertIn(f"treatment = '{injury}'", items)
                self.assertIn(f"{injury} = {{", treatments)
                self.assertIn(f"item = '{item}'", treatments)
                self.assertIn(f"wasabiInjury = '{injury}'", treatments)

    def test_marine_flotation_contract(self):
        marine = ROOT / 'ptech_mediora_marine'
        config = (marine / 'config/config.lua').read_text(encoding='utf-8')
        manifest = (marine / 'fxmanifest.lua').read_text(encoding='utf-8')
        shared = (marine / 'main/shared/rules.lua').read_text(encoding='utf-8')
        client = (marine / 'main/client/flotation.lua').read_text(encoding='utf-8')
        server = (marine / 'main/server/flotation.lua').read_text(encoding='utf-8')
        page = (marine / 'main/ui/index.html').read_text(encoding='utf-8')
        app = (marine / 'main/ui/app.js').read_text(encoding='utf-8')

        self.assertIn('Flotation = {', config)
        self.assertIn('Countdown = 180', config)
        self.assertIn("'main/client/flotation.lua'", manifest)
        self.assertIn("'main/server/flotation.lua'", manifest)
        self.assertIn('function Marine.validSurface', shared)
        self.assertIn('function Marine.busy', shared)
        self.assertIn("ptech_mediora_marine:activateFlotation", client)
        self.assertIn("ptech_mediora_marine:activateFlotation", server)
        self.assertIn("ptech_mediora_marine:flotationWater", client)
        self.assertIn("ptech_mediora_marine:flotationWater", server)
        self.assertIn('receiveFloat(id, float, revision)', client)
        self.assertNotIn('source == 65535', client)
        self.assertIn('id="flotation"', page)
        self.assertIn("data.action === 'show'", app)
        self.assertNotIn('Config.Fins', config)
        self.assertNotIn('ox_inventory', manifest)
        self.assertFalse((marine / 'main/client/client.lua').exists())
        self.assertFalse((marine / 'main/server/server.lua').exists())
        medical = ROOT / 'ptech_mediora_medical'
        self.assertNotIn('Flotation = {', (medical / 'config/config.lua').read_text(encoding='utf-8'))
        self.assertNotIn('flotation.lua', (medical / 'fxmanifest.lua').read_text(encoding='utf-8'))

    def test_manager_tablet_contract(self):
        manager = ROOT / 'ptech_mediora_manager'
        manifest = (manager / 'fxmanifest.lua').read_text(encoding='utf-8')
        config = (manager / 'config/config.lua').read_text(encoding='utf-8')
        client = (manager / 'main/client/client.lua').read_text(encoding='utf-8')
        app = (manager / 'main/ui/app.js').read_text(encoding='utf-8')
        self.assertIn("TabletItem = 'ptech_ems_tablet'", config)
        self.assertIn("'ptech_mediora_medical'", manifest)
        self.assertIn("exports('openTablet'", client)
        self.assertIn("exports('openCharts'", client)
        self.assertIn("ptech_mediora_medical:getPatientCharts", client)
        self.assertIn("message.action !== 'open'", app)
        self.assertIn("getCharts", app)

    def test_manager_treatment_screen_contract(self):
        manager = ROOT / 'ptech_mediora_manager'
        page = (manager / 'main/ui/index.html').read_text(encoding='utf-8')
        app = (manager / 'main/ui/app.js').read_text(encoding='utf-8')
        client = (manager / 'main/client/client.lua').read_text(encoding='utf-8')
        self.assertIn('id="treatment-page"', page)
        self.assertIn('id="treatment-supply-list"', page)
        self.assertIn('id="open-treatment"', app)
        self.assertIn('function renderTreatment(chart)', app)
        self.assertIn('function renderTreatmentSupplies()', app)
        self.assertIn("showPage('treatment')", app)
        self.assertIn("getTreatmentItems()", client)
        self.assertIn('treatmentItems = treatmentItems()', client)
        self.assertNotIn('RemoveItem(', app)
        self.assertNotIn('treatPlayer', app)

if __name__ == '__main__':
    unittest.main()
