# Current Work

## Status: Phase 20 - JSON Optimization (In Progress)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8, 11-19)

---

## Phase 20: JSON Optimization

**Goal:** Reduce JSON payload sizes by creating page-specific endpoints.

### Current JSON Files (Production Sizes)

| File | Size | Generator | Used By |
|------|------|-----------|---------|
| `/payload.json` | **5.0 MB** | `PayloadJsonGenerator` | map.js, summary.js, area_show.js |
| `/photos.json` | **20 MB** (25,623 photos) | `PhotosJsonGenerator` | timeline.js, panoramio.html, area_show.js |
| `/ideas.json` | 510 KB | `IdeasJsonGenerator` | ideas.js |
| `/jsons/homepage.json` | 11 KB | `HomePageJsonGenerator` | homepage.js, post_collection.js |
| `/train_stations.json` | 6 KB | `TrainStationsJsonGenerator` | ideas.js |
| `/nav_stats.json` | 6.5 KB | `NavStatsJsonGenerator` | nav_stats.js |

**Total unoptimized:** ~25.5 MB

---

### Detailed Analysis: payload.json (836 KB)

**Why it's huge:** GPS coordinates - each post has `coords[].route` with hundreds of `[lat, lon]` pairs.

**Pages using it:**

| Page | URL | Fields Used |
|------|-----|-------------|
| **Map** | `/mapa_tras.html` | coords, date, distance, time_spent, url, title, card_image_url |
| **Summary** | `/podsumowanie.html` | posts basic info, towns→voivodeship hierarchy, NO coords |
| **Area Show** | `/gmina/*.html` | posts filtered by area, coords for map |

**Optimization:**
- Create `/jsons/map.json` - posts with coords only, minimal metadata
- Create `/jsons/summary.json` - no coords, just post metadata + hierarchy
- Expected savings: ~500KB total

---

### Detailed Analysis: photos.json (20 MB)

**Stats:** 25,623 photos total, 23,805 with GPS coords

**Field sizes (top consumers):**
| Field | Size | Notes |
|-------|------|-------|
| `article_url` | 2.81 MB | Needed for thumbnails |
| `card_url` | 2.66 MB | **REMOVED** - saves ~2.66 MB |
| `full_url` | 2.22 MB | Only needed for modal |
| `post_url` | 1.38 MB | Links to posts |
| `post_slug` | 1.26 MB | For filtering |

**Pages using it:**

| Page | URL | JS File | Key Requirements |
|------|-----|---------|------------------|
| **Timeline** | `/linia_czasu.html` | timeline.js | All photos, full EXIF for modal |
| **Photo Map** | `/mapa_zdjec.html` | panoramio.html | Only photos WITH lat/lon |
| **Area Show** | `/gmina/*.html` | area_show.js | Filter by post_slug |

**Field usage matrix:**

| Field | timeline.js | panoramio | area_show |
|-------|-------------|-----------|-----------|
| `desc` | ✓ | ✓ | ✓ |
| `full_url` | ✓ (modal) | ✓ | - |
| `article_url` | ✓ (grid) | ✓ (sidebar) | ✓ |
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
1. ~~Remove `card_url` from generator~~ **DONE** - panoramio now uses article_url
2. Create `/jsons/photos_map.json` for panoramio - only photos with lat/lon, exclude detailed EXIF
3. Keep `/jsons/photos.json` for timeline (needs full EXIF for modal)

---

### Implementation Plan

#### Phase 20a: Quick Wins
- [x] Remove `card_url` from `PhotosJsonGenerator` (also updated panoramio.html to use article_url)
- [ ] Move all JSONs to `/jsons/` directory
- [ ] Update JS files to use new paths

#### Phase 20b: Map JSON
- [x] Create `/jsons/map.json` generator (`MapJsonGenerator`)
- [x] Include: posts with coords, slug, title, date, distance, time_spent, card_image_url, coords
- [x] Exclude: full area entity arrays, posts without coords
- [x] Update `map_leaflet.js` to use new endpoint
- [x] Add e2e tests for map JSON endpoint
- [x] Result: 16 KB vs 836 KB in dev (98% reduction)

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
| photos.json 20MB | Remove card_url | **~2.66 MB** |
| photos.json 20MB | Create photos_map.json (coords only, no full EXIF) | **~7 MB** |
| payload.json 5MB | map.json + summary.json | **~3 MB** |
| **Total** | | **~10+ MB** |

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
- `specs/map.spec.js` - Map pages (mapa_tras.html, mapa_zdjec.html)
- `specs/gallery.spec.js` - Gallery pages
- `specs/static.spec.js` - Static pages
- `specs/js-pages.spec.js` - JS-heavy pages
- `specs/homepage.spec.js` - Homepage links, JSON, dynamic content
- `specs/tag-filtering.spec.js` - Tag post list filtering
- `specs/navigation.spec.js` - Navigation styling across pages
- `specs/more-page.spec.js` - More page links

**Latest Results: 82 passed, 0 failed, 5 skipped**

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-06*
