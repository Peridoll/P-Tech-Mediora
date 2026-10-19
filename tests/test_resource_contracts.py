"""Offline source contract checks. Run: python -m unittest discover -s tests -p 'test_*.py'"""
from pathlib import Path
import re
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ROOT = PROJECT_ROOT / 'resources' / '[ptech]' / '[mediora]'
MODULES = ['medical', 'patients', 'escort', 'procurement', 'pharmacy', 'billing', 'settlement']

class ResourceContractTests(unittest.TestCase):
    def test_all_seven_resources_have_manifests(self):
        for name in MODULES:
            with self.subTest(module=name):
                base = ROOT / f'ptech_mediora_{name}'
                self.assertTrue((base / 'fxmanifest.lua').is_file())
                self.assertTrue((base / 'config.lua').is_file())

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

    def test_readme_is_the_only_markdown_document(self):
        markdown_files = sorted(
            path.relative_to(PROJECT_ROOT).as_posix()
            for path in PROJECT_ROOT.rglob('*.md')
            if '.git' not in path.parts
        )
        self.assertEqual(markdown_files, ['README.md'])

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
            server = (ROOT / f'ptech_mediora_{name}' / 'server.lua').read_text(encoding='utf-8')
            for method in ('RemoveMoney(', 'AddMoney(', 'removeAccountMoney(', 'addAccountMoney('):
                self.assertNotIn(method, server)

if __name__ == '__main__':
    unittest.main()
