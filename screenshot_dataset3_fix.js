const puppeteer = require('puppeteer-core');
const path = require('path');

(async () => {
  const csvPath = path.join(__dirname, 'samples', 'revised_dataset3_breakthrough.csv');
  const outPath = path.join(__dirname, 'e2e_reports', 'revised_charts', 'dataset3_after_fix_analytics.png');

  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 1100 });
  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('#calc');
  await page.click('#calc');
  await new Promise((r) => setTimeout(r, 2000));
  const input = await page.$('#upload_log');
  await input.uploadFile(csvPath);
  await new Promise((r) => setTimeout(r, 3500));
  await page.evaluate(() => {
    const cards = [...document.querySelectorAll('.card')];
    const analytics = cards.find((c) => c.textContent.includes('Analytics'));
    if (analytics) analytics.scrollIntoView({ block: 'start' });
  });
  await new Promise((r) => setTimeout(r, 800));
  await page.screenshot({ path: outPath, fullPage: false });

  const report = await page.evaluate(() => {
    const plot = document.querySelector('#pcss_trend_plot');
    const details = document.querySelector('details');
    const rpeColors = [];
    if (plot) {
      const pts = plot.querySelectorAll('.scatterpts .point');
      pts.forEach((pt) => rpeColors.push(pt.getAttribute('fill') || pt.style.fill));
    }
    return {
      hasPlot: !!plot,
      evidenceNote: details ? details.textContent.includes('protocol changes') : false,
      legendText: plot ? plot.textContent : ''
    };
  });
  console.log(JSON.stringify(report, null, 2));
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
