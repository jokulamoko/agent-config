---
name: browser
description: Drive a headless browser to screenshot and interact with a web page — any URL or a local dev server. Use to visually verify frontend/CSS work, capture a page or element, extract computed styles, or run a multi-step interaction (navigate, click, fill, scroll) in one browser session. Reach for this whenever a task needs to see or click a rendered page rather than read its source.
---

# Browser

A headless-Chromium driver at `~/.claude/skills/browser/browser.mjs`. It runs **out of context**: the browser does the work, and only the artifacts you ask for — a PNG, computed styles — come back. This is the token-efficient way to give an agent eyes and hands on a page; nothing from intermediate page state enters the conversation unless you screenshot or extract it.

Two modes share one engine:

- **Simple** — one screenshot of one URL. The default for a quick look.
- **Steps** — an ordered list of actions run in a **single browser session**, so a flow (navigate → click → fill → screenshot) happens in one process with no relaunch and no lost state between steps.

## Prerequisites

Playwright + Chromium are vendored in this skill folder (`npm install` + `npx playwright install chromium`, already done). If `browser.mjs` reports `Executable doesn't exist`, re-run `npx playwright install chromium` from this folder. The script resolves `playwright` from its own `node_modules`, so it runs from any working directory.

## Simple mode

```
node ~/.claude/skills/browser/browser.mjs [path-or-url] [output] [flags]
```

| Positional | Default | Meaning |
|---|---|---|
| `path-or-url` | `/` | A full `http(s)` URL, or a path resolved against `--base` |
| `output` | `/tmp/screenshot.png` | Where the PNG is written |

| Flag | Meaning |
|---|---|
| `--base URL` | Base for relative paths (default `http://127.0.0.1:9292`) |
| `--width N` / `--height N` | Viewport (default 1280×800) |
| `--selector ".sel"` | Screenshot only this element |
| `--full-page` | Capture the full scrollable page |
| `--wait N` | Extra settle time (ms) before capture |
| `--styles ".a,.b"` | Print computed styles for these selectors as JSON |

```bash
node ~/.claude/skills/browser/browser.mjs https://example.com /tmp/out.png --full-page
node ~/.claude/skills/browser/browser.mjs /pages/about /tmp/out.png --base http://localhost:3000 --selector ".hero"
```

## Steps mode

```bash
node ~/.claude/skills/browser/browser.mjs --steps '<json-array>'      # inline
node ~/.claude/skills/browser/browser.mjs --steps @/tmp/flow.json     # from a file
```

The array is a sequence of **action objects**, run top to bottom in one session. Each object carries exactly one action key (plus modifiers). Relative `goto` targets resolve against `--base`.

| Action | Form | Does |
|---|---|---|
| navigate | `{"goto": "url-or-path"}` | Load a page |
| click | `{"click": "selector"}` | Click the first match (auto-waits for it) |
| fill | `{"fill": "selector", "text": "value"}` | Type into an input |
| press | `{"press": "Enter", "selector": "sel"}` | Press a key (on `selector` if given, else the page) |
| hover | `{"hover": "selector"}` | Hover the first match |
| scroll | `{"scroll": "selector"}`, `{"scroll": 600}`, or `{"scroll": "bottom"}` | Scroll element into view, by N pixels, or to `"bottom"`/`"top"` |
| wait | `{"wait": 1000}` or `{"wait": "selector"}` | Pause N ms, or wait for a selector to be visible |
| screenshot | `{"screenshot": "/tmp/x.png", "selector": "sel", "fullPage": true}` | Capture (whole page, or `selector`) |
| styles | `{"styles": ".a,.b"}` | Print computed styles as JSON |
| expect | `{"expect": "selector"}` | Assert visible — fail the run if absent |
| expectGone | `{"expectGone": "selector"}` | Assert absent — fail the run if present |

**Modifier — `"optional": true`** on any action: if it fails (e.g. the element isn't there), log and skip instead of failing the run, and cap its wait at 3s. Use it for steps that may or may not apply on a given page, like dismissing a cookie banner or opening a collapsed toggle.

Selectors are Playwright selectors, so `:has-text("...")` works:

```bash
node ~/.claude/skills/browser/browser.mjs --steps '[
  {"goto": "https://shop.example.com/products/widget"},
  {"click": "button:has-text(\"Add to cart\")"},
  {"wait": "#cart-drawer"},
  {"screenshot": "/tmp/cart.png"},
  {"expect": ".cart__item"}
]'
```

A failed assertion or a non-optional action error stops the run and exits non-zero, naming the step that broke — so a flow that didn't reach its screenshot is loud, not silent.

## Reading the result

Read the PNG(s) with the Read tool and compare against the intent. A capture far smaller than expected often means the page rendered an interstitial (a login/consent/"coming soon" gate) rather than your content — check before trusting it.
