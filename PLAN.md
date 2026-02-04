# Current Work

## Status: Phase 16 Complete

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 11-15, 18)

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

**Why Bootstrap 5 (not full migration):**
- Navbar with dropdowns would need custom JS (~100 lines)
- Grid easily replaceable but only used in ~15 places
- Full custom CSS saves ~170K but requires 2-3 days work
- Bootstrap 5 gives 88K savings for minimal effort

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
| **Core JS** | ~234K | jquery.min.js (88K) + bootstrap.bundle.min.js (80K) + nav_stats.js |
| **React Runtime** | ~143K | react.production.min.js (6K) + react-dom.production.min.js (137K) |
| **Leaflet** | ~150K | leaflet.js (147K) + leaflet.css (16K) |
| **OpenLayers** | ~738K | ol.js (720K) - only used on map page |

---

## Backlog

### Phase 17: Preact Migration (Optional)
- Replace React with Preact (~140K savings)
- Use `preact/compat` for drop-in replacement
- Test all React components (area_show, ideas, gallery_dynamic)

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

### Future Ideas

**Map Page Optimization:**
- Replace OpenLayers with Leaflet (-590K)
- `map.js` already uses jQuery → rewrite to vanilla JS
- Would require converting OpenLayers API to Leaflet API

**Stats Rendering:**
- Explore better ways to render post stats (distance, time, temperature)
- Consider inline badges, sidebar summary, or expandable section

**Navigation Thumbnails:**
- Add post thumbnail to prev/next navigation buttons
- Makes navigation more visual and engaging

---

## Test Status

**242 tests passing**

---

*Last updated: 2026-02-04*
