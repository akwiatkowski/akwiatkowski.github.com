# E2E Tests

End-to-end tests using Playwright to verify the rendered site works correctly.

## Setup

```bash
cd tests/e2e
npm install
npx playwright install chromium
```

## Running Tests

First, start the local server (default: `localhost:5001`):

```bash
# From project root
make serve  # or however you start the server
```

Then run tests:

```bash
cd tests/e2e

# Run all tests
npm test

# Run specific test suites
npm run test:smoke    # Quick existence checks
npm run test:posts    # Post pages
npm run test:map      # Map pages
npm run test:gallery  # Gallery pages
npm run test:static   # Static pages
npm run test:js       # JS-heavy pages

# Run with browser visible
npm run test:headed

# Debug mode (step through tests)
npm run test:debug

# View HTML report
npm run report
```

## Custom Base URL

```bash
BASE_URL=http://localhost:8080 npm test
```

## Test Structure

```
tests/e2e/
├── playwright.config.js    # Playwright configuration
├── package.json            # Dependencies and scripts
├── fixtures/
│   └── base.js             # Custom test fixtures (error tracking, payload)
├── helpers/
│   └── payload.js          # Helper to work with payload.json data
└── specs/
    ├── smoke.spec.js       # Quick existence checks (all URLs return 200)
    ├── posts.spec.js       # Post article pages
    ├── map.spec.js         # Map pages (mapa_tras.html, mapa_zdjec.html)
    ├── gallery.spec.js     # Gallery pages
    ├── static.spec.js      # Static pages (home, about, etc.)
    └── js-pages.spec.js    # JS-heavy pages (ideas, timeline, etc.)
```

## What's Tested

### Smoke Tests
- All posts from `payload.json` return 200
- All tags return 200
- All voivodeships return 200
- Feed files exist (RSS, Atom, sitemap, robots.txt)

### Post Tests
- Posts load without JS errors
- Article has required elements (h1, article, navigation)
- Related posts work
- Prev/next navigation works
- Gallery links work

### Map Tests
- Leaflet container renders
- Map tiles load
- Routes are visible on map
- Popups work on click

### Gallery Tests
- Post galleries load
- Tag galleries load
- Area galleries load
- Images are visible

### Static/JS Pages
- All static pages load without JS errors
- JS-heavy pages (ideas, timeline) render correctly
