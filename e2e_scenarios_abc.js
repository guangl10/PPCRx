const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const OUT = '/home/ubuntu/ppc_rx_app/e2e_reports';
const BASE = 'http://127.0.0.1:3838/';
const CSV_PATH = '/home/ubuntu/ppc_rx_app/samples/test_log_v02_5sessions.csv';

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function setNum(page, id, val) {
  await page.evaluate((i, v) => {
    const el = document.getElementById(i);
    if (!el) return;
    el.value = String(v);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }, id, val);
}

async function setCheckbox(page, id, checked) {
  await page.evaluate((i, c) => {
    const el = document.getElementById(i);
    if (!el) return;
    el.checked = !!c;
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }, id, checked);
}

async function clickSidebarTab(page, value) {
  await page.evaluate((v) => {
    const link = document.querySelector(`a[data-value="${v}"]`);
    if (link) link.click();
  }, value);
  await sleep(400);
}

async function extractReport(page) {
  return page.evaluate(() => {
    const pick = (sel) => {
      const el = document.querySelector(sel);
      return el ? el.innerText.replace(/\s+/g, ' ').trim() : '(not found)';
    };
    const cardTexts = Array.from(document.querySelectorAll('.card')).map((c) => {
      const hdr = c.querySelector('.card-header');
      const body = c.querySelector('.card-body');
      if (!hdr || !body) return null;
      return {
        header: hdr.innerText.replace(/\s+/g, ' ').trim(),
        body: body.innerText.replace(/\n/g, '\n').trim()
      };
    }).filter(Boolean);

    const sendTo = document.querySelector('#send_to_ui') ||
      Array.from(document.querySelectorAll('.card-body')).find((b) =>
        b.innerText.includes('Copy Parent Message')
      );
    const analytics = document.body.innerText.includes('Analytics')
      ? document.body.innerText.match(/Analytics[\s\S]*?(?=Export \/ import|Send to|$)/)?.[0]
      : null;

    return {
      screen: pick('#screen_display'),
      targetHr: pick('#target_hr_display'),
      fuseStatus: pick('#fuse_status'),
      fuseDetail: pick('#fuse_detail'),
      sendTo: sendTo ? sendTo.innerText.trim() : '(Send to section not visible)',
      bayes: pick('#bayes_recommendation'),
      analyticsVisible: document.body.innerText.includes('Recovery Trend'),
      pcssPlot: !!document.querySelector('#pcss_trend_plot'),
      onsetPlot: !!document.querySelector('#onset_trend_plot'),
      cards: cardTexts,
      pageSnippet: document.body.innerText.slice(0, 8000)
    };
  });
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 1200 });

  const client = await page.createCDPSession();
  await client.send('Page.setDownloadBehavior', {
    behavior: 'allow',
    downloadPath: OUT
  });

  const report = { scenarioA: null, scenarioB: null, scenarioC: null };

  // --- Scenario A ---
  await page.goto(BASE, { waitUntil: 'networkidle0', timeout: 60000 });
  await sleep(1000);

  await clickSidebarTab(page, 'profile');
  await setNum(page, 'age', 16);
  await setNum(page, 'days_post_injury', 35);

  await clickSidebarTab(page, 'prescription');
  await setNum(page, 'hrst', 160);

  await clickSidebarTab(page, 'progress');
  await setNum(page, 'current_pcss', 28);
  await setNum(page, 'previous_pcss', 25);
  await setNum(page, 'current_hr', 128);
  await setNum(page, 'current_duration', 20);
  await page.evaluate(() => {
    const rpe = document.querySelector('#rpe');
    if (rpe) {
      rpe.value = '13';
      rpe.dispatchEvent(new Event('input', { bubbles: true }));
      rpe.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });
  await setCheckbox(page, 'full_session', true);
  await page.evaluate(() => {
    const rb = document.querySelector('input[name="post_symptom_severity"][value="0"]');
    if (rb) { rb.checked = true; rb.dispatchEvent(new Event('change', { bubbles: true })); }
  });

  await page.click('#calc');
  await sleep(3500);
  await page.screenshot({ path: path.join(OUT, 'scenario_A_after_calc.png'), fullPage: true });
  report.scenarioA = await extractReport(page);

  // --- Scenario B: upload CSV ---
  const uploadInput = await page.$('input[type="file"]#upload_log');
  if (uploadInput) {
    await uploadInput.uploadFile(CSV_PATH);
    await sleep(2500);
  } else {
    report.scenarioB = { error: 'upload_log file input not found' };
  }
  await page.screenshot({ path: path.join(OUT, 'scenario_B_after_upload.png'), fullPage: true });
  report.scenarioB = await extractReport(page);

  // --- Scenario C: reset + fuse ---
  await page.click('#reset');
  await sleep(1500);

  await clickSidebarTab(page, 'profile');
  await setNum(page, 'age', 16);
  await setNum(page, 'days_post_injury', 35);
  await clickSidebarTab(page, 'prescription');
  await setNum(page, 'hrst', 160);
  await clickSidebarTab(page, 'progress');
  await setNum(page, 'current_pcss', 28);
  await setNum(page, 'previous_pcss', 24);
  await setNum(page, 'current_hr', 128);
  await setNum(page, 'current_duration', 15);
  await page.evaluate(() => {
    const rpe = document.querySelector('#rpe');
    if (rpe) { rpe.value = '16'; rpe.dispatchEvent(new Event('change', { bubbles: true })); }
  });
  await setCheckbox(page, 'full_session', false);
  await setNum(page, 'symptom_onset_min', 12);
  await page.evaluate(() => {
    const rb = document.querySelector('input[name="post_symptom_severity"][value="1"]');
    if (rb) { rb.checked = true; rb.dispatchEvent(new Event('change', { bubbles: true })); }
  });

  await page.click('#calc');
  await sleep(3500);
  await page.screenshot({ path: path.join(OUT, 'scenario_C_fuse.png'), fullPage: true });
  report.scenarioC = await extractReport(page);

  const copyDisabled = await page.evaluate(() => {
    const p = document.querySelector('#copy_parent_msg');
    const a = document.querySelector('#copy_athlete_msg');
    return {
      parentExists: !!p,
      athleteExists: !!a,
      parentDisabled: p ? p.disabled : null,
      athleteDisabled: a ? a.disabled : null
    };
  });
  report.scenarioC.copyButtons = copyDisabled;

  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
