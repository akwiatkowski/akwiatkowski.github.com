# Current Work

## Status: Phase 20 - JSON Optimization (Analysis Complete)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8, 11-19)

---

## Phase 20: JSON Optimization

**Goal:** Reduce JSON payload sizes by creating page-specific endpoints.

### Current JSON Files (Analyzed)

| File | Size | Generator | Used By |
|------|------|-----------|---------|
| `/payload.json` | **836 KB** | `PayloadJsonGenerator` | map.js, summary.js, area_show.js |
| `/photos.json` | **312 KB** | `PhotosJsonGenerator` | timeline.js, panoramio.html, area_show.js |
| `/ideas.json` | **512 KB** | `IdeasJsonGenerator` | ideas.js |
| `/jsons/homepage.json` | 11 KB | `HomePageJsonGenerator` | homepage.js, post_collection.js |
| `/train_stations.json` | 6 KB | `TrainStationsJsonGenerator` | ideas.js |
| `/nav_stats.json` | 19 B | `NavStatsJsonGenerator` | nav_stats.js |

**Total unoptimized:** ~1.7 MB

---

### Detailed Analysis: payload.json (836 KB)

**Why it's huge:** GPS coordinates - each post has `coords[].route` with hundreds of `[lat, lon]` pairs.

**Pages using it:**

| Page | URL | Fields Used |
|------|-----|-------------|
| **Map** | `/mapa.html` | coords, date, distance, time_spent, url, title, card_image_url |
| **Summary** | `/podsumowanie.html` | posts basic info, towns→voivodeship hierarchy, NO coords |
| **Area Show** | `/gmina/*.html` | posts filtered by area, coords for map |

**Optimization:**
- Create `/jsons/map.json` - posts with coords only, minimal metadata
- Create `/jsons/summary.json` - no coords, just post metadata + hierarchy
- Expected savings: ~500KB total

---

### Detailed Analysis: photos.json (312 KB)

**Pages using it:**

| Page | URL | JS File | Key Requirements |
|------|-----|---------|------------------|
| **Timeline** | `/linia_czasu.html` | timeline.js | All photos, full EXIF for modal |
| **Photo Map** | `/mapa2.html` | panoramio.html | Only photos WITH lat/lon |
| **Area Show** | `/gmina/*.html` | area_show.js | Filter by post_slug |

**Field usage matrix:**

| Field | timeline.js | panoramio | area_show |
|-------|-------------|-----------|-----------|
| `desc` | ✓ | ✓ | ✓ |
| `full_url` | ✓ (modal) | ✓ | - |
| `card_url` | **UNUSED** | **UNUSED** | **UNUSED** |
| `article_url` | ✓ (grid) | ✓ | ✓ |
| `time` | ✓ | ✓ | ✓ |
| `post_slug` | - | - | ✓ (filter) |
| `post_url` | ✓ | ✓ | ✓ |
| `is_published` | ✓ | - | ✓ |
| `points` | - | ✓ (score) | - |
| `tags` | ✓ | ✓ | - |
| `exif.lat` | ✓ (modal) | ✓ (required) | - |
| `exif.lon` | ✓ (modal) | ✓ (required) | - |
| `exif.altitude` | - | ✓ | - |
| `exif.focal_35mm` | ✓ (modal) | - | - |
| `exif.aperture` | ✓ (modal) | - | - |
| `exif.exposure` | ✓ (modal) | - | - |
| `exif.iso` | ✓ (modal) | - | - |
| `exif.lens_name` | ✓ (modal) | ✓ | - |
| `exif.camera_name` | ✓ (modal) | ✓ | - |
| `exif.time` | - | ✓ | - |

**Optimization:**
1. Remove `card_url` from generator (never used)
2. Create `/jsons/photos_map.json` for panoramio - only photos with lat/lon, exclude detailed EXIF
3. Keep `/jsons/photos.json` for timeline (needs full EXIF for modal)

---

### Implementation Plan

#### Phase 20a: Quick Wins
- [ ] Remove `card_url` from `PhotosJsonGenerator`
- [ ] Move all JSONs to `/jsons/` directory
- [ ] Update JS files to use new paths

#### Phase 20b: Map JSON
- [ ] Create `/jsons/map.json` generator
- [ ] Include: posts with coords, slug, title, date, distance, time_spent, card_image_url, coords
- [ ] Exclude: full area entity arrays, posts without coords
- [ ] Update `map.js` to use new endpoint
- [ ] Expected size: ~300KB (vs 836KB)

#### Phase 20c: Summary JSON
- [ ] Create `/jsons/summary.json` generator
- [ ] Include: posts basic info, towns→voivodeship hierarchy
- [ ] Exclude: coords, full area entities
- [ ] Update `summary.js` to use new endpoint
- [ ] Expected size: ~50KB

#### Phase 20d: Photos Map JSON
- [ ] Create `/jsons/photos_map.json` generator
- [ ] Include: only photos with lat/lon
- [ ] Include fields: lat, lon, altitude, time, desc, article_url, post_url, tags, points, camera_name
- [ ] Exclude: full_url, card_url, detailed EXIF (aperture, exposure, iso, focal)
- [ ] Update `panoramio.html` to use new endpoint
- [ ] Expected size: ~150KB (vs 312KB)

#### Phase 20e: Deprecate Old Endpoints
- [ ] Add deprecation warnings to old endpoints
- [ ] Remove after confirming all pages work

---

### Expected Savings

| Current | Optimized | Savings |
|---------|-----------|---------|
| payload.json 836KB | map.json ~300KB + summary.json ~50KB | ~486KB |
| photos.json 312KB | photos.json ~200KB + photos_map.json ~150KB | ~0 (split) |
| ideas.json 512KB | (keep as-is for now) | 0 |
| **Total** | | **~500KB** |

---

## Backlog

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

### Future Ideas

**Stats Rendering:**
- Explore better ways to render post stats (distance, time, temperature)
- Consider inline badges, sidebar summary, or expandable section

---

## Current Bundle Sizes

| Bundle | Size | Notes |
|--------|------|-------|
| **Core CSS** | ~210K | bootstrap.min.css (190K) + font-awesome.min.css (31K) + new.css (17K) |
| **Core JS** | ~80K | bootstrap.bundle.min.js (80K) + nav_stats.js (jQuery removed!) |
| **Preact Runtime** | ~25K | preact.umd.js (11K) + hooks (4K) + compat (10K) + shim (0.3K) |
| **Leaflet** | ~150K | leaflet.js (147K) + leaflet.css (16K) - now used for map page too |

---

## Test Status

**275 Crystal tests passing**

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

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-06*
