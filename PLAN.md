# Current Work

## Status: Cleanup complete (Phases 25-30 done)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8-9, 11-32, Photo Planner)

---

## Phase 20: JSON Optimization

**Goal:** Reduce JSON payload sizes by creating page-specific endpoints.

### Current JSON Files

| File | Size | Generator | Used By |
|------|------|-----------|---------|
| `/jsons/e2e.json` | ~5 KB | `PayloadJsonGenerator` | E2E smoke tests only (replaced payload.json) |
| `/jsons/map.json` | 16 KB | `MapJsonGenerator` | map_leaflet.js |
| `/jsons/homepage.json` | 11 KB | `HomePageJsonGenerator` | homepage.js, post_collection.js |
| `/jsons/ideas.json` | 510 KB | `IdeasJsonGenerator` | ideas.js |
| `/jsons/train_stations.json` | 6 KB | `TrainStationsJsonGenerator` | planner.js |
| `/jsons/photo_grid.json` | 14 KB | `PhotoGridJsonGenerator` | planner.js |
| `/photos.json` | **20 MB** (25,623 photos) | `PhotosJsonGenerator` | timeline.js, panoramio.html |

**Note:** `/nav_stats.json` disabled/deregistered. Only `/photos.json` remains at root (needs moving to `/jsons/`).

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

#### Phase 20a: Quick Wins & JSON Moves
- [x] Remove `card_url` from `PhotosJsonGenerator` (also updated panoramio.html to use article_url)
- [x] Disable/deregister `nav_stats.json` (unused)
- [x] Move `train_stations.json` → `/jsons/train_stations.json`
- [x] Move `ideas.json` → `/jsons/ideas.json`
- [x] Replace `payload.json` with `/jsons/e2e.json` (minimal E2E test data only)
- [x] Move `map.json` → `/jsons/map.json`
- [x] Move `homepage.json` → `/jsons/homepage.json`
- [ ] Move `photos.json` → `/jsons/photos.json` (still at root, 20MB)

#### Phase 20b: Map JSON
- [x] Create `/jsons/map.json` generator (`MapJsonGenerator`)
- [x] Include: posts with coords, slug, title, date, distance, time_spent, card_image_url, coords
- [x] Exclude: full area entity arrays, posts without coords
- [x] Update `map_leaflet.js` to use new endpoint
- [x] Add e2e tests for map JSON endpoint
- [x] Result: 16 KB vs 836 KB in dev (98% reduction)

#### Phase 20c: ~~Summary JSON~~ — REMOVED
Summary page (`/zestawienie.html`) deleted. No longer needed.

#### Phase 20d: Photos Map JSON ✅ DONE
- [x] Create `/jsons/photos_map.json` generator (`PhotosMapJsonGenerator`)
- [x] Include: only photos with lat/lon
- [x] Include fields: lat, lon, altitude, time, desc, article_url, post_url, tags, points, camera_name
- [x] Exclude: full_url, card_url, detailed EXIF (aperture, exposure, iso, focal)
- [x] Update `panoramio.html` to use new endpoint

#### Phase 20e: Final Cleanup ✅ DONE
- [x] Move `/photos.json` → `/jsons/photos.json` (last remaining root JSON)
- [x] Update timeline.js and exif_stats.js to use new path

---

### Expected Savings

| Current | Optimized | Savings |
|---------|-----------|---------|
| photos.json 20MB | Remove card_url | **~2.66 MB** |
| photos.json 20MB | Create photos_map.json (coords only, no full EXIF) | **~7 MB** |
| payload.json 5MB | Replaced with e2e.json (~5KB) + map.json (16KB) | **~5 MB** |
| nav_stats.json 6.5KB | Disabled/deregistered | **6.5 KB** |
| **Total** | | **~10+ MB** |

---

## Completed Phases (see PLAN_DONE.md)

Phases 1-3, 8-9, 11-30, 31-32, Photo Planner — all documented in PLAN_DONE.md.

---

## Backlog

### Future Ideas

**More Page (`/wiecej.html`) — Missing Links:**
The more page has 6 links. The old `more.md` had 14 links. Evaluate adding:
- Galeria (`/galeria.html`) — photo gallery index
- Roczne statystyki (`/rok/<year>.html`) — yearly reports
- Gminy (`/gminy.html`) — towns index
- O mnie (`/o-mnie.html`) — about page
- RSS/Atom feeds (`/feed.xml`, `/feed_atom.xml`)

**Eliminate Late-Bound Properties (partial — easy ones done):**
12 of 13 easy late-bound properties converted to constructor params. The "Wire late-bound
dependencies" section in blog.cr is gone. Remaining are genuinely late-bound (need posts):

| Class | Properties | Reason |
|-------|-----------|--------|
| **Renderer** | `all_posts`, `posts_for_resize` | Set after posts are initialized |
| **Validator** | `area_data_loader`, `posts` | Set after posts are initialized |
| **PostCollection** | `photo_tags`, `exif_db`, `markdown_wrapper` | Set before initialize_posts |
| **Post** | `exif_db`, `photo_tags` | Set per-post in initialize_posts loop |

Could reduce `.not_nil!` noise with `getter!` macros across remaining call sites.

**Photo Perceptual Hash (pipeline command):**
Store color/perceptual hash data per photo alongside EXIF. Enables: finding visually similar photos, color-based search, duplicate detection, "more like this" in galleries.

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

**545 Crystal tests passing, 169+ E2E tests passing**

### E2E Tests (Playwright)

Infrastructure in `tests/e2e/`:
- `specs/smoke.spec.js` - All URLs from e2e.json return 200
- `specs/posts.spec.js` - Post article pages
- `specs/map.spec.js` - Map pages (mapa_tras.html, mapa_zdjec.html)
- `specs/gallery.spec.js` - Gallery pages
- `specs/static.spec.js` - Static pages
- `specs/js-pages.spec.js` - JS-heavy pages
- `specs/homepage.spec.js` - Homepage links, JSON, dynamic content
- `specs/tag-filtering.spec.js` - Tag post list filtering
- `specs/navigation.spec.js` - Navigation styling across pages
- `specs/more-page.spec.js` - More page links
- `specs/towns-index.spec.js` - Towns index search, voivodeships, cards
- `specs/area-filtering.spec.js` - Area post list filtering
- `specs/area-show.spec.js` - Area show pages (photos, JSON, no JS errors)
- `specs/social-meta.spec.js` - Social meta tags (og:type, twitter:card, descriptions)

**Latest Results: 169+ passed, 0 failed, 2 skipped**

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-10*
