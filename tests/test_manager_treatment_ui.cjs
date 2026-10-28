// Requires Playwright, pngjs and Chromium: node tests/test_manager_treatment_ui.cjs
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');
const { PNG } = require('pngjs');

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROMIUM_EXECUTABLE_PATH });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => {
      window.GetParentResourceName = () => 'ptech_mediora_manager';
      window.requests = [];
      window.supplies = { items: [
        { name: 'ice', label: '医療キット：打撲処置', uiLabel: '医療キット\n打撲', treatment: 'beat', count: 5 },
        { name: 'burn', label: '医療キット：熱傷処置', treatment: 'burned', count: 2 },
      ] };
      window.chartResult = {
        patient: { serverId: 7, name: '<img src=x onerror=alert(1)> 患者' },
        charts: [
          { chartId: 'recent', issuedAt: '2026-10-23T01:00:00Z', examinerName: '担当医', injuries: [
            { part: 'head', kind: 'beat', severity: 1, bleed: 0 },
            { part: 'left_arm', kind: 'beat', severity: 1, bleed: 0 },
            { part: 'left_arm', kind: 'burned', severity: 3, bleed: 1 },
            { part: 'right_leg', kind: 'beat', severity: 2, bleed: 0 },
            { part: 'right_leg', kind: 'burned', severity: 4, treated: true },
            { part: 'left_leg', kind: 'beat', severity: 3, treated: true },
          ] },
          { chartId: 'old', issuedAt: '2026-10-22T01:00:00Z', examinerName: '別の医師', injuries: [
            { part: 'head', kind: 'shot', severity: 4, bleed: 2 },
            { part: 'upper_body', kind: 'beat', severity: 2, bleed: 0 },
            { part: 'lower_body', kind: 'stabbed', severity: 3, bleed: 1 },
          ] },
          ...Array.from({ length: 15 }, (_, i) => ({ chartId: 'extra-' + i, injuries: [{ part: 'head', kind: 'beat' }] })),
        ],
      };
      window.fetch = async (url, options) => {
        const data = JSON.parse(options.body);
        window.requests.push({ url, data });
        return { json: async () => url.endsWith('/getCharts') ? window.chartResult : url.endsWith('/getTreatmentSupplies') ? window.supplies
          : url.endsWith('/setPatientView') ? { active: data.active, message: data.active ? '患者本人を表示中' : '' } : { ok: true } };
      };
    });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../resources/[ptech]/[mediora]/ptech_mediora_manager/main/ui/index.html')).href);
    if (process.env.MEDIORA_TEST_FONT_CSS) {
      const fontPath = process.env.MEDIORA_TEST_FONT_CSS;
      const css = fs.readFileSync(fontPath, 'utf8').replace(/url\(\.\/([^)]*)\)/g, (_, rel) => 'url(' + pathToFileURL(path.resolve(path.dirname(fontPath), rel)).href + ')');
      await page.addStyleTag({ content: css });
    }
    assert.equal(await page.locator('#tablet').isVisible(), false);
    await page.evaluate(() => window.postMessage({ action: 'open', data: { page: 'charts', targetId: 7 } }, '*'));
    await page.locator('#open-treatment').click();
    await page.waitForFunction(() => document.querySelectorAll('.treatment-supply').length === 2);
    await page.waitForFunction(() => document.querySelector('.patient-view').classList.contains('is-live'));
    assert.match(await page.locator('#view-patient-name').innerText(), /患者/);
    assert.equal(await page.locator('#home-page').isVisible(), false);
    assert.equal(await page.locator('#charts-page').isVisible(), false);
    assert.equal(await page.locator('#treatment-page').isVisible(), true);
    assert.equal(await page.locator('.body-part[data-part="head"]').getAttribute('data-status'), 'injured');
    assert.equal(await page.locator('.body-part[data-part="left_arm"]').getAttribute('data-status'), 'injured');
    assert.equal(await page.locator('.body-part[data-part="right_leg"]').getAttribute('data-status'), 'injured');
    assert.equal(await page.locator('.body-part[data-part="left_leg"]').getAttribute('data-status'), 'unrelated');
    assert.deepEqual(await page.locator('.body-part').evaluateAll(elements => elements.map(element => element.dataset.part)),
      ['head', 'upper_body', 'lower_body', 'left_arm', 'right_arm', 'left_leg', 'right_leg']);
    assert.equal(await page.locator('.body-part[data-part="upper_body"]').getAttribute('data-status'), 'unrelated');
    assert.equal(await page.locator('.body-part[data-part="upper_body"]').isDisabled(), true);
    assert.equal(await page.locator('.treatment-injury').count(), 6);
    assert.match(await page.locator('#wound-summary').innerText(), /未治療 4件/);
    const mapColors = await page.locator('.body-part[data-status="injured"]').evaluateAll(elements => elements.map(element => getComputedStyle(element).backgroundColor));
    assert.equal(new Set(mapColors).size, 1);
    assert.equal(mapColors[0], 'rgb(204, 74, 83)');
    assert.equal(await page.locator('.treatment-injury[data-index="0"]').getAttribute('data-status'), 'mild');
    assert.equal(await page.locator('.treatment-injury[data-index="3"]').getAttribute('data-status'), 'moderate');
    assert.equal(await page.locator('.treatment-injury[data-index="4"]').getAttribute('data-status'), 'treated');
    await page.locator('.body-part[data-part="left_arm"]').click();
    assert.equal(await page.locator('.treatment-injury').count(), 6, 'body selection must not hide other wounds');
    assert.equal(await page.locator('.treatment-injury.selected').getAttribute('data-part'), 'left_arm');
    await page.locator('.treatment-injury[data-index="2"]').click();
    assert.match(await page.locator('#treatment-selection').innerText(), /熱傷/);
    assert.equal(await page.locator('.treatment-injury.selected').count(), 1);
    assert.equal(await page.locator('.body-part.selected').getAttribute('data-part'), 'left_arm');
    assert.match(await page.locator('#treatment-selection').innerText(), /所持数：2/);
    await page.evaluate(() => window.postMessage({ action: 'treatment:supplies', data: { items: [] } }, '*'));
    await page.waitForFunction(() => document.querySelectorAll('.treatment-supply').length === 0);
    assert.match(await page.locator('#treatment-selection').innerText(), /所持数：0/);
    await page.evaluate(() => window.postMessage({ action: 'treatment:supplies', data: { error: '所持数取得失敗' } }, '*'));
    await page.waitForFunction(() => document.getElementById('supply-notice').textContent === '所持数取得失敗');
    assert.match(await page.locator('#treatment-selection').innerText(), /所持数：未取得/);
    await page.locator('#refresh-supplies').click();
    await page.waitForFunction(() => document.querySelectorAll('.treatment-supply').length === 2);
    assert.match(await page.locator('.supply-count').first().innerText(), /5/);
    assert.equal(await page.locator('#treatment-patient-name img').count(), 0);
    assert.equal(await page.locator('#view-patient-name img').count(), 0);
    assert.equal(await page.locator('#treatment-total').innerText(), '0 円');
    for (const viewport of [{ width: 1920, height: 1080 }, { width: 1280, height: 720 }]) {
      await page.setViewportSize(viewport);
      assert.equal(await page.evaluate(() => {
        const center = document.querySelector('.patient-view').getBoundingClientRect();
        const screen = document.querySelector('.screen').getBoundingClientRect();
        const map = document.querySelector('#body-map').getBoundingClientRect();
        const list = document.querySelector('.injury-list-card').getBoundingClientRect();
        return center.width > 200 && screen.width < innerWidth && screen.height < innerHeight
          && getComputedStyle(document.querySelector('.screen')).borderTopWidth === '12px'
          && map.right < center.left && list.left > center.right && map.height < 230
          && [...document.querySelectorAll('.clinical-card')].every(card => card.getBoundingClientRect().bottom <= screen.bottom);
      }), true);
      const transparent = PNG.sync.read(await page.screenshot({ omitBackground: true }));
      const centerPixel = (Math.floor(viewport.height / 2) * viewport.width + Math.floor(viewport.width / 2)) * 4;
      assert(transparent.data[centerPixel + 3] > 0 && transparent.data[centerPixel + 3] < 50, 'tablet glass must leave the patient clearly visible');
    }
    const scrollable = await page.locator('#treatment-chart-list').evaluate(element => element.scrollHeight > element.clientHeight);
    assert.equal(scrollable, true);
    await page.locator('#treatment-chart-list [data-chart-id="old"]').click();
    assert.equal(await page.locator('.body-part[data-part="head"]').getAttribute('data-status'), 'injured');
    assert.equal(await page.locator('.body-part[data-part="left_arm"]').getAttribute('data-status'), 'unrelated');
    assert.equal(await page.locator('.treatment-injury').count(), 3);
    for (const [part, label] of [['upper_body', '上半身'], ['lower_body', '下半身']]) {
      const button = page.locator(`.body-part[data-part="${part}"]`);
      assert.equal(await button.getAttribute('data-status'), 'injured');
      await button.click();
      assert.equal(await page.locator('.treatment-injury.selected').getAttribute('data-part'), part);
      assert.equal(await page.locator('#treatment-part-name').innerText(), `${label}の詳細`);
      assert.equal(await button.getAttribute('aria-label'), `${label}：未治療 1件`);
    }
    await page.evaluate(() => window.postMessage({ action: 'treatment:supplies', data: { items: [] } }, '*'));
    await page.waitForFunction(() => document.querySelectorAll('.treatment-supply').length === 0);
    assert.match(await page.locator('#treatment-supply-list').innerText(), /所持していません/);
    await page.locator('#back-charts').click();
    assert(await page.evaluate(() => window.requests.some(request => request.url.endsWith('/setPatientView') && request.data.active === false)));
    assert.equal(await page.locator('.screen').evaluate(el => getComputedStyle(el).borderTopWidth), '14px');
    assert.match(await page.locator('#chart-detail').innerText(), /別の医師/);
    await page.locator('#open-treatment').click();
    await page.evaluate(() => document.getElementById('treatment-patient-name').textContent = document.getElementById('body-patient-name').textContent = document.getElementById('view-patient-name').textContent = '山田 太郎');
    await page.evaluate(() => window.postMessage({ action: 'patientView:status', data: { active: false, message: '患者が離れました' } }, '*'));
    await page.waitForFunction(() => !document.querySelector('.patient-view').classList.contains('is-live'));
    assert.match(await page.locator('#patient-view-status').innerText(), /患者が離れました/);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: '/tmp/mediora-treatment-1280.png', omitBackground: true });
    await page.evaluate(() => window.postMessage({ action: 'close' }, '*'));
    await page.waitForFunction(() => document.getElementById('tablet').hidden);
    assert.equal(await page.locator('#tablet').isVisible(), false);
    assert.deepEqual(errors, []);
    console.log('Treatment UI: navigation, multiple wounds, severity, supplies, transparency, scrolling and responsive layout passed.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
