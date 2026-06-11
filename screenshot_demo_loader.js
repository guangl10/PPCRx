const puppeteer = require('puppeteer-core');
const path = require('path');

(async () => {
  const outPath = path.join(__dirname, 'e2e_reports', 'demo_loader_dataset3.png');
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 1200 });
  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('#calc');
  await page.click('#calc');
  await new Promise((r) => setTimeout(r, 2500));

  await page.select('#demo_dataset', 'dataset3_breakthrough');
  await page.click('#load_demo');
  await new Promise((r) => setTimeout(r, 3000));

  const checks = await page.evaluate(() => {
    const toast = document.body.innerText.includes('Demo data loaded');
    const analytics = document.body.innerText.includes('Analytics');
    const hrLegend = document.body.innerText.includes('Prescribed HR target');
    const bayes = document.body.innerText.includes('exceeds the published');
    return { toast, analytics, hrLegend, bayes };
  });

  await page.evaluate(() => {
    const cards = [...document.querySelectorAll('.card')];
    const analytics = cards.find((c) => c.textContent.includes('Analytics'));
    if (analytics) analytics.scrollIntoView({ block: 'start' });
  });
  await new Promise((r) => setTimeout(r, 800));
  await page.screenshot({ path: outPath, fullPage: false });

  console.log(JSON.stringify(checks, null, 2));
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
