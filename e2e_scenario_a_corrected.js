const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const OUT = '/home/ubuntu/ppc_rx_app/e2e_reports';
const BASE = 'http://127.0.0.1:3838/';

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

async function clickTab(page, value) {
  await page.evaluate((v) => {
    document.querySelector(`a[data-value="${v}"]`)?.click();
  }, value);
  await sleep(400);
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

  await page.goto(BASE, { waitUntil: 'networkidle0', timeout: 60000 });
  await sleep(1000);

  await clickTab(page, 'profile');
  await setNum(page, 'age', 16);
  await setNum(page, 'days_post_injury', 35);

  await clickTab(page, 'prescription');
  await setNum(page, 'hrst', 160);

  await clickTab(page, 'progress');
  await setNum(page, 'current_pcss', 23);
  await setNum(page, 'previous_pcss', 25);
  await setNum(page, 'current_hr', 128);
  await setNum(page, 'current_duration', 20);
  await page.evaluate(() => {
    const rpe = document.getElementById('rpe');
    if (rpe) {
      rpe.value = '13';
      rpe.dispatchEvent(new Event('input', { bubbles: true }));
      rpe.dispatchEvent(new Event('change', { bubbles: true }));
    }
    const fs = document.getElementById('full_session');
    if (fs) {
      fs.checked = true;
      fs.dispatchEvent(new Event('change', { bubbles: true }));
    }
    const rb = document.querySelector('input[name="post_symptom_severity"][value="0"]');
    if (rb) {
      rb.checked = true;
      rb.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });
  await sleep(300);
  await setNum(page, 'symptom_onset_min', 20);

  await page.click('#calc');
  await sleep(3500);

  await page.screenshot({
    path: path.join(OUT, 'scenario_A_corrected.png'),
    fullPage: true
  });

  const extracted = await page.evaluate(() => {
    const cardByHeader = (hdr) => {
      const cards = Array.from(document.querySelectorAll('.card'));
      for (const c of cards) {
        const h = c.querySelector('.card-header');
        if (h && h.innerText.includes(hdr)) {
          return c.querySelector('.card-body')?.innerText?.trim() || '';
        }
      }
      return '(not found)';
    };

    const quickStart = cardByHeader('Quick start');
    const screening = document.querySelector('#screen_display')?.innerText?.trim() || cardByHeader('Screening');
    const targetHr = document.querySelector('#target_hr_display')?.innerText?.trim() || cardByHeader('Target heart rate');
    const fuseStatus = document.querySelector('#fuse_status')?.innerText?.trim() || '';
    const fuseDetail = document.querySelector('#fuse_detail')?.innerText?.trim() || '';
    const fuseCard = cardByHeader('Safety fuse');

    const atField = document.querySelector('#at_name');
    const parentBtn = document.querySelector('#copy_parent_msg');
    const athleteBtn = document.querySelector('#copy_athlete_msg');
    const sendToHint = document.querySelector('.alert-warning')?.innerText?.trim() || null;

    return {
      quickStart,
      screening,
      targetHr,
      fuseStatus,
      fuseDetail,
      fuseCard,
      sendTo: {
        hint: sendToHint,
        atNameLabel: atField?.labels?.[0]?.innerText || 'Your name (for messages):',
        atNameValue: atField?.value ?? '',
        parentButton: parentBtn?.innerText?.trim() || '(missing)',
        athleteButton: athleteBtn?.innerText?.trim() || '(missing)',
        parentDisabled: parentBtn?.disabled ?? null,
        athleteDisabled: athleteBtn?.disabled ?? null
      }
    };
  });

  // Copy parent message via clipboard read after click
  await page.evaluate(() => {
    document.querySelector('#at_name').value = 'Coach Li';
    document.querySelector('#at_name').dispatchEvent(new Event('input', { bubbles: true }));
  });

  await page.click('#copy_parent_msg');
  await sleep(500);

  const parentMsg = await page.evaluate(async () => {
    try {
      return await navigator.clipboard.readText();
    } catch (e) {
      return '__CLIPBOARD_READ_FAILED__';
    }
  });

  await page.click('#copy_athlete_msg');
  await sleep(500);

  const athleteMsg = await page.evaluate(async () => {
    try {
      return await navigator.clipboard.readText();
    } catch (e) {
      return '__CLIPBOARD_READ_FAILED__';
    }
  });

  let parentText = parentMsg;
  let athleteText = athleteMsg;

  if (parentMsg === '__CLIPBOARD_READ_FAILED__' || athleteMsg === '__CLIPBOARD_READ_FAILED__') {
    // Fallback: call R-equivalent via page - use Shiny message handler simulation
    parentText = '(clipboard unavailable in headless; see R fallback below)';
    athleteText = '(clipboard unavailable in headless; see R fallback below)';
  }

  const report = { extracted, parentMessage: parentText, athleteMessage: athleteText };
  fs.writeFileSync(path.join(OUT, 'scenario_A_corrected_report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
