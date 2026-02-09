# Current Work

## Status: Phase 9 - Command Restructure (Complete)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8-9, 11-24, Photo Planner)

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

#### Phase 20e: Final Cleanup
- [ ] Move `/photos.json` → `/jsons/photos.json` (last remaining root JSON)
- [ ] Update timeline.js and panoramio to use new path

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

## Phase 9: Command Restructure (Complete)

**Goal:** Restructure all standalone Crystal command scripts into a shared library with thin entry-point wrappers and a unified pipeline runner.

**Architecture:**
```
data/src/commands/
├── base.cr              # Commands module, ENVS constant, init_blog helper
├── all.cr               # Require aggregator
├── pipeline/            # Data pipeline commands (run in sequence)
│   ├── all.cr
│   ├── generate_areas_for_posts.cr
│   ├── generate_polygon_json.cr
│   ├── assign_photos_to_areas.cr
│   └── gpx_rectify.cr
└── tools/               # Standalone utility commands
    ├── all.cr
    ├── fetch_map_tiles.cr
    ├── list_missing_routes.cr
    └── test_region_matching.cr

commands/                # Thin entry-point wrappers (delegate to data/src/commands/)
├── run_all.cr           # Unified pipeline runner (shares single AreaMatcher::Matcher)
├── generate_areas_for_posts.cr
├── generate_polygon_json.cr
├── assign_photos_to_areas.cr
├── gpx_rectify.cr
├── fetch_map_tiles.cr
├── list_missing_routes.cr
└── test_region_matching.cr
```

**Key changes:**
- All 7 `commands/*.cr` entry points rewritten as thin wrappers delegating to `data/src/commands/`
- All pipeline commands accept optional `AreaMatcher::Matcher` for shared loading (~90MB loaded once)
- `commands/run_all.cr` runs full pipeline with shared matcher instance
- Fixed `Map::Downloader::PUBLIC_PATH` to `env/full/public/local/tiles`
- Fixed broken require in `lists_posts_missing_detailed_route.cr`
- 2 deferred commands remain as-is: `generate_photo_map.cr`, `generate_maps_for_route_ideas.cr`

**Tests added:** 28 new specs (base_spec, assign_photos_manifest_spec, douglas_peucker_spec, tools_spec)

**Test Results:** 444 Crystal specs passing, 161 E2E tests passing

---

## Phase 24: Polygon-Based Photo-to-Area Assignment (Complete)

**Goal:** Replace inaccurate bbox-based photo selection on area show pages with precise polygon point-in-polygon matching using GEOS.

**Architecture:**
```
commands/assign_photos_to_areas.cr   ← Offline script (run manually)
         ↓ uses
AreaMatcher::Matcher.match_point()   ← GEOS polygon testing
         ↓ writes
env/<env>/cache/photos_in_area/      ← Per-area YAML cache
  ├── already_assigned.txt           ← Manifest of processed photos
  ├── towns/<slug>.yml
  ├── counties/<slug>.yml
  ├── voivodeships/<slug>.yml
  ├── meso_regions/<slug>.yml
  └── macro_regions/<slug>.yml
         ↓ read by
PhotoAreaCache                       ← Build-time cache reader service
         ↓ used by
AreaShowView.collect_area_photos     ← Returns cached photos (no bbox fallback)
```

**Files created:**
- `commands/assign_photos_to_areas.cr` — Offline command with incremental processing via manifest, `--overwrite` flag
- `data/src/services/photo_area_cache.cr` — Build-time cache reader, resolves YAML entries to PhotoEntity
- `spec/services/photo_area_cache_spec.cr` — 7 Crystal specs
- `tests/e2e/specs/area-show.spec.js` — 20 E2E tests (4 area types × 5 checks)

**Files modified:**
- `data/src/blog.cr` — Added `require "./services/photo_area_cache"`
- `data/src/render_context.cr` — Added lazy `photo_area_cache` getter
- `data/src/views/area_show_view.cr` — `collect_area_photos` uses cache instead of bbox, no fallback

