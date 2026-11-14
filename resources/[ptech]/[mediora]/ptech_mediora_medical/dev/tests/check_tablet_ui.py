from pathlib import Path
import json
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / 'main/ui'
injuries = [
    dict(part='left_arm', kind='shot', severity=1, bleed=1, model='medical'),
    dict(part='left_arm', kind='bleeding', severity=1, bleed=1, model='medical'),
    dict(part='right_leg', kind='bruise', severity=3, bleed=0, model='medical'),
]
chart = dict(chartId='chart-1', patientName='患者 太郎', examinerName='医師', issuedAt='2026-11-06T00:00:00Z',
             death='死亡・瀕死フラグなし', injuries=injuries, treated={}, charges=[], totalCharge=0,
             observationStatus='Medical受傷記録')
result = dict(patient=dict(name='患者 太郎', serverId=2), charts=[chart], currentInjuries=injuries,
              vitals=dict(health=75, hunger=80, thirst=70, stress=20, down=False),
              treatmentItems=[dict(name='pmediora_bulletextractionkit', label='弾丸摘出キット', count=3),
                              dict(name='pmediora_icepack', label='冷却パック', count=4),
                              dict(name='pmediora_firstaidkit', label='救急キット', count=1)],
              itemDefinitions={'pmediora_bulletextractionkit':dict(kinds=['shot','pin'], bleeding=True),
                               'pmediora_icepack':dict(kinds=['blunt']),
                               'pmediora_firstaidkit':dict(heal=100)})
