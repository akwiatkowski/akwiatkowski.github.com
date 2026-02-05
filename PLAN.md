# Current Work

## Status: Phase 19 Complete

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 11-19)

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

## Backlog

### Phase 20: JSON Optimization

**Goal:** Ensure all pages use optimized JSON endpoints with minimal payload sizes.

**Background:**
- `payload.json` is 836KB (includes coords, full area data)
- Created `HomePageJsonGenerator` → `/jsons/homepage.json` (6KB, 99% smaller)
- Pattern: create page-specific JSON with only required fields

**Tasks:**

1. **Audit all pages using JSON data**
   - [ ] List all pages that fetch JSON (map, ideas, gallery, etc.)
   - [ ] Document which JSON file each page uses
   - [ ] Document which fields are actually used by JS

2. **Create optimized JSON generators for each use case**
   - [ ] Map page → `/jsons/map.json` (needs coords, but not all post fields)
   - [ ] Ideas page → `/jsons/ideas.json`
   - [ ] Gallery pages → `/jsons/gallery.json`
   - [ ] Other pages as needed

3. **Migrate JSON URLs to `/jsons/` directory**
   - [ ] Move `payload.json` → `/jsons/payload.json` (keep for backward compat or deprecate)
   - [ ] Move `nav_stats.json` → `/jsons/nav_stats.json`
   - [ ] Move `ideas.json` → `/jsons/ideas.json`
   - [ ] Move `photos.json` → `/jsons/photos.json`
   - [ ] Update all JS files to use new paths

4. **Measure and document savings**
   - [ ] Before/after size comparison for each JSON
   - [ ] Total bandwidth savings

**Current JSON Files:**
| File | Size | Used By | Optimized? |
|------|------|---------|------------|
| `/payload.json` | 836KB | map.js, others? | No |
| `/jsons/homepage.json` | 6KB | post_collection.js | Yes |
| `/nav_stats.json` | ~1KB | nav_stats.js | OK (small) |
| `/ideas.json` | ? | ideas page | TBD |
| `/photos.json` | ? | gallery? | TBD |

---

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

### Future Ideas

**Stats Rendering:**
- Explore better ways to render post stats (distance, time, temperature)
- Consider inline badges, sidebar summary, or expandable section

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
- `specs/homepage.spec.js` - Homepage links, JSON, dynamic content
- `specs/tag-filtering.spec.js` - Tag post list filtering

**Latest Results: 44 passed, 0 failed, 5 skipped**

All tests passing. Skipped tests are for data not present in dev mode.

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

*Last updated: 2026-02-05*