**Results (full env):** 6,059 geo-tagged photos assigned to 1,037 area-slug pairs across 5 area types.

**Usage:**
```bash
crystal run commands/assign_photos_to_areas.cr              # Incremental
crystal run commands/assign_photos_to_areas.cr -- --overwrite  # Full reprocess
```

---

## Phase 23: Centralized Profiler (Complete)

**Goal:** Replace scattered manual timing with a single annotation-based profiler.

**How it works:**
- `@[Profile(category: "yaml")]` annotation on methods
- `include Profiled` in a class enables auto-wrapping via `finished` macro hook
- `Profiler.measure("cat", "name") { ... }` for cross-object/dynamic-name calls
- `Profiler.summary` prints category breakdown + top 10 slowest at end of build
- Remove `include Profiled` to disable all profiling for a class — annotations become inert

**Files created:**
- `data/src/services/profiler.cr` — `Profile` annotation, `Profiler` class (measure, record, summary, reset, enabled?)
- `data/src/services/profiled.cr` — `Profiled` module with `finished` macro hook

**Files modified:**
- `data/src/blog.cr` — `Profiler.reset`/`measure`/`summary` replaces 6 timing variables + manual summary
- `data/src/view_registry/coordinator.cr` — `Profiler.measure("registry", entry.name)` replaces manual timing
- `data/src/data_manager.cr` — `@[Profile(category: "yaml")]` on 8 load methods
- `data/src/post_renderer.cr` — `@[Profile(category: "posts")]` on 2 render methods
- `data/src/validator.cr` — `@[Profile(category: "validation")]` on 3 private methods

**Dev build output:**
```
─── Profiler Summary ───
  render:     3406.5ms  60.6%  (4 items)
  registry:   1465.0ms  26.1%  (46 items)
  validation:  550.2ms   9.8%  (4 items)
  posts:       190.8ms   3.4%  (2 items)
  init:          4.8ms   0.1%  (3 items)
  Total:      5617.3ms
─── Top 10 Slowest ───
  1703.7ms - render: Post + registry rendering
  1465.3ms - render: Registry rendering
   702.4ms - registry: Photo maps: all
   292.9ms - registry: Areas: show pages
   278.1ms - validation: validator.run
   271.7ms - validation: validate_html_output
   190.8ms - render: Post rendering
   190.8ms - posts: render_with_galleries
   132.9ms - registry: Setup: copy assets
   122.1ms - registry: Photo galleries: all
```

**Macro note:** Crystal nested macros (`macro finished` inside `macro included`) cannot use `\{% if %}` / `\{% end %}` for visibility — the `\{% end %}` gets consumed by the outer macro parser. Solved with ternary: `method.visibility.stringify == ":private" ? "private ".id : "".id`.

---

## Phase 21: Map Service Restructure (Complete)

Full restructure of `data/src/services/map/` — separated computation from rendering, added multi-format output, consolidated views, wrote comprehensive tests.

**Parts completed:**
1. Bug fixes: typos (DEFAULTH, time→tile, dimenstion), dead code removal (sleep, fix_crossing_photos, unused vars)
2. MapConfig & MapContext structs with factory methods for all 11 use cases
3. MapPipeline + MapResult (computation/rendering separation), PhotoSelection module
4. SvgRenderer, PngRenderer (rsvg-convert), LeafletJsonRenderer
5. View consolidation: 9 → 4+2 (GlobalMapSvgView, AreaMapSvgView, + kept PostBig/PostRoute/Idea)
6. Tests: 116 new tests (387 total, up from 271)

**Post-completion fixes:**
- `MapContext` default: `RouteColors.new` → `RouteColors.new("data/config")` — RouteColors requires a config_path, not zero-arg
- `MapPipeline.route_object_to_polyline`: `color_rgb` from `route_colors.color_rgb_for()` is nilable (`String?`), added `|| "0,0,0"` fallback

**Architecture (new pipeline):**
```
MapConfig + MapContext → MapPipeline.compute → MapResult → SvgRenderer / LeafletJsonRenderer / PngRenderer
```

