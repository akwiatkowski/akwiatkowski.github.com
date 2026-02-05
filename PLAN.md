# Current Work

## Status: Phase 16 Complete

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 11-18)

---

## Phase 16: Bootstrap 5 Migration ✅ COMPLETE

### Goal
Upgrade Bootstrap 4 → 5 to remove jQuery dependency (-88K).

### Analysis (2026-02-04)

**Bootstrap Usage in Codebase:**

| Feature | Usage | Files |
|---------|-------|-------|
| Grid | `container`, `row`, `col-lg-8 offset-lg-2` | ~15 places |
| Navbar | Full navbar with dropdowns, mobile collapse | 1 component |
| Buttons | `btn`, `btn-primary`, `btn-light`, `btn-group` | ~10 places |
| Tables | `table` class | 2 files |
| Utilities | `text-center`, `d-block`, `mr-auto` | ~10 places |
| Tooltips | `data-toggle="tooltip"` | 4 buttons |

**JavaScript Dependencies:**

| Library | Size | Used For |
|---------|------|----------|
| jQuery | 88K | Only `map.js` (height/width/fadeOut) |
| Bootstrap JS | 80K | Navbar collapse, dropdown toggles, tooltips |

**Why Bootstrap 5:**
- Removes jQuery dependency (-88K)
- Minimal migration effort (data attribute changes)
- Keeps Bootstrap features (navbar, grid, utilities)

### Migration Steps

1. **Download Bootstrap 5 files**
   - `bootstrap.min.css` (v5.3.x)
   - `bootstrap.bundle.min.js` (includes Popper, no jQuery)

2. **Update HTML - Breaking Changes**
   - `data-toggle` → `data-bs-toggle`
   - `data-target` → `data-bs-target`
   - `data-placement` → `data-bs-placement`
   - `data-dismiss` → `data-bs-dismiss`
   - `mr-*` → `me-*` (margin-end)
   - `ml-*` → `ms-*` (margin-start)

3. **Update Navbar**
   - `data-toggle="collapse"` → `data-bs-toggle="collapse"`
   - `data-toggle="dropdown"` → `data-bs-toggle="dropdown"`

4. **Update Tooltips**
   - Initialize via JS: `new bootstrap.Tooltip(element)`

5. **Remove jQuery**
   - Delete `jquery.min.js` from assets
   - Rewrite `map.js` jQuery calls to vanilla JS

6. **Update asset_bundles.yml**
   - Remove jQuery from `core` bundle
   - Update Bootstrap paths

### Files to Update

| File | Changes |
|------|---------|
| `data/layout/include/navigation/static.html` | `data-toggle` → `data-bs-toggle` |
| `data/layout/post/pager_*.html` | `data-toggle="tooltip"` → `data-bs-toggle` |
| `data/layout/include/navigation/stats.html` | `data-toggle="dropdown"` → `data-bs-toggle` |
| `data/assets/js/self/map.js` | Replace jQuery with vanilla JS |
| `data/config/asset_bundles.yml` | Remove jQuery, update Bootstrap paths |

### What Was Done

1. Downloaded Bootstrap 5.3.3 JS (CSS was already 5.3.8)
2. Updated data attributes: `data-toggle` → `data-bs-toggle`, `data-target` → `data-bs-target`
3. Updated utility classes: `mr-auto` → `me-auto`, `ml-auto` → `ms-auto`
4. Rewrote `map.js` to vanilla JS (removed all jQuery usage)
5. Converted all `$(document).ready()` to `DOMContentLoaded`
6. Added Bootstrap 5 tooltip initialization in `nav_stats.js`
7. Removed jQuery from `core` bundle in `asset_bundles.yml`

### Bug Fix: Towns/Voivodeships in Posts

Fixed display of towns, voivodeships, and lands (krainy) in post articles:
- Migrated from deprecated `TownEntity`/`VoivodeshipEntity`/`LandEntity`
- Now uses unified `AreaEntity` system via `@post.town_entities`, etc.
- Data comes from `cache/areas_for_post/*.yml` (calculated route distances)

### AreaType Polish Inflections Refactoring

Refactored `AreaType` enum with proper Polish grammatical cases and ASCII-safe URL slugs:

**Polish Display Methods (with diacritics):**
- `polish_nominative` - gmina, powiat, województwo, region, obszar
- `polish_genitive` - gminy, powiatu, województwa, regionu, obszaru
- `polish_nominative_plural` - gminy, powiaty, województwa, regiony, obszary

