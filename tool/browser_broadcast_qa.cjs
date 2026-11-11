// Run with Playwright on NODE_PATH, against a locally served build/web.
const fs = require('node:fs');
const { chromium } = require('playwright');

(async () => {
  const base = process.argv[2] || 'http://127.0.0.1:8788';
  const version = await (await fetch(`${base}/version.json`)).json();
  if (version.version !== '1.5.0') throw new Error(`Expected 1.5.0, got ${version.version}`);
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const errors = [];
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
    const save = fs.readFileSync('artifacts/qa/manager-preview-career.json', 'utf8');
    await context.addInitScript(({ save }) => {
      localStorage.setItem('flutter.ftm27_career_v1', JSON.stringify(save));
      localStorage.setItem('flutter.ftm27_lang', JSON.stringify('uz'));
      localStorage.setItem('flutter.darkMode', 'true');
      localStorage.setItem('flutter.ftm27_coins_v1', '1000');
    }, { save });
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(String(e)));
    await page.goto(base);
    await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder, flt-semantics'), { timeout: 30000 });
    const enable = page.locator('flt-semantics-placeholder');
    if (await enable.count()) await enable.evaluate(el => el.click());
    await page.getByRole('button', { name: 'Boshlash', exact: true }).waitFor({ timeout: 30000 });
    await page.screenshot({ path: 'artifacts/qa/browser-dashboard-desktop.png' });
    // CanvasKit semantics containers can overlap their tappable children.
    await page.mouse.click(714, 451);
    await page.waitForTimeout(700);
    await page.screenshot({ path: 'artifacts/qa/browser-start-dialog.png' });
    await page.mouse.click(570, 870);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: 'artifacts/qa/browser-enter-match.png' });
    fs.writeFileSync('artifacts/qa/browser-semantics.txt', await page.locator('body').innerText());
    await page.getByText('Kamera', { exact: true }).waitFor({ timeout: 20000 });
    const frameStats = await page.evaluate(() => new Promise(resolve => {
      const start = performance.now(); let last = start; const frames = [];
      const tick = now => {
        frames.push(now - last); last = now;
        if (now - start < 3000) requestAnimationFrame(tick);
        else resolve({ frames: frames.length, seconds: (now - start) / 1000, maxFrameMs: Math.max(...frames) });
      };
      requestAnimationFrame(tick);
    }));
    await page.screenshot({ path: 'artifacts/qa/browser-match-desktop.png' });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: 'artifacts/qa/browser-match-mobile.png' });
    const result = { version, frameStats, errors, speedControls: 'Visually checked in screenshot; exact rates covered by match_broadcast_test.dart' };
    fs.writeFileSync('artifacts/qa/browser-broadcast-results.json', JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
    if (errors.length) process.exitCode = 1;
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
