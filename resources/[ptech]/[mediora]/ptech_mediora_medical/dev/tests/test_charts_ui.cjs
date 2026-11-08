'use strict';
// 実際のHTML/JSをChromiumで開く。FiveMのNUI応答だけを置き換える。
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require('playwright');
const ui = path.resolve(__dirname, '../../main/ui');
const fontRoot = process.env.MEDICAL_TEST_FONT_ROOT;
const chart = (id, severity = 2) => ({
  chartId: id, issuedAt: '2026-11-02T12:00:00Z', examinerName: '診察者 ' + id,
  death: '死亡・瀕死フラグなし', observationStatus: 'クライアント観察記録',
  injuries: [{ part: 'left_arm', kind: 'beat', severity, bleed: 1 }],
});
const records = {
  2: { patient: {serverId: 2, name: '患者 二郎'}, charts: [chart('new'), chart('old', 4)] },
  3: { patient: {serverId: 3, name: '患者 三郎'}, charts: [] },
  4: { error: '勤務中の医療職のみ利用できます' },
  5: { patient: {serverId: 5, name: '<img src=x onerror="window.injected=true">'}, charts: [chart('safe')] },
};

async function main() {
  const server = http.createServer((req, res) => {
    const name = decodeURIComponent(req.url.split('?')[0]);
    const root = name.startsWith('/fonts/') ? fontRoot : ui;
    const file = path.resolve(root || ui, '.' + (name.startsWith('/fonts/') ? name.slice(6) : name));
    if (!root || !file.startsWith(root + path.sep) || !fs.existsSync(file)) { res.writeHead(404).end(); return; }
    const types = {'.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.woff2': 'font/woff2'};
    res.writeHead(200, {'Content-Type': types[path.extname(file)] || 'application/octet-stream'});
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: process.env.CHROMIUM_EXECUTABLE_PATH || undefined,
      headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });
    const page = await browser.newPage({viewport: {width: 1280, height: 720}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => { window.GetParentResourceName = () => 'ptech_mediora_medical'; });
    let searches = [], delayed;
    await page.route('https://ptech_mediora_medical/**', async route => {
      const data = route.request().postDataJSON();
      let result;
      if (route.request().url().endsWith('/getCharts')) {
        searches.push(data.targetId);
        if (data.targetId === 99) { delayed = route; return; }
        result = records[data.targetId] || {error: 'そのIDのプレイヤーは現在接続していません'};
      } else {
        result = {ok: true};
        await page.evaluate(action => {
          if (action === 'close') window.postMessage({action: 'close'}, '*');
          if (action === 'charts') window.postMessage({action: 'charts:open', data: {targetId: 2}}, '*');
        }, data.action);
      }
      await route.fulfill({json: result});
    });
    await page.goto('http://127.0.0.1:' + server.address().port + '/index.html');
    if (fontRoot) {
      await page.addStyleTag({url: 'http://127.0.0.1:' + server.address().port + '/fonts/japanese-400.css'});
      await page.addStyleTag({content: "body{font-family:'Noto Sans JP',sans-serif}"});
    }
    const message = async (action, data) => page.evaluate(payload => window.postMessage(payload, '*'), {action, data});
    const hidden = id => page.locator('#' + id).isHidden();
    const contains = async (id, value) => assert((await page.locator('#' + id).innerText()).includes(value));
    const waitPatient = name => page.waitForFunction(name => document.querySelector('#chart-patient-name').textContent === name && !document.querySelector('#chart-patient').hidden, name);
    const search = async id => {
      await page.locator('#chart-patient-id').fill(String(id));
      await page.locator('#chart-search').evaluate(form => form.requestSubmit());
    };
    assert(await hidden('app') && await hidden('chart-app') && await hidden('examination-status'));
    await message('examination:status', {active: true});
    await page.locator('#examination-status').waitFor({state: 'visible'});
    assert(await hidden('chart-app'));
    await message('charts:open', {targetId: 2, chartId: 'old'});
    await waitPatient('患者 二郎');
    assert.equal(await page.locator('#chart-patient-id').inputValue(), '2');
    assert.equal(await page.locator('.chart-choice').count(), 2);
    await contains('chart-examiner', 'old');
    await contains('chart-injuries', '最重度');
    await page.locator('.chart-choice').first().click();
    await contains('chart-examiner', 'new');
    await contains('chart-injuries', '左腕');
    assert(await hidden('app'));
    await search(3);
    await waitPatient('患者 三郎');
    await contains('chart-notice', 'カルテはありません');
    assert(await hidden('chart-detail'));
    await search(4);
    await page.waitForFunction(() => document.querySelector('#chart-notice').textContent.includes('勤務中'));
    assert(await hidden('chart-patient') && await hidden('chart-detail'));
    const before = searches.length;
    await page.locator('#chart-patient-id').fill('-1');
    await page.locator('#chart-search').evaluate(form => form.dispatchEvent(new Event('submit', {cancelable: true})));
    await contains('chart-notice', '正の整数');
    assert.equal(searches.length, before);
    await search(5);
    await waitPatient(records[5].patient.name);
    assert.equal(await page.locator('#chart-patient-name img').count(), 0);
    assert.equal(await page.evaluate(() => window.injected), undefined);
    await search(99);
    await page.waitForFunction(() => document.querySelector('#chart-notice').textContent.includes('取得しています'));
    await search(2);
    await waitPatient('患者 二郎');
    await delayed.fulfill({json: records[3]}).catch(() => {});
    await contains('chart-patient-name', '患者 二郎');
    await search(99);
    await page.waitForFunction(() => document.querySelector('#chart-notice').textContent.includes('取得しています'));
    await page.keyboard.press('Escape');
    await page.locator('#chart-app').waitFor({state: 'hidden'});
    await delayed.fulfill({json: records[2]}).catch(() => {});
    assert(await hidden('chart-app'));
    // 形式エラー画面から既存カルテへ移動できる。
    await message('open', {mode: 'unsupported', title: '診察 — ID 2', details: 'injuries.raw: test', canOpenCharts: true});
    await page.locator('#raw summary').click();
    await contains('raw-text', 'injuries.raw: test');
    await page.locator('#open-charts').click();
    await waitPatient('患者 二郎');
    // 長い一覧・詳細でもパネルと閉じるボタンが画面内に収まる。
    records[2].charts = Array.from({length: 35}, (_, i) => ({...chart(String(i)), injuries: [
      ...['head', 'upper_body', 'lower_body', 'left_arm', 'right_arm', 'left_leg', 'right_leg']
        .map(part => ({part, kind: 'shot', severity: 3, bleed: 2})),
    ]}));
    for (const viewport of [{width:1280,height:720}, {width:1920,height:1080}]) {
      await page.setViewportSize(viewport);
      await message('charts:open', {targetId: 2});
      await page.waitForFunction(() => document.querySelectorAll('.chart-choice').length === 35);
      const box = await page.locator('.chart-panel').boundingBox();
      assert(box.x >= 0 && box.y >= 0 && box.x + box.width <= viewport.width && box.y + box.height <= viewport.height);
      const closeBox = await page.locator('#close-charts-bottom').boundingBox();
      assert(closeBox.y + closeBox.height <= viewport.height);
      assert.equal(await page.locator('#chart-injuries .injury-card').count(), 7);
      assert(await page.locator('.chart-list').evaluate(el => el.scrollHeight > el.clientHeight));
      assert(await page.locator('.chart-content').evaluate(el => el.scrollHeight > el.clientHeight));
      if (process.env.MEDICAL_TEST_SCREENSHOT) await page.screenshot({path: process.env.MEDICAL_TEST_SCREENSHOT + '-' + viewport.width + '.png'});
    }
    await message('close');
    await page.locator('#chart-app').waitFor({state:'hidden'});
    await message('examination:status', {active:false});
    await page.locator('#examination-status').waitFor({state:'hidden'});
    assert.deepEqual(errors, []);
    console.log('PASS: chart search / selection / permissions / empty / invalid ID / XSS / stale response / close / raw-data entry / 7 parts / 720p and 1080p layout');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
