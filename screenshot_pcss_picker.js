const puppeteer = require('puppeteer-core');

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0' });

  await page.click('a[href="#sidebar_panel-progress"], [data-value="progress"]');
  await new Promise((r) => setTimeout(r, 800));

  await page.click('#current_pcss_check_1');
  await new Promise((r) => setTimeout(r, 300));
  await page.click('input[name="current_pcss_score_1"][value="4"]');
  await page.click('#current_pcss_check_2');
  await new Promise((r) => setTimeout(r, 300));
  await page.click('input[name="current_pcss_score_2"][value="3"]');

  await new Promise((r) => setTimeout(r, 1500));

  const totals = await page.evaluate(() => ({
    current: document.getElementById('current_pcss_total_display')?.textContent?.trim(),
    body: document.body.innerText.includes('PCSS Total:')
  }));

  console.log(JSON.stringify(totals, null, 2));
  await page.screenshot({ path: '/home/ubuntu/ppc_rx_app/e2e_reports/progress_pcss_picker.png', fullPage: true });
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
