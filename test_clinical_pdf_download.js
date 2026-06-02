const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

(async () => {
  const outPdf = '/home/ubuntu/ppc_rx_app/samples/shiny_downloaded_prescription.pdf';
  const browser = await puppeteer.launch({
    executablePath: '/snap/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 900 });

  const client = await page.createCDPSession();
  await client.send('Page.setDownloadBehavior', {
    behavior: 'allow',
    downloadPath: '/home/ubuntu/ppc_rx_app/samples'
  });

  await page.goto('http://127.0.0.1:3838/', { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('#landing_btn_at');
  await page.click('#landing_btn_at');
  await new Promise((r) => setTimeout(r, 1000));

  await page.evaluate(() => {
    const setNum = (id, val) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.value = String(val);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    };
    setNum('age', 16);
    setNum('days_post_injury', 35);
    setNum('hrst', 160);
    setNum('previous_pcss', 25);
    setNum('current_pcss', 23);
    setNum('current_hr', 128);
    setNum('current_duration', 20);
  });

  await page.click('#calc');
  await new Promise((r) => setTimeout(r, 3000));

  const btnVisible = await page.evaluate(() => {
    const btn = document.querySelector('#download_pdf');
    if (!btn) return { exists: false, visible: false, text: null };
    const rect = btn.getBoundingClientRect();
    const style = window.getComputedStyle(btn);
    return {
      exists: true,
      visible: rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden',
      text: btn.innerText.trim()
    };
  });

  await page.screenshot({
    path: '/home/ubuntu/ppc_rx_app/clinical_after_calc_with_pdf_btn.png',
    fullPage: true
  });

  if (!btnVisible.exists) {
    console.log(JSON.stringify({ ok: false, step: 'button_missing', btnVisible }, null, 2));
    await browser.close();
    process.exit(1);
  }

  const beforeFiles = fs.readdirSync('/home/ubuntu/ppc_rx_app/samples');
  await page.click('#download_pdf');
  await new Promise((r) => setTimeout(r, 8000));

  const afterFiles = fs.readdirSync('/home/ubuntu/ppc_rx_app/samples');
  const newFiles = afterFiles.filter((f) => !beforeFiles.includes(f) && f.endsWith('.pdf'));
  const crdownload = afterFiles.find((f) => f.endsWith('.crdownload'));

  let downloaded = newFiles[0];
  if (!downloaded) {
    const candidates = afterFiles
      .filter((f) => f.endsWith('.pdf') && f.includes('PPCSexRx'))
      .map((f) => ({ f, m: fs.statSync(path.join('/home/ubuntu/ppc_rx_app/samples', f)).mtimeMs }))
      .sort((a, b) => b.m - a.m);
    downloaded = candidates[0]?.f;
  }

  let downloadOk = false;
  let pdfSize = 0;
  let pdfHeader = '';
  if (downloaded) {
    const full = path.join('/home/ubuntu/ppc_rx_app/samples', downloaded);
    fs.renameSync(full, outPdf);
    pdfSize = fs.statSync(outPdf).size;
    pdfHeader = fs.readFileSync(outPdf, { encoding: 'latin1', start: 0, end: 8 });
    downloadOk = pdfHeader.startsWith('%PDF-');
  }

  console.log(JSON.stringify({
    ok: btnVisible.visible && downloadOk,
    btnVisible,
    downloadedFile: downloaded || null,
    outPdf,
    pdfSize,
    pdfHeader,
    crdownload: crdownload || null,
    newFiles
  }, null, 2));

  await browser.close();
  process.exit(btnVisible.visible && downloadOk ? 0 : 1);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
