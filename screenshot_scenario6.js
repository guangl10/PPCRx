const puppeteer = require('puppeteer-core');

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0', timeout: 60000 });

  await page.waitForSelector('#landing_btn_parent');
  await page.click('#landing_btn_parent');
  await new Promise((r) => setTimeout(r, 800));

  await page.evaluate(() => {
    const setNum = (id, val) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.value = String(val);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    };
    setNum('age', 15);
    setNum('days_post_injury', 30);
    setNum('previous_pcss', 10);
    setNum('current_pcss', 9);
  });

  await page.click('#calc');
  await new Promise((r) => setTimeout(r, 2500));
  await page.screenshot({
    path: '/home/ubuntu/ppc_rx_app/scenario6_simple_ready.png',
    fullPage: true
  });
  await browser.close();
  console.log('saved scenario6_simple_ready.png');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
