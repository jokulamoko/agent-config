import { chromium } from 'playwright';
import fs from 'node:fs';

const argv = process.argv.slice(2);
const flags = {};
const positional = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--width') flags.width = parseInt(argv[++i]);
  else if (a === '--height') flags.height = parseInt(argv[++i]);
  else if (a === '--selector') flags.selector = argv[++i];
  else if (a === '--full-page') flags.fullPage = true;
  else if (a === '--wait') flags.wait = parseInt(argv[++i]);
  else if (a === '--styles') flags.styles = argv[++i];
  else if (a === '--base') flags.base = argv[++i];
  else if (a === '--steps') flags.steps = argv[++i];
  else positional.push(a);
}

const base = flags.base || 'http://127.0.0.1:9292';
const width = flags.width || 1280;
const height = flags.height || 800;

const resolveUrl = (target) =>
  !target || target.startsWith('http')
    ? (target || base)
    : `${base}${target.startsWith('/') ? '' : '/'}${target}`;

const loadSteps = (raw) => {
  const text = raw.startsWith('@') ? fs.readFileSync(raw.slice(1), 'utf8') : raw;
  const parsed = JSON.parse(text);
  return Array.isArray(parsed) ? parsed : [parsed];
};

const captureStyles = async (page, selectorList) => {
  const selectors = selectorList.split(',').map((s) => s.trim());
  const results = await page.evaluate((sels) => sels.map((sel) => {
    const el = document.querySelector(sel);
    if (!el) return { selector: sel, error: 'not found' };
    const cs = getComputedStyle(el);
    return {
      selector: sel,
      tag: el.tagName.toLowerCase(),
      styles: {
        padding: cs.padding, margin: cs.margin,
        fontSize: cs.fontSize, fontFamily: cs.fontFamily, fontWeight: cs.fontWeight,
        color: cs.color, backgroundColor: cs.backgroundColor,
        borderRadius: cs.borderRadius, boxShadow: cs.boxShadow,
        display: cs.display, gap: cs.gap, width: cs.width, height: cs.height,
        letterSpacing: cs.letterSpacing, textTransform: cs.textTransform,
      },
    };
  }), selectors);
  console.log('Computed styles:');
  console.log(JSON.stringify(results, null, 2));
};

const screenshot = async (page, { screenshot: out, selector, fullPage }) => {
  if (selector) {
    const el = await page.$(selector);
    if (el) { await el.screenshot({ path: out }); }
    else {
      console.error(`selector "${selector}" not found — capturing full page`);
      await page.screenshot({ path: out, fullPage: fullPage !== false });
    }
  } else {
    await page.screenshot({ path: out, fullPage: fullPage || false });
  }
  console.log(`screenshot ${out}`);
};

const runStep = async (page, step) => {
  const t = step.optional ? 3000 : 15000;
  if ('goto' in step) {
    const url = resolveUrl(step.goto);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    console.log(`goto ${url}`);
  } else if ('click' in step) {
    await page.locator(step.click).first().click({ timeout: t });
    console.log(`click ${step.click}`);
  } else if ('fill' in step) {
    await page.locator(step.fill).first().fill(step.text ?? '', { timeout: t });
    console.log(`fill ${step.fill}`);
  } else if ('press' in step) {
    if (step.selector) await page.locator(step.selector).first().press(step.press, { timeout: t });
    else await page.keyboard.press(step.press);
    console.log(`press ${step.press}`);
  } else if ('hover' in step) {
    await page.locator(step.hover).first().hover({ timeout: t });
    console.log(`hover ${step.hover}`);
  } else if ('scroll' in step) {
    if (typeof step.scroll === 'number') {
      await page.evaluate((y) => window.scrollBy(0, y), step.scroll);
      console.log(`scroll ${step.scroll}px`);
    } else if (step.scroll === 'bottom' || step.scroll === 'top') {
      await page.evaluate((edge) => {
        window.scrollTo(0, edge === 'bottom' ? document.body.scrollHeight : 0);
      }, step.scroll);
      console.log(`scroll to ${step.scroll}`);
    } else {
      await page.locator(step.scroll).first().scrollIntoViewIfNeeded({ timeout: t });
      console.log(`scroll to ${step.scroll}`);
    }
  } else if ('wait' in step) {
    if (typeof step.wait === 'number') {
      await page.waitForTimeout(step.wait);
      console.log(`wait ${step.wait}ms`);
    } else {
      await page.locator(step.wait).first().waitFor({ state: 'visible', timeout: t });
      console.log(`wait for ${step.wait}`);
    }
  } else if ('expect' in step) {
    if (!await page.locator(step.expect).first().isVisible().catch(() => false))
      throw new Error(`"${step.expect}" not visible`);
    console.log(`expect ${step.expect} ✓`);
  } else if ('expectGone' in step) {
    if (await page.locator(step.expectGone).first().isVisible().catch(() => false))
      throw new Error(`"${step.expectGone}" still visible`);
    console.log(`expectGone ${step.expectGone} ✓`);
  } else if ('screenshot' in step) {
    await screenshot(page, step);
  } else if ('styles' in step) {
    await captureStyles(page, step.styles);
  } else {
    throw new Error(`unknown step: ${JSON.stringify(step)}`);
  }
};

const steps = flags.steps ? loadSteps(flags.steps) : [
  { goto: positional[0] || '/' },
  { wait: 2000 },
  ...(flags.wait ? [{ wait: flags.wait }] : []),
  { screenshot: positional[1] || '/tmp/screenshot.png', selector: flags.selector, fullPage: flags.fullPage },
  ...(flags.styles ? [{ styles: flags.styles }] : []),
];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width, height } });
try {
  for (let i = 0; i < steps.length; i++) {
    try {
      await runStep(page, steps[i]);
    } catch (e) {
      if (steps[i].optional) { console.log(`step ${i + 1} optional, skipped: ${e.message}`); continue; }
      console.error(`step ${i + 1} failed (${JSON.stringify(steps[i])}): ${e.message}`);
      process.exitCode = 1;
      break;
    }
  }
} finally {
  await browser.close();
}
