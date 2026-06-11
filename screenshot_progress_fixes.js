const puppeteer = require('puppeteer-core');
const path = require('path');

const OUT = '/home/ubuntu/ppc_rx_app/e2e_reports';

async function openProgress(page) {
  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0' });
  await page.click('[data-value="progress"]');
  await new Promise((r) => setTimeout(r, 900));
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', 'window-size=1280,900']
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });

  await openProgress(page);
  await page.screenshot({
    path: path.join(OUT, 'progress_collapsed.png'),
    fullPage: true
  });
  console.log('saved progress_collapsed.png');

  const details = await page.$('.pcss-today-details');
  if (details) {
    await page.evaluate((el) => {
      el.open = true;
    }, details);
  }
  await new Promise((r) => setTimeout(r, 500));
  await page.click('#current_pcss_check_1');
  await new Promise((r) => setTimeout(r, 400));
  await page.click('input[name="current_pcss_score_1"][value="4"]');
  await new Promise((r) => setTimeout(r, 1200));

  await page.screenshot({
    path: path.join(OUT, 'progress_pcss_expanded_headache4.png'),
    fullPage: true
  });
  console.log('saved progress_pcss_expanded_headache4.png');

  const meta = await page.evaluate(() => ({
    inlineTotal: document.getElementById('current_pcss_total_inline')?.textContent?.trim(),
    help: document.querySelector('#pcss_previous_help')?.textContent?.trim(),
    hasOnsetRadio: !!document.getElementById('symptom_onset_range'),
    hasPrevPicker: !!document.getElementById('previous_pcss_check_1')
  }));
  console.log(JSON.stringify(meta, null, 2));

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
