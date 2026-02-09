# Current Work

## Status: Phase 25 - Code Audit Fixes (In Progress)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8-9, 11-24, 25 Batch 1, Photo Planner)

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

## Phase 25: Code Audit Fixes (Batch 2)

**Goal:** Fix bugs, rename misleading methods, remove dead code found during 2026-02-09 audit.

### Bugs (must fix)

#### 25a. Delete `is_published` field + `mark_as_published!` entirely
**File:** `data/src/models/photo_entity.cr:199-201`, `data/src/data_manager/exif_db.cr:37`

`mark_as_published!` sets wrong ivar (`@published` instead of `@is_published`), but **nothing reads `is_published` at all**. The photos JSON generator explicitly works around it: `# photo_entity.is_published behaves strange`. Photos are classified by collection membership in ExifDb, not by flag.

**Fix:** Delete `mark_as_published!`, delete `@is_published` field/getter/constructor param, delete the call in `exif_db.cr:37`, update `photos_json_generator.cr` to remove the workaround comment.

#### 25b. YearStatReportView hike opacity checks bicycle value
**File:** `data/src/views/dynamic_view/year_stat_report_view.cr:152-153`
```crystal
hike_opacity = OPACITY_MAX if bicycle_opacity > OPACITY_MAX  # BUG: should check hike_opacity
hike_opacity = OPACITY_MIN if bicycle_opacity < OPACITY_MIN  # BUG: should check hike_opacity
```

#### 25c. `LandEntity` reads wrong YAML key for `@code`
**File:** `data/src/models/land_entity.cr:32` — reads `y["country"]` into `@code`. Field is unused so low impact but still wrong.

### Misleading Names (should rename)

#### 25d. `haversine_distance` → `euclidean_distance_approx`
**File:** `data/src/services/area_photo_selector.cr:100-104` — implements Pythagorean distance, not Haversine.

#### 25e. `externally_propelled?` — implicit nil return
**File:** `data/src/post/accessors.cr:77-79` — fix to `train? || car? || bus?`

#### 25f. `IMAGE_FORMAT_M43 = :m34` symbol typo
**File:** `data/src/post/photos.cr:5` — symbol value `:m34` doesn't match constant name `M43`. No posts use `image_format` header. Fix to `:m43`.

#### 25g. `content_html_missing_reference_links` — misleading name + divide-by-2
**File:** `data/src/post/helpers.cr:14-15` — rename to `content_html_reference_pattern_count`.

### Dead Code (delete)

- [x] ~~Unreachable code in PortfolioView (lines 81-99)~~ Done (uncommitted)
- [ ] Commented-out `title` method in `accessors.cr:102-106`
- [x] ~~`image_format_m43?` — zero callers~~ Done (uncommitted)
- [x] ~~`VoivodeshipEntity#belongs_to_post?` + `#validate` — zero callers~~ Done (uncommitted)
- [ ] `validator.cr:117-146` private `check_missing_referenced_links` — dead duplicate of `tremolite/validator.cr`

### Low Priority

- **Gallery index views** — `# TODO this can crash if there is 0 photos` in 6+ views — add guard clause
- **`data_manager.cr:140-144`** — regex scan on EXIF path can crash if filename doesn't match
- **`coord_set.cr:89,102`** — uses `set.includes?` should be `@set.includes?`

---

## Phase 26: Remove Portfolio

**Goal:** Remove portfolio page entirely. Will be regenerated later.

**Delete files (6):**
- `data/src/models/portfolio_entity.cr`
- `data/src/views/dynamic_view/portfolio_view.cr`
- `data/layout/portfolio/page.html`
- `data/layout/portfolio/indicator.html`
- `data/layout/portfolio/section.html`
- `data/config/portfolio.yml`

**Modify files (9):**
- `data/src/models/all.cr` — remove `require "./portfolio_entity"`
- `data/src/data_manager.cr` — remove `@portfolios`, `getter :portfolios`, `load_portfolio` method
- `data/src/views/dynamic_view/all.cr` — remove `require "./portfolio_view"`
- `data/src/render_context.cr` — remove `portfolios` accessor
- `data/src/view_registry/views/photo_views.cr` — remove portfolio registration + "portfolio" from `selected_tags`
- `data/src/models/photo_entity.cr` — remove `TAG_PORTFOLIO` constant + from `TAG_GALLERIES`
- `data/config/photo_tags.yml` — remove portfolio tag entry
- `data/config/config.yml` — remove `gallery.portfolio.*` and `portfolio.title` entries
- `spec/views/dynamic_view_spec.cr` — remove PortfolioView test

**Also clean up:**
- `data/assets/js/self/timeline.js` — remove `'portfolio': 15` from phase mapping
- `data/src/post_function_parser.cr` — remove `# used for creating portfolio page` comment

---

## Phase 27: Remove Deprecated Entities (TownEntity, VoivodeshipEntity, LandEntity)

**Goal:** Complete migration to AreaEntity. All three are marked `PHASE6_DEPRECATED` but still have active callers.

**Status: Requires careful migration — NOT safe to just delete.**

### Active Dependencies

