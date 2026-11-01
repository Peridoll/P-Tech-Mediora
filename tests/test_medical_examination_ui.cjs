const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROMIUM_EXECUTABLE_PATH });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../resources/[ptech]/[mediora]/ptech_mediora_medical/main/ui/index.html')).href);
    const notice = page.locator('#examination-status');
    assert.equal(await notice.isVisible(), false);
    await page.evaluate(() => window.postMessage({ action: 'examination:status', data: { active: true } }, '*'));
    await notice.waitFor({ state: 'visible' });
    assert.equal(await notice.innerText(), '診察されています');
    assert.equal(await page.locator('#app').isVisible(), false);
    assert.equal(await notice.evaluate(element => getComputedStyle(element).pointerEvents), 'none');
    await page.evaluate(() => window.postMessage({ action: 'examination:status', data: { active: false } }, '*'));
    await notice.waitFor({ state: 'hidden' });
    assert.deepEqual(errors, []);
    console.log('Patient diagnosis notice: show, hide and noninteractive display passed.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
