# Current Work

## Status: Cleanup complete (Phases 25-30 done)

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 8-9, 11-30, Photo Planner)

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

## Phase 25: Code Audit Fixes ✅ COMPLETE (commit `a0d9e943`)

All bugs fixed, misleading methods renamed, dead code deleted. See PLAN_DONE.md.

---

## Phase 26: Remove Portfolio ✅ COMPLETE (commit `a0d9e943`)

All portfolio code deleted (6 files, 11 modifications). See PLAN_DONE.md.

---

## Phase 27: Remove Deprecated Entities ✅ COMPLETE

Deleted TownEntity, VoivodeshipEntity, LandEntity. Migrated `closest_town` to AreaEntity,
`check_missing_towns` to AreaDataLoader. Removed `lands_from_towns`, old load methods,
deprecated getters. Deleted LandsIndexView. Cleaned all PHASE6_DEPRECATED markers.
See PLAN_DONE.md.

---

## Phase 28: Rename Post Slug Arrays + Make Non-Nilable ✅ COMPLETE (commit `a0d9e943`)

Renamed `@tags`→`@tag_slugs`, `@towns`→`@town_slugs`, `@lands`→`@land_slugs`, `@foreign`→`@foreign_slugs`.
Made all four non-nilable with explicit declarations, removing ~40 `.not_nil!` calls across 18 files.
See PLAN_DONE.md.

---

## Phase 30: Duplicate Area Slug Disambiguation ✅ COMPLETE (commit `3557d08a`)

Two-pass slug disambiguation in GenerateAreasForPosts: Pass 1 appends voivodeship (474 towns),
Pass 2 appends gmina type label miejska/wiejska (329 towns) with county slug fallback (15 exception towns).
Removed dedup workaround from AreaDataLoader and `.uniq(&.slug)` from TownsIndexView.
12 new specs. See PLAN_DONE.md.

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

**Decouple Services from `@blog`:** ✅ DONE
All services decoupled. All tremolite base classes decoupled from `@blog`. Template method hooks collapsed.
See PLAN_DONE.md Phase 29.

**Eliminate Late-Bound Properties (Phase 30 idea):**
After Phase 29, several classes use late-bound `property` setters instead of constructor params. These are nilable types requiring `.not_nil!` at use sites. Analyze whether these can be converted to constructor params.

Current late-bound properties:
| Class | Properties | Reason |
|-------|-----------|--------|
| **Renderer** | `validator`, `url_to_output_path_proc`, `image_resizer`, `posts_for_resize`, `all_posts`, `data_manager`, `mod_watcher` | Set after construction because Renderer is created before DataManager, ModWatcher, PostCollection |
| **Validator** | `area_data_loader`, `posts` | Set after posts are initialized |
| **ModWatcher** | `posts_path`, `posts_ext`, `data_path`, `exif_db_path` | Set after construction; exif_db_path only available after DataManager init |
| **PostCollection** | `data_path`, `output_path`, `markdown_wrapper`, `photo_tags`, `exif_db` | markdown_wrapper has circular dep; rest could be constructor params |
| **Post** | `post_collection`, `markdown_wrapper`, `exif_db`, `photo_tags` | Set per-post in initialize_posts loop |
| **DataManager** | `html_buffer` | Set after construction due to Blog init order |

**Circular dependency analysis:**
- `MarkdownWrapper` → needs `RenderContext` → needs `Blog` (self during init)
- This is the only true circular dependency. All other late-bound props exist because of Blog.initialize ordering.
- Possible fix: Construct objects in dependency order in Blog.initialize, passing earlier objects to later ones.
- The MarkdownWrapper circular dep could be broken by making it fully lazy (only created on first use in PostCollection.initialize_posts).

**Estimated benefit:** ~35 `.not_nil!` calls removed, stronger compile-time safety.

**Reusable Ambilight Slideshow Component:**
The portfolio lightbox (blurred dual-layer backlight + drop-shadow) could be extracted into a standalone JS/CSS component reusable across the site. Current candidates:
- **Post galleries** (`/galeria/...`) — replace the basic lightbox with ambilight version
- **Area show pages** — photo section currently has no lightbox at all
- **Timeline page** — photo modal could use the same treatment
- **Photo map page** — sidebar/modal photo view

Refactoring approach:
1. Extract CSS (`.portfolio-lb-outer`, `.portfolio-lb-inner`, lightbox shell) into a shared `ambilight-lightbox.css`
2. Extract JS into a generic `AmbilightLightbox({ photos, index, onClose, onPrev, onNext })` Preact component in its own file (e.g. `data/assets/js/src/ambilight_lightbox.jsx`)
3. The component takes a photo array with `{ src, full_src, alt, exif?, post_url?, post_title? }` — same interface portfolio already uses
4. Add as a shared bundle in `asset_bundles.yml` (e.g. `ambilight-lightbox` composite with the CSS + JS)
5. Each page imports and renders the component with its own photo data

**Photo Perceptual Hash (pipeline command):**
Store color/perceptual hash data per photo alongside EXIF. Enables: finding visually similar photos, color-based search, duplicate detection, "more like this" in galleries. Options: aHash, pHash, dHash, or dominant color extraction. Could run as a pipeline command storing results in a YAML/JSON sidecar.

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

**545 Crystal tests passing, 169 E2E tests passing**

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

**Latest Results: 169 passed, 0 failed, 2 skipped**

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-09*