| Entity | Active Callers | Critical Path |
|--------|---------------|---------------|
| **TownEntity** | 10 refs in 5 files | `lands_from_towns` (post init), `photo_coord_quant_cache`, validation |
| **VoivodeshipEntity** | 4 refs in 3 files | validation, render_context getter |
| **LandEntity** | 8 refs in 4 files | loaded before towns, `TownEntity` constructor requires `Array(LandEntity)` |

### Migration Steps

1. **Port `lands_from_towns`** — use AreaEntity with AreaType::MesoRegion instead of LandEntity
2. **Port `photo_coord_quant_cache`** — use AreaEntity for closest-area lookup
3. **Port validation** — use area slugs from AreaDataLoader instead of town/voivodeship arrays
4. **Remove `load_towns`, `load_voivodeships`, `load_lands`** from DataManager
5. **Remove getters** from DataManager and RenderContext
6. **Delete entity files** and update requires

---

## Phase 28: Rename Post Slug Arrays + Make Non-Nilable

**Goal:** Rename `@tags`/`@towns`/`@lands`/`@foreign` to `@tag_slugs`/`@town_slugs`/`@land_slugs`/`@foreign_slugs` to clarify they hold slug strings (not entity objects). Simultaneously make them non-nilable and remove ~50 `.not_nil!` calls.

**Root cause of `.not_nil!`:** These fields are not declared in the base `Tremolite::Post` class (`tremolite/posts/post.cr`). They're assigned in `tags_initialize`/`towns_initialize`/`lands_initialize` methods. Crystal infers them as `Array(String)?` (nilable).

**Naming rationale:** `@tags` is ambiguous — could be `Array(TagEntity)` or `Array(String)`. `@tag_slugs` makes it immediately clear these are string identifiers. Same for `@towns` vs `@town_slugs`. Already used: `post.foreign_slugs` method, `post.area_slugs()` method.

**Fix (two changes in one pass):**

1. Add explicit non-nilable declarations in `initializers.cr`:
```crystal
@tag_slugs : Array(String) = Array(String).new
@town_slugs : Array(String) = Array(String).new
@land_slugs : Array(String) = Array(String).new
@foreign_slugs : Array(String) = Array(String).new
```

2. Rename all references and remove `.not_nil!` calls.

### Reference counts (50 total, 19 files)

| Field | Old Name | New Name | Refs | Files |
|-------|----------|----------|------|-------|
| tags | `@tags` / `.tags` | `@tag_slugs` / `.tag_slugs` | 19 | 10 |
| towns | `@towns` / `.towns` | `@town_slugs` / `.town_slugs` | 16 | 9 |
| lands | `@lands` / `.lands` | `@land_slugs` / `.land_slugs` | 8 | 5 |
| foreign | `@foreign` / `.foreign` | `@foreign_slugs` / `.foreign_slugs` | 7 | 3 |

### Files to modify

**Post internals (3 files, 26 refs):**
- `post/initializers.cr` — declarations, `_initialize` methods, `_from_headers` methods, `lands_from_towns` (11 refs)
- `post/accessors.cr` — getter declaration, all `self.tags.not_nil!` calls in predicates (10 refs)
- `post/areas.cr` — `@towns.not_nil!`, `@lands.not_nil!`, `@foreign.not_nil!` in area_slugs methods (5 refs)

**Models (3 files, 3 refs):**
- `models/tag_entity.cr:35` — `post.tags.not_nil!` → `post.tag_slugs`
- `models/town_entity.cr:94` — `post.towns.not_nil!` → `post.town_slugs`
- `models/land_entity.cr:48` — `post.lands.not_nil!` → `post.land_slugs`

**Core (2 files, 6 refs):**
- `data_manager.cr` — `post.towns.nil?`, `post.towns.not_nil!` (4 refs)
- `validator.cr` — `post.towns.not_nil!` (2 refs)

**Views (8 files, 12 refs):**
- `views/area_show_view.cr:109` — `post.tags.to_json` → `post.tag_slugs.to_json`
- `views/post_view/article_view.cr:91,143-144` — `@post.tags`, `@post.foreign_entities/slugs`
- `views/special_view/e2e_json_generator.cr:40` — `post.tags.to_json`
- `views/special_view/home_page_json_generator.cr:70` — `post.tags.to_json`
- `views/dynamic_view/exif_stats_view.cr:38` — `post.tags.not_nil!`
- `views/dynamic_view/towns_history_view.cr:59,78` — `post.towns`
- `views/dynamic_view/towns_timeline_view.cr:169` — `post.towns.not_nil!`
- `views/new_home_page_view.cr:30,107,114` — `p.tags.try(&.includes?(...))`

**Other (1 file):**
- `render_context.cr:223` — `post.foreign_slugs` (already uses correct name)

**Note:** `@foreign` already has `foreign_slugs` method wrapper in `areas.cr`. After rename, the wrapper becomes a simple getter.

**Risk:** Very low — Crystal compiler catches all missed renames at compile time. 486 Crystal tests + 161 E2E tests validate behavior.

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

**486 Crystal tests passing, 161 E2E tests passing**

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
