const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const datasets = [
  'revised_dataset1_fast_recovery.csv',
  'revised_dataset2_plateau.csv',
  'revised_dataset3_breakthrough.csv',
  'revised_dataset4a_fast.csv',
  'revised_dataset4b_slow.csv'
];

(async () => {
  const outDir = path.join(__dirname, 'e2e_reports', 'revised_charts');
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 1200 });

  for (const csv of datasets) {
    const csvPath = path.join(__dirname, 'samples', csv);
    await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0', timeout: 60000 });

    await page.waitForSelector('#calc', { timeout: 15000 });
    await page.click('#calc');
    await new Promise((r) => setTimeout(r, 2000));

    const input = await page.$('#upload_log');
    if (!input) throw new Error('upload_log not found');
    await input.uploadFile(csvPath);
    await new Promise((r) => setTimeout(r, 3500));

    const base = csv.replace('.csv', '');
    await page.evaluate(() => {
      const h = document.querySelector('.card-header');
      const cards = [...document.querySelectorAll('.card')];
      const analytics = cards.find((c) => c.textContent.includes('Analytics'));
      if (analytics) analytics.scrollIntoView({ block: 'start' });
    });
    await new Promise((r) => setTimeout(r, 800));
    await page.screenshot({
      path: path.join(outDir, `${base}_analytics.png`),
      fullPage: false
    });

    const bayes = await page.evaluate(() => {
      const alerts = [...document.querySelectorAll('.alert')];
      const guidance = alerts.find((a) =>
        a.textContent.includes('athlete') || a.textContent.includes('RPE') || a.textContent.includes('Building')
      );
      return guidance ? guidance.textContent.trim() : '';
    });
    console.log(base, '|', bayes.slice(0, 120));
  }

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