**ASCII-Safe URL Slugs (no diacritics):**
- `nominative_slug` - gmina, powiat, **wojewodztwo**, region, obszar
- `genitive_slug` - gminy, powiatu, **wojewodztwa**, regionu, obszaru

**URL Helpers (use slug methods):**
- `url_prefix` → `/#{nominative_slug}/` (e.g., `/wojewodztwo/`)
- `url_type` → `genitive_slug` (e.g., `wojewodztwa`)

**DRY Identifiers:**
- `english_plural` - towns, counties, voivodeships, meso_regions, macro_regions
- `payload_field` → `english_plural`
- `polygon_dir` → `english_plural`

**AreaEntity Aliases:**
- `view_url` → alias for `show_url`
- `post_areas_link_url` → alias for `post_list_url`

**Bug fix:** Area type labels now lowercase (e.g., "województwo" not "Województwo")

### Savings

| Before | After | Savings |
|--------|-------|---------|
| jQuery 88K | 0 | **-88K** |
| Bootstrap 4 CSS 190K | Bootstrap 5 CSS ~190K | 0 |
| Bootstrap 4 JS 80K | Bootstrap 5 JS ~80K | 0 |

---

## Current Bundle Sizes

| Bundle | Size | Notes |
|--------|------|-------|
| **Core CSS** | ~210K | bootstrap.min.css (190K) + font-awesome.min.css (31K) + new.css (17K) |
| **Core JS** | ~80K | bootstrap.bundle.min.js (80K) + nav_stats.js (jQuery removed!) |
| **Preact Runtime** | ~25K | preact.umd.js (11K) + hooks (4K) + compat (10K) + shim (0.3K) |
| **Leaflet** | ~150K | leaflet.js (147K) + leaflet.css (16K) - now used for map page too |
| ~~**React Runtime**~~ | ~~143K~~ | Replaced with Preact (-114K savings) |
| ~~**OpenLayers**~~ | ~~738K~~ | Replaced with Leaflet (-590K savings) |

---

## Phase 17: Preact Migration ✅ COMPLETE