requests = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True)
    page = browser.new_page(viewport=dict(width=1600, height=1000))
    errors = []
    page.on('pageerror', lambda err: errors.append(str(err)))
    page.add_init_script("window.GetParentResourceName = () => 'ptech_mediora_medical';")
    def route(req):
        if req.request.url.startswith('https://ptech_mediora_medical/'):
            endpoint = req.request.url.rsplit('/', 1)[-1]
            data = req.request.post_data_json
            requests.append((endpoint, data))
            req.fulfill(json=result if endpoint == 'getCharts' else photo if endpoint == 'getChartPhoto' else dict(error='mock: verified request'))
        else:
            req.abort()
    page.route('https://**/*', route)
    page.goto(UI.joinpath('index.html').as_uri())
    saved_issued_at = chart['issuedAt']
    chart['issuedAt'] = '2000-01-01T00:00:00Z'
    page.evaluate('window.postMessage({action:"charts:open",data:{targetId:2}}, "*")')
    all_dates = page.get_by_role('button', name='全日付を表示（1件）')
    all_dates.click()
    assert page.locator('#chart-date').input_value() == ''
    assert page.locator('#chart-detail').is_visible()
    chart['issuedAt'] = saved_issued_at
    def open_chart(treatment=False):
        page.evaluate('(data) => window.postMessage({action:"charts:open", data}, "*")',
                      dict(targetId=2, chartId='chart-1', openTreatment=treatment))
        page.locator('#chart-detail').wait_for(state='visible')
        page.wait_for_timeout(450)
    photo = dict(image=page.evaluate("document.createElement('canvas').toDataURL('image/jpeg')"),
                 anchors=dict(right_leg=dict(x=.45,y=.72),left_arm=dict(x=.56,y=.40)))
    result['photoEnabled'] = True
    chart['hasPhoto'] = True
    open_chart()
    assert page.locator('#chart-photo').is_visible()
    assert page.locator('#chart-callout-lines line').count() == 2
    chart['hasPhoto'] = False
    open_chart()
    assert not page.locator('#chart-photo').is_visible()
    assert page.locator('#chart-photo-status').inner_text() == '診察写真なし'
    assert not page.locator('#chart-callout-lines').is_visible()
    assert not page.locator('#chart-body-map').is_visible()
    result['photoEnabled'] = False
    open_chart()
    assert page.locator('#chart-body-map [data-part]').count() == 7
    assert page.locator('#chart-body-map').is_visible()
    assert not page.locator('#chart-photo-layer').is_visible()
    assert page.locator('#chart-sidebar-patient').inner_text() == '患者 太郎'
    assert page.locator('#chart-injuries tr').count() == 3
    chart_box = page.locator('.chart-panel').bounding_box()
    map_box = page.locator('#chart-body-map').bounding_box()
    page.screenshot(path=str(Path(__import__('tempfile').gettempdir())/'mediora-chart-preview.png'))
    page.locator('#chart-treat').click()
    page.locator('#treatment-screen').wait_for(state='visible')
    assert page.locator('.treatment-tool').count() == 3
    assert page.locator('#chart-body-map').bounding_box() == map_box, (map_box, page.locator('#chart-body-map').bounding_box())
    assert page.locator('.chart-panel').bounding_box() == chart_box
    page.screenshot(path=str(Path(__import__('tempfile').gettempdir())/'mediora-treatment-preview.png'))
    card = page.locator('.treatment-tool[data-kind="pmediora_icepack"]')
    target = page.locator('#chart-body-map [data-part="right_leg"]')
    wrong = page.locator('#chart-body-map [data-part="left_arm"]')
    page.locator('#treatment-tools').hover()
    cb, tb, wb = card.bounding_box(), target.bounding_box(), wrong.bounding_box()
    page.mouse.move(cb['x']+20, cb['y']+20)
    page.mouse.down()
    page.mouse.move(wb['x']+wb['width']/2, wb['y']+wb['height']/2, steps=10)
    assert page.locator('.drop-ready').count() == 0
    page.mouse.move(tb['x']+tb['width']/2, tb['y']+tb['height']/2, steps=10)
    assert page.locator('.drop-ready').count() == 1
    page.mouse.up()
    page.wait_for_timeout(150)
    assert any(endpoint=='treatChartInjury' and data['part']=='right_leg' and data['item']=='pmediora_icepack' for endpoint,data in requests)
    page.locator('#treatment-back').click()
    page.locator('#chart-treat').click()
    kit = page.locator('.treatment-tool[data-kind="pmediora_firstaidkit"]').bounding_box()
    head = page.locator('#chart-body-map [data-part="head"]').bounding_box()
    page.mouse.move(kit['x']+15, kit['y']+15)
    page.mouse.down()
    page.mouse.move(head['x']+head['width']/2, head['y']+head['height']/2, steps=10)
    assert page.locator('#chart-body-map .drop-ready').count() == 7
    page.mouse.up()
    page.wait_for_timeout(150)
    assert any(endpoint=='treatChartInjury' and data['item']=='pmediora_firstaidkit' and data['part']=='upper_body' for endpoint,data in requests)
    page.locator('#treatment-back').click()
    # Partial treatment shows the receipt alongside the remaining wound.
    result['currentInjuries'] = [injuries[0]]
    chart.update(treated={'1':True,'2':True,'3':True}, treatmentCharges=[dict(label='冷却', siteCount=3, amount=300000)],
                 treatmentFee=100000,totalCharge=400000)
    open_chart()
    assert page.locator('#chart-supplies').is_visible()
    assert page.locator('#chart-supplies-list tr').first.locator('td').all_inner_texts() == ['冷却', '3か所', '￥300,000']
    assert page.locator('#chart-injuries').is_visible()
    assert page.locator('#chart-treat').inner_text() == '治療'
    page.locator('#chart-bill').click()
    assert page.locator('#chart-billing-window').is_visible()
    assert '400,000' in page.locator('#chart-billing-total').inner_text()
    page.locator('#chart-billing-mode').select_option('manual')
    amount = page.locator('#chart-billing-amount')
    assert page.locator('#chart-billing-submit').is_disabled()
    assert '請求金額を入力' in page.locator('#chart-billing-hint').inner_text()
    amount.fill('0')
    assert page.locator('#chart-billing-submit').is_disabled()
    amount.fill('125000')
    assert '125,000' in page.locator('#chart-billing-total').inner_text()
    assert page.locator('#chart-billing-submit').is_enabled()
    assert page.locator('#chart-billing-hint').is_hidden()
    page.locator('#chart-billing-close').click()
    chart['revived'] = True
    open_chart()
    page.locator('#chart-bill').click()
    assert '蘇生プリセットを選択' in page.locator('#chart-billing-hint').inner_text()
    page.locator('#chart-billing-revive').select_option('hospital')
    assert page.locator('#chart-billing-submit').is_enabled()
    assert page.locator('#chart-billing-hint').is_hidden()
    page.locator('#chart-billing-close').click()
    chart.pop('revived')
    result['currentInjuries'] = []
    result['vitals']['health'] = 100
    open_chart(treatment=True)
    assert page.locator('#chart-treat').inner_text() == '治療済'
    assert page.locator('#chart-treat').is_disabled()
    assert page.locator('#treatment-screen').is_hidden()
    for width,height in [(1280,720),(960,600)]:
        page.set_viewport_size(dict(width=width,height=height))
        box = page.locator('.chart-panel').bounding_box()
        assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=width+1 and box['y']+box['height']<=height+1
    old_items = result['treatmentItems']
    result.update(currentInjuries=injuries, treatmentItems={}, vitals=dict(health=0, down=True))
    open_chart()
    assert page.locator('#chart-treat').is_enabled() and page.locator('#chart-revive').is_enabled()
    page.locator('#chart-treat').click()
    assert '道具がありません' in page.locator('#chart-treatment-result').inner_text()
    result.update(currentInjuries=[], treatmentItems=old_items, vitals=dict(health=100, down=False))
    chart.update(archived=True, currentInjuries=injuries)
    open_chart()
    assert page.locator('#chart-treat').inner_text() == '治療\n無効'
    assert page.locator('#chart-bill').inner_text() == '請求\n無効'
    assert page.locator('#chart-revive').inner_text() == '蘇生\n不要'
    assert all(page.locator(f'#chart-{action}').is_disabled() for action in ('treat', 'bill', 'revive'))
    chart.update(currentInjuries=[], invoiceId=123)
    open_chart()
    assert page.locator('#chart-treat').inner_text() == '治療済'
    assert page.locator('#chart-bill').inner_text() == '請求済'
    assert all(page.locator(f'#chart-{action}').is_disabled() for action in ('treat', 'bill'))
    chart.pop('invoiceId')
    chart.update(archived=False, death='死亡', deathCause='餓死（空腹値からの推定）')
    starvation = dict(part='upper_body', body='全身', kind='starvation', severity=1, bleed=0, model='medical')
    chart.update(injuries=[starvation], treated={})
    result.update(canReceiveIV=True, currentInjuries=[starvation], vitals=dict(health=0, hunger=0, thirst=40, stress=50, down=True))
    result['treatmentItems'].append(dict(name='pmediora_ivdrip', label='点滴', count=1))
    result['itemDefinitions']['pmediora_ivdrip'] = dict(label='点滴', ivRecovery=dict(starvation=dict(hunger=20), drowning={}))
    open_chart()
    assert page.locator('#chart-injuries tr').first.locator('td').all_inner_texts()[:2] == ['-', '餓死']
    assert page.locator('#chart-body-map .injured').count() == 0
    assert page.locator('#chart-treat').is_enabled() and page.locator('#chart-revive').is_disabled()
    page.locator('#chart-treat').click()
    assert page.locator('#chart-treatment-injury option').all_text_contents() == ['点滴／餓死']
    iv=page.locator('.treatment-tool[data-kind="pmediora_ivdrip"]').bounding_box()
    head=page.locator('#chart-body-map [data-part="head"]').bounding_box()
    page.mouse.move(iv['x']+15,iv['y']+15)
    page.mouse.down()
    page.mouse.move(head['x']+head['width']/2,head['y']+head['height']/2,steps=10)
    assert page.locator('#chart-body-map .drop-ready').count() == 7
    page.mouse.up()
    assert page.locator('#chart-body-map .drop-ready').count() == 0
    page.wait_for_timeout(150)
    assert any(endpoint=='treatChartInjury' and data['part']=='upper_body' and data['item']=='pmediora_ivdrip'
               for endpoint,data in requests)
    drowning = dict(starvation, kind='drowning')
    chart.update(deathCause='溺死', injuries=[drowning])
    result['currentInjuries'] = [drowning]
    open_chart()
    assert page.locator('#chart-injuries td', has_text='溺死').is_visible()
    assert page.locator('#chart-treatment-injury option').all_text_contents() == ['点滴／溺死']
    chart['treated'] = {'1':True}
    result.update(canReceiveIV=False, currentInjuries=[])
    open_chart()
    assert page.locator('#chart-injuries tr').first.locator('td').all_inner_texts()[:3] == ['-', '溺死', '処置済']
    assert page.locator('#chart-revive').is_enabled()
    assert page.locator('#chart-treatment-injury option[value="upper_body:pmediora_ivdrip"]').count() == 0
    assert not errors, errors
    browser.close()
print('Browser integration passed: layout, matching drag/drop, completed body regions, receipt and billing')
