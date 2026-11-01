"""Normalize the seven body parts assigned by the installed Wasabi bone map."""
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

MODULE = Path(__file__).resolve().parents[1] / 'resources' / '[ptech]' / '[mediora]' / 'ptech_mediora_medical'


class MedicalReportRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function RegisterNUICallback() end; function AddEventHandler() end')
        self.lua.execute((MODULE / 'main/shared/shared.lua').read_text(encoding='utf-8'))
        self.lua.execute((MODULE / 'main/client/ui.lua').read_text(encoding='utf-8'))

    def test_seven_parts_keep_injury_details_and_display_names(self):
        self.lua.execute('''
        local parts = {'head', 'upper_body', 'lower_body', 'left_arm', 'right_arm', 'left_leg', 'right_leg'}
        local labels = {head='頭部', upper_body='上半身', lower_body='下半身',
            left_arm='左腕', right_arm='右腕', left_leg='左脚', right_leg='右脚'}
        local injuries = {}
        for _, part in ipairs(parts) do
            injuries[part] = {type='beat', data={level=2, bleed=1}}
        end
        local report = Medical.report(injuries, true)
        assert(#report.rows == 7)
        for i, row in ipairs(report.rows) do
            assert(row.part == parts[i] and row.kind == 'beat')
            assert(row.severity == 2 and row.bleed == 1)
            local view = MedicalUI.view({injuries={[row.part]=injuries[row.part]}, success=true})
            assert(view.injuries[1].body == labels[row.part])
        end
        ''')

    def test_other_parts_do_not_create_treatable_chart_rows(self):
        self.lua.execute('''
        local injuries = {}
        for _, part in ipairs({'neck', 'spine', 'left_hand', 'right_hand', 'left_foot', 'right_foot', 'none'}) do
            injuries[part] = {type='shot', data={level=4, bleed=3}}
        end
        local report = Medical.report(injuries, true)
        assert(#report.rows == 0 and report.status == '未対応形式')
        injuries.left_arm = {type='burned', data={level=1, bleed=0}}
        report = Medical.report(injuries, true)
        assert(#report.rows == 1 and report.rows[1].part == 'left_arm')
        assert(report.rows[1].kind == 'burned' and report.rows[1].severity == 1)
        ''')


if __name__ == '__main__':
    unittest.main()