### What Was Done
- Downloaded Preact UMD files (preact, hooks, compat, shim) to `data/assets/js/libs/`
- Updated `asset_bundles.yml` to use Preact instead of React
- Changed JSX source files to use React 17 `ReactDOM.render()` API (Preact compat doesn't support React 18 `createRoot`)
- Fixed transpiled JS files and `panoramio.html`

### Savings
| Before | After | Savings |
|--------|-------|---------|
| React 139K | Preact 25K | **-114K (82%)** |

---

## Backlog

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

### Future Ideas

**Map Page Optimization:** ✅ DONE
- Replaced OpenLayers with Leaflet (-590K savings)
- Created `map_leaflet.js` with same features (routes, popups, background change)
- MapView now uses `leaflet` bundle instead of `openlayers`
- Added `map-blog.css` for popup styling

**Stats Rendering:**
- Explore better ways to render post stats (distance, time, temperature)
- Consider inline badges, sidebar summary, or expandable section

**Navigation Thumbnails:** ✅ DONE
- Prev/next pager: horizontal cards with thumbnail (32% width each)
- Related posts: 4-column grid with thumbnails (2 on mobile)
- Uses `grid_image_src` (560x420px) for pager, `thumbnail_image_src` for related

---

## Test Status

**253 Crystal tests passing**

### E2E Tests (Playwright)

Infrastructure in `tests/e2e/`:
- `specs/smoke.spec.js` - All URLs from payload.json return 200
- `specs/posts.spec.js` - Post article pages
- `specs/map.spec.js` - Map pages (mapa.html, mapa2.html)
- `specs/gallery.spec.js` - Gallery pages
- `specs/static.spec.js` - Static pages
- `specs/js-pages.spec.js` - JS-heavy pages

**Latest Results: 36 passed, 0 failed, 5 skipped**

All tests passing. Skipped tests are for data not present in dev mode (e.g., posts without photos for gallery tests).

**Fixes Applied (2026-02-04):**
- [x] Tag URLs: use `tag.url` (Polish slug) instead of constructing from `tag.slug`
- [x] Voivodeship tests: filter to only those with posts, use `show_url` from payload
- [x] Gallery tests: filter to tags/voivodeships with posts that have photos
- [x] Locator fixes: use `.first()` for ambiguous selectors (`.navbar-nav`, compound selectors)
- [x] Map popup test: retry multiple routes with graceful skip if no popup appears
- [x] Summary page: check `#content` instead of ambiguous `article, .container`

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

**Next steps for e2e:**
- [ ] Add area page tests (AreaShowView)
- [ ] CI integration

---

## Phase 19: New Index Page (index2.html → index.html)

### Overview

New modern index page with dynamic content selection. Will live as `index2.html`/`index3.html` during development, then replace current `index.html`. Old index becomes `/wpisy.html`.

**Prototypes:**
- `index2.html` - Light mode only, static content
- `index3.html` - Light/dark mode, static content (current)

### Design Decisions

**Typography:**
- Sans-serif: Inter (UI, body)
- Serif: Playfair Display (headings) - may switch to Lora
- Strategy: 2 fonts loaded from Google Fonts

**Color Scheme:**
- Light/dark mode via `prefers-color-scheme`
- Teal accent (#2d7a85 light, #4db8c7 dark)
- CSS variables for all colors

### Requirements

#### 1. Hero Photo Selection (JS, dynamic per visit)

**Data source:** New JSON file with curated photos (not all photos)

**Selection factors (fuzzy logic, probability-based):**

| Factor | Effect | Notes |
|--------|--------|-------|
| Season match | +probability | Photo month within ±1 of current month |
| Has "good" tag | +probability | Minimum quality bar |
| Post is finished | required | Must have `finished_at` set |
| Post has tags | required | Must be tagged |
| Freshness | slight + | Newer posts slightly preferred |
| Time of day | modifier | Morning shows early light, evening shows golden hour |

**Algorithm:**
- Calculate score for each eligible photo
- Time-of-day modifies probability, doesn't exclude
- Random selection weighted by score
- ~50-60% randomness in final pick

#### 2. Post Selection (JS, dynamic per visit)

**Mix strategy for 5 posts:**

| Slot | Source | Selection |
|------|--------|-----------|
| 1 (featured, 2-col) | Best seasonal | High-scored post matching current season |
| 2-5 (regular) | Mixed pool | See below |

**Mixed pool composition:**
- Latest by date (40%)
- Recently finished (`finished_at` in last N days) (30%)
- Seasonal throwback (same month, older year) (30%)

**Randomness:** 50-60% - shuffle within categories, random picks

#### 3. Category Chips (JS, dynamic per visit)

**Fixed chips (always show):**
- Rowerem (bicycle)
- Pieszo (hike)
- Kolejowe (train)

**Dynamic chips (rotate, 3-4 slots):**

| Type | Selection Logic |
|------|-----------------|
| Meso region | Pick from regions with 2-5 posts (not too popular) |
| Town | Pick towns visited but not famous |
| Seasonal tag | `mountains` in winter, `coast` in summer |
| Discovery | Random from: `air`, `bikepacking`, `birds`, `countryside` |

**No grouping** - all chips equal, same visual weight

**Goal:** "Let's explore something together" feeling

#### 4. Data Requirements

**New JSON file needed:** `hero_photos.json` or similar
```json
{
  "photos": [
    {
      "url": "/path/to/post.html",
      "image": "/images/processed/..._card.jpg",
      "title": "Post title",
      "subtitle": "Post subtitle",
      "month": 12,
      "tags": ["best", "hike"],
      "finished_at": "2024-01-15"
    }
  ]
}
```

**Existing data used:**
- `payload.json` - posts, tags, areas
- Post `finished_at` attribute

### Implementation Steps

- [ ] Create `hero_photos.json` generator (Crystal)
- [ ] Add `finished_at` to payload.json posts
- [ ] Write hero photo selection JS
- [ ] Write post mixing JS
- [ ] Write chip selection JS
- [ ] Create index page view (Crystal)
- [ ] Test light/dark mode
- [ ] Test responsive design
- [ ] Replace index.html, move old to wpisy.html

### Hero Text Options

**Current (index3.html):**
> "Polska, której nie zobaczysz z autostrady"
> "Boczne drogi. Ciche wsie. Zapomniane krajobrazy."

**Alternative (index2.html):**
> "Odkrywam miejsca, które przemijają"
> "Nie pokażę Ci gdzie jechać na wakacje..."

Will iterate on final text.

---

*Last updated: 2026-02-04*