Old path (`Map::Base` → `Map::Main` → `.to_svg`) still works alongside — consolidated views use old path for now.

### Performance Observations

Map rendering generates ~130+ SVG files per build:
- ~100 posts × 2 (big + small) = ~200 post maps
- 16 voivodeships × 2 = 32 voivodeship maps
- 7 global maps
- 10 tag maps
- ~10 idea maps
- **Total: ~260 Map::Base/Main instances**

**Bottleneck (fixed): GridLayer photo selection** — was O(cells × photos) per map.

Implemented `SpatialIndex` (`data/src/services/map/spatial_index.cr`): pre-buckets photos
into a hash grid keyed by `{floor(lat/0.05), floor(lon/0.05)}`. Each query checks only
overlapping buckets (1–4 typical) instead of scanning all photos.

Integrated into both `GridLayer` (old path) and `MapPipeline` (new path).

**Benchmark results** (25K photos, simulated Poland coordinates):

| Scenario | Cells | Linear | Spatial | Speedup |
|----------|-------|--------|---------|---------|
| Coarse (zoom 8, photo_size=160) | 384 | 115 ms | 5.4 ms | **21x** |
| Fine (zoom 10, photo_size=50) | 62,935 | 12.3 sec | 29 ms | **421x** |

The fine-grid scenario represents the "detailed" global map — the worst case that was
taking ~12 seconds per map now takes ~29 ms. With ~15 grid-type maps generated per build,
this saves roughly 3 minutes of total build time.

**Remaining potential optimizations (not yet implemented):**
1. **Shared TilesLayer**: Global maps at same zoom share identical tile grids. Could compute once, reuse across views.
2. **Pre-filter photos once**: `filter_photos_with_coords` runs for every map instance. Could cache the filtered array on RenderContext.
3. **Lazy SVG rendering**: Views currently compute maps in constructor. Could defer to `output` call for better memory use.

---

## Backlog

### Future Ideas

**Trip Ideas page (`/pomysly_tras.html`) - Known Issues:**
- Town links are broken: `ideas.json` only includes towns that have been visited (rendered as AreaEntity),
  but trip ideas reference all towns on the route including unvisited ones. Unvisited towns have no
  show page URL so links appear as gray/inactive tags. Fix: either render show pages for all towns
  (not just visited) or include all towns in the JSON with a flag indicating if visited.

**More Page (`/wiecej.html`) — Missing Links:**
The new more page only has 5 links. The old `more.md` had 14 links. Evaluate adding:
- Galeria (`/galeria.html`) — photo galleries
- Roczne statystyki (`/rok/<year>.html`) — yearly reports
- Gminy (`/gminy.html`) — towns index
- Statystyki EXIF (`/statystyki_exif.html`) — EXIF stats
- O mnie (`/o-mnie.html`) — about page
- RSS/Atom feeds (`/feed.xml`, `/feed_atom.xml`)
- External galleries (Smugmug, 500px) — if still relevant

**Stats Rendering:**
- Explore better ways to render post stats (distance, time, temperature)
- Consider inline badges, sidebar summary, or expandable section

**Link Preview / Social Share Meta Tags:**
Current state for area show pages (and likely other pages):
- **Present:** `og:title`, `og:url`, `og:site_name`, `og:image` (with type/width/height), `<title>`
- **Missing:** `og:description` (blank on Facebook/Slack/Discord), `og:type` (should be `"website"`), `twitter:card` (`summary_large_image`), `twitter:title/description/image`, `meta name="description"` (search engine snippets)
- **Source files:** `data/src/views/helpers/seo_helper.cr` (text meta), `data/src/views/base_view.cr` (`open_graph_html`), `data/layout/include/open_graph_image.html` (image meta)
- Area pages could auto-generate descriptions like "Grudziądz — 12 wypraw, 340km, 185 zdjęć" from inline stats

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

**444 Crystal tests passing, 161 E2E tests passing**

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

**Latest Results: 161 passed, 0 failed, 5 skipped**

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-09*
