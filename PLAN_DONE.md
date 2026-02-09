# Renderer & Views Refactoring - Completed Work

This document archives completed phases and architectural decisions.

---

## Phase 1: Cleanup & Documentation ✅ COMPLETE

**Commit `9ddf621`** (2026-02-01):
- Deleted 14 deprecated view files (`*ListView`, `*MasonryView` variants)
- Removed dead code from renderer mixins
- Created `VIEWS.md` documenting all 50+ active views
- **-731 lines of dead code removed**

---

## Phase 1.5: Testing Infrastructure ✅ COMPLETE

**Commit `95d6ecf`** (2026-02-01):
- Created `RenderContext` class (Context Object pattern)
- Created `MockRenderContext`, `MockPost`, `MockHtmlBuffer` for testing
- Added **96 tests** covering all view categories
- Updated `BaseView` to use context via lazy property

---

## Phase 2: View Registry + Coordinator ✅ COMPLETE

**Decision**: Changed from Pipeline to Registry approach for better:
- Explicit dependency declarations per view
- Queryable "what runs when X changes?"
- Eventually remove mixins entirely

**Created files** (`data/src/view_registry/`):

Core infrastructure:
- `base.cr` - ViewRegistry class with `register()` and `task()` methods
- `coordinator.cr` - RenderCoordinator executes based on what changed
- `setup.cr` - Combines all registrations
- `all.cr` - Requires everything

Tasks (6 registered):
- `tasks/setup_tasks.cr` - dev render, copy assets (priority 1-2)
- `tasks/exif_tasks.cr` - EXIF initialization (priority 4)
- `tasks/cache_tasks.cr` - nav_stats, town_photo, coord_quant (priority 5-6)

Views (35 registered):
- `views/entity_views.cr` - towns, tags, voivodeships, lands (priority 10-13)
- `views/home_views.cr` - home, map, pois (priority 20-22)
- `views/photo_views.cr` - galleries, photo maps (priority 30-35)
- `views/stats_views.cr` - summary, year reports, burnout, towns history/timeline (priority 40-44)
- `views/feed_views.cr` - RSS, Atom, JSON, sitemap, robots (priority 50-58)
- `views/index_views.cr` - towns index, lands index (priority 60-61)
- `views/static_views.cr` - more, about, english, JS pages (priority 90-96)
- `views/debug_views.cr` - posts, camera stuff, missing EXIF (priority 100-102)

Tests:
- `spec/view_registry_spec.cr` - **49 tests** covering registry functionality

**Integration**:
- `blog.cr` - Added `view_registry`, `render_coordinator`, `render_with_registry` methods

**Deleted abandoned files**:
- `data/src/render_pipeline.cr`
- `data/src/render_stages/`

---

## Phase 3: Full Mixin Removal ✅ COMPLETE

**Goal**: All render logic in registry, no mixins

**Completed**:
- Deleted entire `renderer_mixin/` directory (12 files)
- Converted per-post rendering to use `RenderContext.write_output()` directly
- Renderer class is now a thin wrapper with only:
  - `dev_render`, `copy_assets_and_photos`, `site_desc`, `all_mod_watchers`, `render_view`
- All aggregate view logic in `view_registry/tasks/` and `view_registry/views/`
- Fixed view require chains (`base_view.cr`, `page_view.cr`, etc.)
- Deleted deprecated `PostListView::AbstractListView` (-36 lines)
- Deleted deprecated `PostListView::PaginatedListView` (-74 lines)
- Deleted deprecated `TodosView` (-189 lines)
- Refactored spec support: extracted `MockHtmlBuffer`, `MockPost` into separate files, created `all.cr`

**Infrastructure added:**
- `RenderContext.write_output(view)` - render views from registry blocks
- `RenderContext.validator` - access validator from registry blocks
- `RenderContext.posts_descending`, `site_email`, `site_author`, `last_updated_at`, `years` - helpers for feed/stats views
- `Renderer.render_view(view)` - public wrapper for write_output

**Views migrated (35 total):**
- entity_views.cr (4): Towns, Tags, Voivodeships, Lands
- index_views.cr (2): Towns index, Lands index
- home_views.cr (3): Home, Map, POIs
- stats_views.cr (5): Summary, Year reports, Burnout, Towns history/timeline
- static_views.cr (7): More, About, English, JS pages
- feed_views.cr (9): RSS, Atom, JSON files, Sitemap, Robots
- debug_views.cr (3): Debug posts, camera, missing EXIF
- photo_views.cr (2): Photo galleries, Photo maps

---

## Deprecated Code Removed

The old bicycle planner (`/todos/*`) was obsolete and replaced by JS-based pages:
- `/pomysly_tras.html` - Trip Ideas page (renamed from pomysly.html)
- `/pomysly_dla_zdjec.html` - Photo Planner page (renamed from pomysly2.html)

**Files deleted:**
- `views/todos_view.cr`
- `views/post_list_view/abstract_list_view.cr`
- `views/post_list_view/paginated_list_view.cr`
- `renderer_mixin/render_todo.cr` (deleted with all mixins)
- `TodoRouteEntity`
- `TransportPoiEntity`

---

## Architectural Decisions

### Architecture: Registry + Coordinator

Implementation in `data/src/view_registry/`:
- `ViewRegistry` - declares all views/tasks with dependencies
- `RenderCoordinator` - executes based on what changed
- Tasks (priority 1-9) - data preparation, no output
- Views (priority 10-100) - actual rendering

**Why Registry won**:
- Single source of truth for all views and their dependencies
- Queryable: "what runs when posts change?" → `registry.names_depending_on(:posts)`
- Explicit priority controls execution order
- Tasks allow data prep before views render
- Supports gradual mixin removal
- Can generate documentation from registry

**Other options considered**:

- **Command Pattern**: Similar benefits but more files (50+ command classes)
- **Event-Driven**: Hard to trace flow, discoverability problem
- **Render Pipeline**: Views hidden inside stages, less queryable

### View Lifecycle: Context Object Pattern

Implementation in `data/src/render_context.cr`:
- `RenderContext` wraps Blog and provides typed accessors
- Views access `context.posts`, `context.towns`, etc.
- `BaseView` has lazy `context` property
- `MockRenderContext` enables testing without Blog

---

## Registry Structure

### File Structure

```
data/src/view_registry/
  base.cr                 # ViewRegistry class
  coordinator.cr          # RenderCoordinator class
  all.cr                  # Requires everything
  setup.cr                # Combines all registrations
  tasks/
    setup_tasks.cr        # Copy assets, dev render (2 tasks)
    exif_tasks.cr         # EXIF initialization (1 task)
    cache_tasks.cr        # Cache refresh tasks (3 tasks)
  views/
    entity_views.cr       # Towns, tags, voivodeships, lands (4 views)
    home_views.cr         # Home, map, pois (3 views)
    photo_views.cr        # Photo galleries + SVG maps (2 views)
    stats_views.cr        # Summary, year reports, burnout, towns (5 views)
    feed_views.cr         # RSS, Atom, JSON, sitemap, robots (9 views)
    index_views.cr        # Towns index, lands index (2 views)
    static_views.cr       # About, more, JS pages (7 views)
    debug_views.cr        # Debug posts, camera, missing EXIF (3 views)

spec/
  view_registry_spec.cr   # 49 tests
```

**Totals**: 6 tasks + 35 views = 41 entries registered

### Priority Guide

| Priority | Type | Count | Examples |
|----------|------|-------|----------|
| 1-2 | Setup tasks | 2 | dev render, copy assets |
| 4 | EXIF tasks | 1 | init all posts EXIF |
| 5-6 | Cache tasks | 3 | nav_stats, town_photo, coord_quant |
| 10-13 | Entity views | 4 | Towns, tags, voivodeships, lands |
| 20-22 | Home views | 3 | Home, map, pois |
| 30-35 | Photo views | 2 | Galleries (30), maps (35) |
| 40-44 | Stats views | 5 | Summary, year reports, burnout, towns history/timeline |
| 50-58 | Feed views | 9 | RSS, Atom, JSON, sitemap, robots |
| 60-61 | Index views | 2 | Towns index, lands index |
| 90-96 | Static views | 7 | About, more, english, JS pages |
| 100-102 | Debug views | 3 | Debug posts, camera, missing EXIF |

---

## Test Coverage

**View tests (96 tests):**
- PostListView: 8 tests
- DynamicView: 13 tests
- StaticView: 7 tests
- GalleryView: 17 tests
- SpecialView: 8 tests
- PhotoMap: 10 tests
- Other views: 14 tests
- RenderContext/mocks: 14 tests
- Example patterns: 5 tests

**Registry tests (49 tests):**
- ViewRegistry core: 13 tests
- Task registration: 4 tests
- View registration: 8 tests
- Priority ordering: 10 tests
- Dependencies: 11 tests
- Query methods: 6 tests

**Total: 146 tests**

---

## Cost Estimates (Actual)

- **Phase 1 (Cleanup)**: ~2 hours
- **Phase 1.5 (Testing)**: ~2 hours
- **Phase 2 (Registry)**: ~4 hours
- **Phase 3 (Mixin Removal)**: ~3 hours

---

## Phase 11-13: Asset Management & HTML Processing ✅ COMPLETE

**Goal**: Smart asset loading per view with inheritance, external JS files (no runtime Babel), and HTML validation.

### Phase 11: Asset Bundle System ✅

**Commits**: `b9866f83`, `c1c08994`

1. **Bundle Configuration** - Created `data/config/asset_bundles.yml`
   - Granular bundles: `bootstrap-css`, `fontawesome`, `leaflet-css`, `leaflet-js`, etc.
   - Composite bundles: `core`, `leaflet`, `openlayers`, `react-runtime`, `gallery`
   - Integrity hash support for SRI

2. **Asset Bundle Loader** - Created `data/src/services/asset_bundle_loader.cr`
   - Loads bundle config from YAML
   - Resolves composites recursively
   - Merges assets with deduplication
   - Tracks integrity hashes

3. **AssetAware Module** - Created `data/src/views/concerns/asset_aware.cr`
   - `asset_bundles` - base bundles (default: `["core"]`)
   - `additional_bundles` - append to parent's bundles
   - `excluded_bundles` - remove from inheritance
   - `page_js` - optional page-specific JS file
   - `resolved_bundles` - compute final bundle list
   - `assets_html` - generate tags with cache busting

4. **Split head_open.html** - Created modular templates
   - `include/head_meta.html` - charset, viewport, msapplication
   - `include/head_icons.html` - favicons, apple-touch-icons
   - `include/head_feeds.html` - RSS, Atom links

5. **Updated BaseView**
   - Included `AssetAware` module
   - New `head_open_html_with_bundles` method
   - Fallback to legacy `head_open_html_legacy` if no bundle loader

6. **View Bundle Declarations**
   - `AreaShowView` - `["leaflet", "react-runtime"]`
   - `MapView` - `["openlayers"]`
   - `JsIdeasView` - `["ideas-css", "leaflet", "react-runtime"]`
   - `JsTimelineView` - `["leaflet", "timeline-js"]`
   - `GalleryView::AbstractView` - `["gallery"]`
   - `CollectionDynamicView` - `["post-collection-js"]`

### Phase 12: External JavaScript ✅

1. **Directory Structure** - Created `data/assets/js/src/`

2. **Extracted nav_stats.js** (~30 lines)
   - From inline script in `navigation/js_overload.html`
   - To `data/assets/js/self/nav_stats.js`
   - Loaded via `nav-js` bundle (part of `core`)

3. **Extracted post_collection.js** (~200 lines)
   - From inline script in `post_collection/dynamic.html`
   - To `data/assets/js/self/post_collection.js`
   - Uses JSON config block for template variables
   - Loaded via `post-collection-js` bundle

4. **Extracted timeline.js** (~600 lines)
   - From inline script in `photos/timeline.html`
   - To `data/assets/js/self/timeline.js`
   - Template reduced from 1521 to 663 lines (CSS + HTML only)
   - Loaded via `timeline-js` bundle

### Phase 13: HTML Processing & Validation ✅

1. **HtmlProcessor Service** - Created `data/src/services/html_processor.cr`
   - Removes HTML comments (preserves IE conditionals)
   - Runs validators on output
   - Returns processed HTML with errors/warnings

2. **HTML Validators** - Created `data/src/services/html_validators/`
   - `MissingTitleValidator` - Checks `<title>` exists
   - `EmptyTitleValidator` - Checks `<title>` not empty
   - `DuplicateIdValidator` - Checks no duplicate IDs
   - `UnprocessedPlaceholderValidator` - Checks no `{{...}}` left
   - `MissingAltValidator` - Warns on `<img>` without `alt`
   - `MissingLangValidator` - Warns on `<html>` without `lang`
   - `InvalidHrefValidator` - Warns on `href="#"` or empty

3. **Integration** - Added `validate_html_output` to `validator.cr`

### Files Created

| File | Purpose |
|------|---------|
| `data/config/asset_bundles.yml` | Bundle definitions |
| `data/src/services/asset_bundle_loader.cr` | Load and resolve bundles |
| `data/src/views/concerns/asset_aware.cr` | Asset mixin with inheritance |
| `data/src/services/html_processor.cr` | Comment removal, validation |
| `data/src/services/html_validators/base.cr` | Validator interface |
| `data/src/services/html_validators/title_validators.cr` | Title checks |
| `data/src/services/html_validators/duplicate_id_validator.cr` | Duplicate ID check |
| `data/src/services/html_validators/placeholder_validator.cr` | Unprocessed `{{}}` check |
| `data/src/services/html_validators/accessibility_validators.cr` | Alt/lang checks |
| `data/src/services/html_validators/link_validators.cr` | Href checks |
| `data/src/services/html_validators/all.cr` | Require all validators |
| `data/layout/include/head_meta.html` | Meta tags only |
| `data/layout/include/head_icons.html` | Favicons only |
| `data/layout/include/head_feeds.html` | RSS/Atom links only |
| `data/assets/js/self/nav_stats.js` | Navigation stats loader |
| `data/assets/js/self/post_collection.js` | Post collection dynamic loader |
| `data/assets/js/self/timeline.js` | Photo timeline viewer |
| `spec/services/html_validators_spec.cr` | Validator tests |
| `spec/services/asset_bundle_loader_spec.cr` | Bundle loader tests |

### Test Results

**220 tests passing** (199 original + 8 AssetBundleLoader + 13 HtmlValidators)

---

---

## Phase 15: CSS Cleanup ✅ COMPLETE

**Completed**: 2026-02-04

### What Was Done
1. Deleted unused `css/tmp/` directory (76K, 11 files)
2. Merged `clean-blog.css` into `new.css` (single base CSS file)
3. Removed unused classes: `site-heading`, `page-heading`, `post-todo`
4. Removed duplicate rules and obsolete vendor prefixes
5. Added symbol-based `page_css` support for page-specific CSS

### CSS Structure (After Cleanup)

| File | Size | Loaded By |
|------|------|-----------|
| `new.css` | 17K | All pages (via `core` bundle) |
| `new_gallery.css` | 7K | Gallery pages (via `page_css: ["gallery"]`) |
| `coord_photo.css` | 2K | Gallery pages (via `page_css: ["gallery"]`) |
| `ideas.css` | 6K | Ideas page (via `page_css: ["ideas"]`) |
| `ol-blog.css` | 1K | Map page (via `openlayers` bundle) |

### Savings
- Deleted 76K unused CSS (`css/tmp/`)
- Reduced clean-blog.css by ~0.5K (duplicates, empty rules)
- Total: **~77K saved**

---

## Phase 18: Blog Article Visual Improvements ✅ COMPLETE

**Completed**: 2026-02-04

### Article Styling

**CSS Changes (`new.css`):**
- Article typography: Georgia serif, 1.125rem, line-height 1.75
- Photo captions: cleaner hierarchy with `.photo-caption-title`
- EXIF overlay: small text in bottom-right corner of photo, visible on hover
- Dark mode support for captions

**HTML Changes (`post/post_image_partial.html`):**
- EXIF moved inside `<a>` tag as `<span class="photo-exif">` for overlay positioning
- Caption title wrapped in `<span class="photo-caption-title">`

### ImageResizer Upgrade

**Analysis:**
- Original photos are 2048px wide
- Content column is ~760px
- 1000px gives good HiDPI coverage (1.3x)

**Old 6-size structure:**
```crystal
@@sizez = {
  "medium"       => {width: 750, height: 600, quality: 88},
  "small"        => {width: 600, height: 450, quality: 80},
  "thumb"        => {width: 60, height: 40, quality: 65},
  "big_thumb"    => {width: 150, height: 100, quality: 70},
  "gallery_thumb"=> {width: 320, height: 200, quality: 84},
  "gallery"      => {width: 450, height: 350, quality: 85},
}
```

**New 4-size structure:**
```crystal
@@sizez = {
  "article"   => {width: 1000, height: 800, quality: 85},
  "card"      => {width: 700, height: 525, quality: 82},
  "grid"      => {width: 560, height: 420, quality: 80},
  "thumbnail" => {width: 150, height: 112, quality: 72},
}
```

**Migration mapping:**
| Old Name | New Name | Notes |
|----------|----------|-------|
| medium | article | Increased 750→1000px |
| small | card | Increased 600→700px |
| thumb | thumbnail | Merged with big_thumb |
| big_thumb | thumbnail | Merged with thumb |
| gallery_thumb | grid | Increased 320→560px |
| gallery | article | Merged - 1000px works for lightbox |

**Files Updated:**
- `data/src/image_resizer.cr` - New size definitions
- `data/src/tremolite/tremolite/image_resizer.cr` - Base class defaults
- `data/src/models/photo_entity.cr` - Constants renamed (THUMBNAIL_PREFIX, etc.)
- `data/src/post/photos.cr` - Method names updated
- `data/src/views/special_view/photos_json_generator.cr` - JSON field names
- `data/assets/js/src/area_show.jsx` - JS field references
- `data/src/views/gallery_view/abstract_view.cr` - Added react-runtime bundle

**Trade-offs:**
- +23% storage (603KB vs 493KB per photo)
- Better quality at larger sizes
- 33% fewer files to generate (4 vs 6 sizes)

---

## Phase 16: Bootstrap 5 Migration ✅ COMPLETE

**Completed**: 2026-02-04

### Goal
Upgrade Bootstrap 4 → 5 to remove jQuery dependency (-88K).

### What Was Done

1. **Downloaded Bootstrap 5.3.3 JS** (CSS was already 5.3.8)

2. **Updated data attributes:**
   - `data-toggle` → `data-bs-toggle`
   - `data-target` → `data-bs-target`
   - `data-placement` → `data-bs-placement`

3. **Updated utility classes:**
   - `mr-auto` → `me-auto`
   - `ml-auto` → `ms-auto`

4. **Rewrote `map.js` to vanilla JS** (removed all jQuery usage)

5. **Updated asset bundles:**
   - Removed jQuery from `core` bundle
   - Removed OpenLayers bundle (replaced with Leaflet)

6. **Fixed tooltip initialization** - Bootstrap 5 requires explicit JS init

### Files Updated

| File | Changes |
|------|---------|
| `data/layout/include/navigation/static.html` | `data-toggle` → `data-bs-toggle` |
| `data/layout/post/pager_*.html` | Tooltip data attributes |
| `data/assets/js/self/map.js` | Vanilla JS rewrite |
| `data/assets/js/self/nav_stats.js` | Tooltip init |
| `data/config/asset_bundles.yml` | Removed jQuery, OpenLayers |

### Savings

| Before | After | Savings |
|--------|-------|---------|
| jQuery 88K | 0 | **-88K** |
| OpenLayers 738K | 0 | **-738K** (replaced with Leaflet) |

---

## Phase 17: Preact Migration ✅ COMPLETE

**Completed**: 2026-02-04

### Goal
Replace React (~140KB) with Preact (~25KB) for 82% size reduction.

### What Was Done

1. **Downloaded Preact UMD files** to `data/assets/js/libs/`:
   - `preact.umd.js` (11K)
   - `preact-hooks.umd.js` (4K)
   - `preact-compat.umd.js` (10K)
   - `preact-shim.js` (0.3K) - aliases Preact to React globals

2. **Updated `asset_bundles.yml`:**
   - Changed `react` bundle to use Preact files

3. **Fixed React API usage:**
   - Changed React 18 `createRoot().render()` → React 17 `ReactDOM.render()`
   - Preact compat only supports React 17 API

4. **Updated files:**
   - `data/assets/js/src/*.jsx` - Source files
   - `data/assets/js/self/*.js` - Transpiled files
   - `data/layout/panoramio.html` - Inline script

### Savings

| Before | After | Savings |
|--------|-------|---------|
| React 139K | Preact 25K | **-114K (82%)** |

---

## Phase 16-17 Total Savings

| Item | Savings |
|------|---------|
| jQuery removal | -88K |
| OpenLayers → Leaflet | -738K |
| React → Preact | -114K |
| **Total** | **-940K** |

---

## Phase 19: Tag Filtering & More Page ✅ COMPLETE

**Completed**: 2026-02-05

### Tag Post List Filtering Fix

**Problem**: Tag pages (`/wpisy-dla/tagu/rowerem.html`) showed all posts instead of filtered ones.

**Root Cause**: `post_collection.js` read configuration at script load time (top-level variable), before DOM had the `#post-collection-config` element available.

**Fix**: Moved config reading inside `loadPosts()` function which runs on DOMContentLoaded.

```javascript
// Before (broken) - config read at top level
var CONFIG = getConfig();  // DOM not ready!
var FILTER_BY = CONFIG.filterBy || '';

// After (fixed) - config read inside loadPosts()
function loadPosts() {
  var CONFIG = getConfig();  // DOM is ready
  FILTER_BY = CONFIG.filterBy || '';
  // ... rest of function
}
```

### E2E Tests for Tag Filtering

Created `tests/e2e/specs/tag-filtering.spec.js`:
- Bicycle tag page loads and shows posts
- Only shows posts with bicycle tag (count verification)
- Hike tag page loads and shows posts
- Only shows posts with hike tag (count verification)
- Filter configuration verification for both pages
- No JS errors check

### NewMoreView and Footer Updates

**Footer changes:**
- Removed GitHub link
- Changed RSS link → Galeria (/galeria.html)
- Added Więcej link (/wiecej.html)
- Moved O mnie to bottom position

**New More Page (`/wiecej.html`):**
- Created `NewMoreView` with modern homepage styling
- Card-based link grid with SVG icons
- Clean design with single link to Panoramio map

**Old More Page:**
- Moved to `/wiecej2.html`
- Marked as DEPRECATED in code

### CSS Refinements

**Body margin fix:**
- Browser default 8px margin caused background color mismatch
- Added `body { margin: 0; padding: 0; }` to both `new.css` and `new-home.css`

**Nav/footer background:**
- Adjusted frosted glass effect colors
- Light mode: slightly darker (`rgba(245,245,244,0.92)`)
- Dark mode: slightly lighter (`rgba(35,35,35,0.92)`)

### URL Changes

- About page: `/o_mnie.html` → `/o-mnie.html`
- Added redirect from old URL using `TemporaryRedirectView`

### Files Changed

| File | Changes |
|------|---------|
| `data/assets/js/self/post_collection.js` | Fixed config reading timing |
| `data/assets/css/self/new.css` | Body margin reset, nav-bg colors |
| `data/assets/css/self/new-home.css` | Body margin, nav-bg, more-links grid |
| `data/src/views/new_more_view.cr` | New view class |
| `data/src/views/static_view/more_view.cr` | Changed URL, marked deprecated |
| `data/src/view_registry/views/static_views.cr` | NewMoreView, about redirect |
| `data/layout/more/new.html` | New template |
| `data/layout/include/footer_new.html` | Updated links |
| `data/layout/home/new.html` | Updated footer links |
| `tests/e2e/specs/tag-filtering.spec.js` | New test file |

### Test Results

**E2E Tests: 44 passed, 0 failed, 5 skipped**

---

## Phase 8: External (Foreign) Areas ✅ COMPLETE

**Completed**: 2026-02-06

### Goal
Handle areas outside Poland (Czech Republic, Switzerland, Germany, Italy) with dedicated URL pattern and post rendering.

### What Was Done

1. **New `foreign:` key in post YAML** - Separates external areas from Polish towns
   ```yaml
   towns: [poznan]           # Polish only
   foreign: [czechy_praga]   # External areas
   ```

2. **External areas config** - Created `data/config/areas/external_areas.yml`
   - Country name lookup (for plain text fallback)
   - Area definitions with country field

3. **URL pattern** - `/zagranica/<slug>.html`
   - Show page: `/zagranica/czechy_praga.html` (not implemented yet)
   - Post list: `/wpisy-dla/zagranica/czechy_praga.html`

4. **"Zagranica" section in posts** - Renders after Województwa
   - External areas with entities → links
   - Country-only slugs → plain text (e.g., "Szwajcaria")

### Model Changes

| File | Changes |
|------|---------|
| `area_entity.cr` | Added `country : String?` field, `external?` method |
| `router.cr` | `/zagranica/` URL pattern for external areas |
| `area_data_loader.cr` | Load external areas, country name lookup |
| `render_context.cr` | `external_areas_with_posts`, `country_name` helpers |
| `post/initializers.cr` | `foreign:` key parsing |
| `post/areas.cr` | `foreign_slugs`, `foreign_entities` methods |
| `article_view.cr` | "Zagranica" section with link/plain text fallback |

### External Areas Defined

**Czech Republic:**
- `czechy_kraj_olomucki` - Kraj Ołomucki (voivodeship)
- `czechy_kraj_morawsko_slaski` - Kraj Morawsko-Śląski (voivodeship)
- `czechy_praga` - Praga (town)

**Country placeholders** (render as plain text until regions added):
- `szwajcaria`, `niemcy`, `wlochy`

### Posts Migrated

16 posts updated from `towns:` to `foreign:` key:
- 6 Czech posts (2018-2019)
- 6 Swiss posts (2022)
- 4 German posts (2025)

### Files Created

| File | Purpose |
|------|---------|
| `data/config/areas/external_areas.yml` | External areas + country lookup |
| `external_area_post_list_view.cr` | Post list view for external areas |

### Test Results

**275 tests passing** (view count updated 39 → 40)

---

## Photo Planner Page Overhaul ✅ COMPLETE

**Completed**: 2026-02-06

### Goal
Transform `/pomysly2.html` (standalone bicycle route planner) into an integrated site page at `/pomysly_dla_zdjec.html` with proper layout, bug fixes, dark mode, and optimized data loading.

### Bugs Fixed

1. **`time_distance` was an object, not a number** - `train_stations.json` output `{"Poznań": 2.5}` but frontend expected a number. Displayed as `[object Object]`. Fix: use `poznan_time_distance` method.
2. **`countCellsOnSegment` wrong argument** - 3rd arg was `segment.from.lon` instead of `segment.to.lat`
3. **Station popup said "km" instead of "h"** for train travel time
4. **Dead code removed** - `generateGoogleMapsLink`, `generateOSRMLink`, `countBlankCellsInRadius`, duplicate comments, console.log calls

### Optimized Data Loading

Created `/jsons/photo_grid.json` (14 KB) replacing `/photos.json` (20 MB) fetch:
- Only lat/lon coordinate pairs needed for the grid
- 99.9% size reduction

### Layout Integration

Converted from standalone `full_html` page to integrated `content` method:
- Uses `load_html("planner/planner", data)` template system
- Gets site nav + footer automatically from `BaseView.to_html`
- Declares `["leaflet"]` additional bundle and `["planner"]` page CSS

### Styling Overhaul

- Created `planner.css` with CSS custom properties (`--p-` prefix)
- Full dark/light mode support via `prefers-color-scheme`
- Panel-based sidebar: duration picker, results, stats grid, legend
- Gradient route card headers, sticky sidebar, responsive breakpoint at 860px

### Files Changed

| File | Action |
|------|--------|
| `data/src/views/special_view/photo_grid_json_generator.cr` | **CREATED** - optimized JSON endpoint |
| `data/src/views/special_view/train_stations_json_generator.cr` | **FIXED** - output number not hash |
| `data/src/views/static_view/photo_planner_view.cr` | **RENAMED** from `js_bicycle_planner_view.cr`, rewritten |
| `data/assets/css/self/planner.css` | **CREATED** - dark/light mode CSS |
| `data/assets/js/self/planner.js` | **CREATED** - extracted/fixed JS |
| `data/layout/planner/planner.html` | **CREATED** - body-only template |
| `data/config/asset_bundles.yml` | Added `planner` page-asset |
| `data/src/view_registry/views/feed_views.cr` | Registered photo grid JSON (priority 56) |
| `data/src/view_registry/views/static_views.cr` | Renamed entry + URL |
| `data/src/views/new_more_view.cr` | Added planner link |
| `tests/e2e/specs/js-pages.spec.js` | 12 tests for photo planner |

### Deleted Files

- `data/layout/map/bicycle_planner.full.html`
- `data/layout/map/bicycle_planner.html`
- `data/layout/map/bicycle_planner.head.html`
- `data/assets/js/tmp/planner.js` (old BlogPlanner)
- `data/assets/js/tmp/planner.coffee`
- `data/layout/planner.html` (old BlogPlanner template)

### Test Results

**275 Crystal tests passing, ~93 E2E tests passing**

---

## Phase 21: Area Show Page Redesign ✅ COMPLETE

**Completed**: 2026-02-07

### Goal
Redesign the area show page (`/gmina/*.html`, etc.) with visual improvements, performance optimization, and new features.

### Visual Changes

1. **Removed intro-header interference** — Override `content` to skip PageView's `<header class="intro-header">` that conflicted with the full-viewport hero
2. **Hero photo + map blend** — Three layers: best photo background (fixed), Leaflet map at 0.35 opacity, text overlay with gradient. Fallback: map at full opacity if no photo
3. **Hero map fade-in** — Map starts invisible, fades in (0.8s transition) after polygon loads + 600ms delay, so tile loading/zooming is hidden
4. **Year range in hero** — Shows "2019–2024" below area name instead of verbose stat cards
5. **Compact stats bar** — Replaced 4 bulky stat cards with single inline line: `12 wypraw · 340km · 26h · 185 zdjec`
6. **Working navigation links** — "Wszystkie wpisy" and "Pelna galeria" now link to actual post list and gallery URLs (were `#`)
7. **Tight photo matrix** — CSS grid with `gap: 1px`, 5:4 aspect ratio, no borders/rounding, hover overlay
8. **Vertical post cards** — Full-width rows with image on left, text on right (stacks on mobile)
9. **Related areas section** — Photo-background cards with area name overlay, replaces text-link footer
10. **Standalone map section** — Interactive Leaflet map (draggable, zoomable) in main content area

### Performance Optimization (4x speedup: 1100ms → 272ms)

| Problem | Before | After |
|---------|--------|-------|
| `AreaPhotoSelector` creation | 3-4x per page | 1x total via `context.photo_selector` |
| `posts_for_area()` | Full scan every call | Memoized by `area_type:slug` in RenderContext |
| `areas_with_posts()` | Recomputed on every call | Memoized by AreaType in RenderContext |
| Photo array `flat_map` | 3-4x per page | 1x total inside shared selector |

### Related Areas Algorithm

Fuzzy scoring for finding 2-4 related areas:
- BBox overlap (weighted 10x) via `intersection_area`
- Shared posts (2x per shared post)
- Same voivodeship bonus (+1)
- Random multiplier (`rand(0.8..1.2)`) for variety
- Candidates: Towns and MesoRegions with posts

### Sorted Rendering

All area views (show, post list, gallery) now render in sorted order by slug for deterministic output.

### Shared Map Logic

Extracted `initLeafletMap()` function shared between:
- Hero map (non-interactive, fade-in)
- Content map section (interactive, draggable)

### Files Changed

| File | Changes |
|------|---------|
| `data/src/views/area_show_view.cr` | Override content, add URLs/photo/related areas, use shared selector |
| `data/src/render_context.cr` | Memoized `posts_for_area`, `areas_with_posts`, shared `photo_selector` |
| `data/layout/area/show.html` | Complete CSS rewrite, new config fields |
| `data/assets/js/src/area_show.jsx` | All components redesigned, shared map init |
| `data/assets/js/self/area_show.js` | Regenerated via esbuild |
| `data/src/view_registry/views/area_views.cr` | Sorted rendering by slug |

### Test Results

**274 Crystal tests passing, 110 E2E tests passing**

---

## Phase 22: Towns Index Page ✅ COMPLETE

**Completed**: 2026-02-07

### Goal
Replace the old `ModelView::TownsIndexView` (basic `<ol>` list of all 2477 towns) with a modern, interactive Preact-powered page showing only ~500 towns with posts, grouped by voivodeship, with search/filter and photo cards.

### Architecture
Same pattern as area show page: Crystal generates inline JSON, HTML template provides CSS + structure, JSX provides interactive UI.

### What Was Done

1. **Crystal View** — Rewrote `TownsIndexView` with `load_html("towns/index", data)` template
   - Inline JSON: voivodeships array + towns array (only towns with posts)
   - Hero image: last finished post's card photo (fallback to config background)
   - Deduplicates towns by slug (`.uniq(&.slug)`)
   - Own `AreaPhotoSelector` instance for unique photo tracking

2. **HTML Template** — Created `data/layout/towns/index.html`
   - Hero section with background photo, title overlay
   - CSS grid card layout (4-5 cols desktop, 2 cols mobile)
   - Town cards: photo background, name overlay, post count badge, year range
   - Fixed dark navbar over hero
   - Dark mode support

3. **JSX Components** — Created `data/assets/js/src/towns_index.jsx`
   - `TownsIndexApp` (root), `SearchBar`, `VoivodeshipGroup`, `TownCard`
   - Instant search filtering with `useMemo`
   - Empty voivodeships auto-hidden when filtering
   - "No results" message for empty search

4. **Unique Photos** — Added `best_unique_photo_for` to `AreaPhotoSelector`
   - Tracks used photos via `@used_photos : Set(String)`
   - Prevents same photo appearing on multiple town cards
   - Falls back to closest unused photo if all bbox photos taken

5. **Voivodeship Slug Fix** — Fixed hyphen in `warminsko-mazurskie` slug
   - `data/external/voivodeships.yaml` and `data/config/areas/voivodeships.yml`

### Files Created

| File | Purpose |
|------|---------|
| `data/layout/towns/index.html` | Template with CSS + hero + mount point |
| `data/assets/js/src/towns_index.jsx` | Preact components (source) |
| `data/assets/js/self/towns_index.js` | Transpiled JS output |
| `tests/e2e/specs/towns-index.spec.js` | 8 E2E tests |

### Files Modified

| File | Changes |
|------|---------|
| `data/src/views/model_view/towns_index_view.cr` | Complete rewrite with load_html + inline JSON |
| `data/src/services/area_photo_selector.cr` | Added `best_unique_photo_for`, `@used_photos` tracking |
| `data/external/voivodeships.yaml` | Fixed `warminskomazurskie` → `warminsko-mazurskie` |
| `data/config/areas/voivodeships.yml` | Fixed `warminskomazurskie` → `warminsko-mazurskie` |

### Key Decisions

- **Component named `TownsIndexApp`** (not `TownsIndex`) to avoid global scope collision with `window.TownsIndex = { init: fn }` when using `--bundle=false` esbuild
- **Own `AreaPhotoSelector` instance** per view — shared `context.photo_selector` would cause cross-view side effects from unique photo tracking
- **No search icon** — FontAwesome `fa-search` rendered as square on this page, removed in favor of centered placeholder text
- **Inline JSON via `<script type="application/json">`** — safer than template interpolation directly in JS

### Test Results

**274 Crystal tests passing, 118 E2E tests (8 new)**

---

## Phase 20: JSON Optimization (Partial) ✅ MOSTLY COMPLETE

**Completed**: 2026-02-08

### Phase 20a: Quick Wins & JSON Moves ✅

- Removed `card_url` from `PhotosJsonGenerator` (~2.66 MB savings)
- Disabled/deregistered `nav_stats.json` (unused by frontend)
- Moved `train_stations.json` → `/jsons/train_stations.json`
- Moved `ideas.json` → `/jsons/ideas.json`
- Replaced `payload.json` with `/jsons/e2e.json` (minimal data for E2E smoke tests only)
- All other JSON endpoints already under `/jsons/`
- **Remaining:** `/photos.json` still at root (20MB, needs moving)

### Phase 20b: Map JSON ✅

- Created `/jsons/map.json` via `MapJsonGenerator`
- Posts with coords, minimal metadata (slug, title, date, distance, time_spent, card_image_url)
- 16 KB vs 836 KB original payload.json usage (98% reduction)
- Updated `map_leaflet.js` to use new endpoint

### Phase 20c: Summary JSON — REMOVED

Summary page (`/zestawienie.html`) deleted. No longer needed.

### Phase 20d: Photos Map JSON ✅

- Created `/jsons/photos_map.json` via `PhotosMapJsonGenerator`
- Only photos with lat/lon, excludes detailed EXIF (aperture, exposure, iso, focal)
- Updated `panoramio.html` to use new endpoint

### Test Results

**271 Crystal tests passing, 141 E2E tests passing**

---

## Phase 23: Centralized Profiler ✅ COMPLETE

**Completed**: 2026-02-08

### Goal
Replace scattered manual timing (6 variables, 3 "Phase:" log lines, manual summary block) with a single annotation-based profiler system.

### Architecture

- `@[Profile(category: "yaml")]` annotation marks methods for timing
- `include Profiled` in a class triggers `finished` macro hook that auto-wraps annotated methods with `previous_def`
- `Profiler.measure("cat", "name") { ... }` for dynamic names / cross-object calls
- `Profiler.summary` prints category breakdown + top 10 slowest
- To disable: just remove `include Profiled` — annotations become inert

### Files Created

| File | Purpose |
|------|---------|
| `data/src/services/profiler.cr` | `Profile` annotation, `Profiler` class (measure, record, summary, reset, enabled?) |
| `data/src/services/profiled.cr` | `Profiled` module with `finished` macro hook |

### Files Modified

| File | Changes |
|------|---------|
| `data/src/blog.cr` | `Profiler.reset`/`measure`/`summary`, removed 6 timing vars + manual summary |
| `data/src/view_registry/coordinator.cr` | `Profiler.measure("registry", entry.name)` replaces manual timing |
| `data/src/data_manager.cr` | `@[Profile(category: "yaml")]` on 8 load methods |
| `data/src/post_renderer.cr` | `@[Profile(category: "posts")]` on 2 render methods |
| `data/src/validator.cr` | `@[Profile(category: "validation")]` on 3 private methods |

### Macro Gotcha

Crystal nested macros (`macro finished` inside `macro included`) cannot use `\{% if %}` / `\{% end %}` — the parser consumes the `end` for the outer macro. Fix: use ternary operator for visibility check.

### Test Results

**409 Crystal tests passing, 141 E2E tests passing**

---

## Phase 9: Command Restructure ✅ COMPLETE

**Completed**: 2026-02-09

### Goal
Restructure all standalone Crystal command scripts (`commands/*.cr`) into a shared library under `data/src/commands/` with thin entry-point wrappers, shared initialization, and a unified pipeline runner.

### Architecture

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
```

### What Was Done

1. **Created `data/src/commands/base.cr`** — `Commands` module with `ENVS` constant and `init_blog` helper for shared Blog initialization
2. **Created pipeline commands** (4) — `generate_areas_for_posts`, `generate_polygon_json`, `assign_photos_to_areas`, `gpx_rectify` — all accept optional `AreaMatcher::Matcher` for shared loading
3. **Created tool commands** (3) — `fetch_map_tiles`, `list_missing_routes`, `test_region_matching`
4. **Rewrote all 7 `commands/*.cr` entry points** as thin wrappers delegating to `data/src/commands/`
5. **Created `commands/run_all.cr`** — unified pipeline runner that shares a single `AreaMatcher::Matcher` instance (~90MB loaded once instead of per-command)
6. **Fixed `Map::Downloader::PUBLIC_PATH`** — corrected path to `env/full/public/local/tiles`
7. **Fixed broken require** in `lists_posts_missing_detailed_route.cr`

### Key Design Decisions

- **Pipeline vs Tools separation** — Pipeline commands process data in sequence and benefit from shared state (AreaMatcher). Tools are standalone utilities.
- **Optional `AreaMatcher::Matcher` parameter** — Pipeline commands can create their own matcher if run individually, or receive a shared one from `run_all.cr`
- **2 commands deferred** — `generate_photo_map.cr` and `generate_maps_for_route_ideas.cr` remain as-is (more complex dependencies, less frequently used)

### Files Created

| File | Purpose |
|------|---------|
| `data/src/commands/base.cr` | Commands module, ENVS, init_blog helper |
| `data/src/commands/all.cr` | Require aggregator |
| `data/src/commands/pipeline/all.cr` | Pipeline require aggregator |
| `data/src/commands/pipeline/generate_areas_for_posts.cr` | Area-post matching command |
| `data/src/commands/pipeline/generate_polygon_json.cr` | GeoJSON generation command |
| `data/src/commands/pipeline/assign_photos_to_areas.cr` | Photo-area assignment command |
| `data/src/commands/pipeline/gpx_rectify.cr` | GPX rectification command |
| `data/src/commands/tools/all.cr` | Tools require aggregator |
| `data/src/commands/tools/fetch_map_tiles.cr` | Map tile downloader |
| `data/src/commands/tools/list_missing_routes.cr` | Missing route lister |
| `data/src/commands/tools/test_region_matching.cr` | Region matching tester |
| `commands/run_all.cr` | Unified pipeline runner |

### Files Modified

| File | Changes |
|------|---------|
| `commands/generate_areas_for_posts.cr` | Thin wrapper delegating to pipeline |
| `commands/generate_polygon_json.cr` | Thin wrapper delegating to pipeline |
| `commands/assign_photos_to_areas.cr` | Thin wrapper delegating to pipeline |
| `commands/gpx_rectify.cr` | Thin wrapper delegating to pipeline |
| `commands/fetch_map_tiles.cr` | Thin wrapper delegating to tools |
| `commands/list_missing_routes.cr` | Thin wrapper delegating to tools |
| `commands/test_region_matching.cr` | Thin wrapper delegating to tools |

### Tests Added

28 new Crystal specs:
- `spec/commands/base_spec.cr` — Commands module tests
- `spec/commands/assign_photos_manifest_spec.cr` — Manifest/incremental processing tests
- `spec/commands/douglas_peucker_spec.cr` — Polygon simplification tests
- `spec/commands/tools_spec.cr` — Tool command tests

### Test Results

**444 Crystal tests passing, 161 E2E tests passing**

---

## Phase 21b: Map Service Restructure ✅ COMPLETE

**Completed**: 2026-02-08

### Goal
Full restructure of `data/src/services/map/` — separated computation from rendering, added multi-format output, consolidated views, wrote comprehensive tests.

### What Was Done

1. Bug fixes: typos (DEFAULTH, time→tile, dimenstion), dead code removal (sleep, fix_crossing_photos, unused vars)
2. MapConfig & MapContext structs with factory methods for all 11 use cases
3. MapPipeline + MapResult (computation/rendering separation), PhotoSelection module
4. SvgRenderer, PngRenderer (rsvg-convert), LeafletJsonRenderer
5. View consolidation: 9 → 4+2 (GlobalMapSvgView, AreaMapSvgView, + kept PostBig/PostRoute/Idea)
6. Tests: 116 new tests (387 total, up from 271)

### Architecture

```
MapConfig + MapContext → MapPipeline.compute → MapResult → SvgRenderer / LeafletJsonRenderer / PngRenderer
```

Old path (`Map::Base` → `Map::Main` → `.to_svg`) still works alongside — consolidated views use old path for now.

### Performance: SpatialIndex

**Bottleneck (fixed): GridLayer photo selection** — was O(cells × photos) per map.

Implemented `SpatialIndex` (`data/src/services/map/spatial_index.cr`): pre-buckets photos into a hash grid keyed by `{floor(lat/0.05), floor(lon/0.05)}`. Each query checks only overlapping buckets (1–4 typical) instead of scanning all photos.

| Scenario | Cells | Linear | Spatial | Speedup |
|----------|-------|--------|---------|---------|
| Coarse (zoom 8, photo_size=160) | 384 | 115 ms | 5.4 ms | **21x** |
| Fine (zoom 10, photo_size=50) | 62,935 | 12.3 sec | 29 ms | **421x** |

---

## Phase 24: Polygon-Based Photo-to-Area Assignment ✅ COMPLETE

**Completed**: 2026-02-09

### Goal
Replace inaccurate bbox-based photo selection on area show pages with precise polygon point-in-polygon matching using GEOS.

### Architecture

```
commands/assign_photos_to_areas.cr   ← Offline script (run manually)
         ↓ uses
AreaMatcher::Matcher.match_point()   ← GEOS polygon testing
         ↓ writes
env/<env>/cache/photos_in_area/      ← Per-area YAML cache
         ↓ read by
PhotoAreaCache                       ← Build-time cache reader service
         ↓ used by
AreaShowView.collect_area_photos     ← Returns cached photos (no bbox fallback)
```

### Files Created/Modified

- `commands/assign_photos_to_areas.cr` — Offline command with incremental processing, `--overwrite` flag
- `data/src/services/photo_area_cache.cr` — Build-time cache reader
- `spec/services/photo_area_cache_spec.cr` — 7 specs
- `tests/e2e/specs/area-show.spec.js` — 20 E2E tests
- `data/src/views/area_show_view.cr` — Uses cache, no bbox fallback

**Results (full env):** 6,059 geo-tagged photos assigned to 1,037 area-slug pairs across 5 area types.

---

## Phase 25 Batch 1: Post Code Cleanup + Tests ✅ COMPLETE

**Committed**: `bcd57b76` (2026-02-09)

### Goal
Make PhotoEntity testable, remove dead code, fix duplicate declarations, add model specs.

### What Was Done

1. **PhotoEntity Post-free constructor** — Added constructor accepting `post_slug`, `post_url`, `post_time`, `post_title` directly (no `Tremolite::Post` needed). Original constructor delegates to it.

2. **PhotoTagEntity direct constructor** — Added `initialize(@slug, @slug_pl, @title, @points, @subtitle)` for test use.

3. **Dead code removed:**
   - Deleted `data/src/post/related_by_distance.cr` (entire file, 3 dead methods)
   - Deleted `related_posts_by_town` + `is_related_to_other_post_by_towns?` from `related_posts.cr`
   - Deleted `voivodeships` + `was_in_voivodeship` from `accessors.cr`
   - Deleted commented-out voivodeship code from `initializers.cr` (lines 86-96)
   - Deleted `ensure_posts_have_assigned_lands` from `post_collection.cr`
   - Deleted unused `exif_db` method from `post_coord_quant_cache.cr`
   - Removed `require "./post/related_by_distance"` from `post.cr`

4. **Fixed duplicate `@head_photo_entity`** — Removed declaration from `photos.cr` (kept in `initializers.cr`)

5. **Tests added:**
   - `spec/models/photo_entity_spec.cr` — 34 tests (construction, points, tags, params, image paths, comparison)
   - `spec/models/photo_tag_entity_spec.cr` — 4 tests (YAML constructor, direct constructor, view_url)

### Test Results

**486 Crystal tests passing** (444 → 486), 161 E2E tests passing

---

## Phase 25 Batch 2: Code Audit Fixes ✅ COMPLETE

**Commit `a0d9e943`** (2026-02-09)

### Bugs Fixed
- **25a.** Deleted `@is_published` field + `mark_as_published!` entirely from PhotoEntity and ExifDb (dead field, setter wrote wrong ivar)
- **25b.** Fixed YearStatReportView hike opacity — was checking `bicycle_opacity` instead of `hike_opacity`
- **25c.** Fixed LandEntity YAML key — `y["country"]` → `y["code"]`

### Misleading Names Renamed
- **25d.** `haversine_distance` → `euclidean_distance_approx` (was Pythagorean, not Haversine)
- **25e.** `externally_propelled?` — fixed implicit nil return to `train? || car? || bus?`
- **25f.** `IMAGE_FORMAT_M43 = :m34` → `:m43` (symbol typo)
- **25g.** `content_html_missing_reference_links` → `content_html_reference_pattern_count`

### Dead Code Deleted
- `check_missing_referenced_links` from validator.cr (30 lines)
- Commented-out `title` method from accessors.cr
- Workaround comment from photos_json_generator.cr

---

## Phase 26: Remove Portfolio ✅ COMPLETE

**Commit `a0d9e943`** (2026-02-09)

Deleted all portfolio code:
- **6 files deleted:** portfolio_entity.cr, portfolio_view.cr, 3 templates, portfolio.yml
- **11 files modified:** removed requires, data manager fields, render context accessor, registry entry, photo tag, config entries, JS weight, spec

---

## Phase 28: Rename Post Slug Arrays + Make Non-Nilable ✅ COMPLETE

**Commit `a0d9e943`** (2026-02-09)

Renamed Post instance variables to clarify they hold slug strings:
- `@tags` → `@tag_slugs`, `@towns` → `@town_slugs`, `@lands` → `@land_slugs`, `@foreign` → `@foreign_slugs`

Made all four non-nilable with explicit `Array(String)` declarations and defaults, removing ~40 `.not_nil!` calls across 18 files.

### Test Results

**485 Crystal tests passing** (486 → 485, -1 from removed PortfolioView test), 161 E2E tests passing

---

## Phase 27: Remove Deprecated Entities (TownEntity, VoivodeshipEntity, LandEntity) ✅ COMPLETE

Completed migration from deprecated entity system to unified AreaEntity.

### Changes

**Migrated callers:**
- `lands_from_towns` in `post/initializers.cr` — deleted (AreaEntity meso_region associations via area cache are more accurate)
- `closest_town` in `photo_coord_quant_cache.cr` — migrated to use AreaEntity towns from AreaDataLoader
- `check_missing_towns` in `validator.cr` — migrated to use AreaDataLoader for town/voivodeship slugs

**Removed from DataManager:**
- `@towns`, `@town_slugs`, `@voivodeships`, `@lands` instance variables and getters
- `load_towns`, `load_lands`, `load_town_yaml` methods
- `towns_already_visited_only_selfpropelled` (deprecated method)

**Removed from RenderContext:**
- `voivodeships`, `towns`, `lands` proxy methods
- `towns_already_visited_only_selfpropelled` proxy
- PHASE6_DEPRECATED comment blocks

**Deleted files:**
- `data/src/models/town_entity.cr` (103 lines)
- `data/src/models/voivodeship_entity.cr` (101 lines)
- `data/src/models/land_entity.cr` (50 lines)
- `data/src/views/model_view/lands_index_view.cr`

**Cleaned up PHASE6_DEPRECATED markers in:**
- `view_registry/views/index_views.cr` — removed commented lands index block
- `view_registry/tasks/cache_tasks.cr` — removed commented town photo cache block
- `views/dynamic_view/year_stat_report_view.cr` — removed commented voivodeships_stats
- `models/coord_range.cr` — removed commented VoivodeshipEntity constructor
- `services/nav_stats_cache.cr` — removed migration comments
- `spec/view_registry_spec.cr` — removed deprecated comment
- `spec/views/other_views_spec.cr` — removed deprecated comment blocks

**New tests:**
- `spec/models/area_entity_spec.cr` — 11 tests:
  - AreaEntity lat/lon from bbox (2 tests)
  - `PhotoCoordQuantCache.closest_town` class method (4 tests: nearest town, nil cases, skip no-bbox)
  - `Tremolite::Validator.find_missing_towns` class method (5 tests: known/unknown slugs, self-propelled vs not, edge cases)

**Refactored for testability:**
- `closest_town` extracted to `PhotoCoordQuantCache.closest_town(lat, lon, towns)` class method — no Blog dependency
- `check_missing_towns` extracted to `Validator.find_missing_towns(known_slugs, post_data)` class method — pure data in/out

### Test Results

**495 Crystal tests passing** (+11 new, -1 removed deprecated), 161 E2E tests passing

---

## Phase 29: Blog Initialization Simplification + @blog Decoupling ✅ COMPLETE

**Completed**: 2026-02-09

### Goal
Simplify Blog initialization (all 7 callers repeat 8-line constructors) and decouple all tremolite classes from `@blog` so each class receives only what it needs.

### Step 1: Blog.for_env convenience constructor

Added `Blog.for_env(env, target)` that derives all 8 params from just `env` (dev/full) and `target` (local/release). Simplified all 7 callers from 8-line constructors to single-line calls.

| File | Before | After |
|------|--------|-------|
| `data/src/commands/base.cr` | 8-line Blog.new | `Blog.for_env(env)` |
| `env/dev/src/render_local.cr` | 8-line Blog.new | `Blog.for_env("dev", "local")` |
| `env/dev/src/render_release.cr` | 8-line Blog.new | `Blog.for_env("dev", "release")` |
| `env/dev/src/run_local.cr` | 8-line Blog.new | `Blog.for_env("dev", "local")` |
| `env/full/src/render_local.cr` | 8-line Blog.new | `Blog.for_env("full", "local")` |
| `env/full/src/render_release.cr` | 8-line Blog.new | `Blog.for_env("full", "release")` |
| `env/full/src/find_ungeotagged_photos.cr` | 8-line Blog.new | `Blog.for_env("full", "local")` |

### Steps 2-8: @blog decoupling

Each tremolite class was refactored to accept specific params instead of the entire Blog:

| Class | Before | After |
|-------|--------|-------|
| **ImageResizer** | `initialize(@blog)` | `initialize(@data_path, @output_path)` |
| **ModWatcher** | `initialize(@blog, file_path)` | `initialize(file_path)` + injected path properties |
| **Validator** | `initialize(@blog)` | `initialize(@html_buffer)` + injected area_data_loader, posts |
| **Renderer** | `initialize(@blog, @html_buffer)` | `initialize(@html_buffer, @data_path, @output_path, @assets_path)` + late-bound props |
| **DataManager** | `initialize(@blog, @config_path)` | `initialize(@config_path, @data_path, @cache_path, @output_path, @posts_path, @posts_ext)` |
| **Post** | `initialize(@blog, @path)` | `initialize(@path, @data_path, @output_path)` + late-bound deps |
| **PostCollection** | `initialize(@blog, paths)` | `initialize(@posts_path, @posts_ext)` + late-bound deps |
| **BaseView** | `@blog` fallbacks | Context-only (no `@blog` fallback) |

### Step 9: Blog.initialize rewired

Blog.initialize now passes specific params to each constructor and wires late-bound dependencies via properties after construction. `@blog` now only exists in `RenderContext` and `Blog` itself.

### Step 10: Constructor collapse (base+custom → single)

Removed all template method hooks from tremolite base classes:

| Class | Removed Hooks |
|-------|--------------|
| **DataManager** | `custom_initialize`, `custom_load`, `load_data` |
| **Post** | `custom_initialize`, `custom_process_header` |
| **Validator** | `custom_validators` |
| **ModWatcher** | `update_before_save` (empty base) |
| **Renderer** | `render_all` (empty, never overridden) |
| **PostCollection** | `each_post_file` (base version, kept custom override only) |

Constructors moved from base tremolite files to custom files. The `process` method (Post) and `run` method (Validator) moved to custom files with hook content inlined.

### Files Modified

**Base tremolite files (simplified):**
- `data/src/tremolite/tremolite/data_manager.cr` — constructor + hooks removed
- `data/src/tremolite/tremolite/posts/post.cr` — constructor + hooks removed
- `data/src/tremolite/tremolite/posts/post_collection.cr` — base each_post_file removed
- `data/src/tremolite/tremolite/validator.cr` — custom_validators hook removed
- `data/src/tremolite/tremolite/mod_watcher.cr` — update_before_save hook removed
- `data/src/tremolite/tremolite/renderer.cr` — render_all hook removed
- `data/src/tremolite/tremolite/image_resizer.cr` — `@blog` → path params
- `data/src/tremolite/tremolite/views/base_view.cr` — `@blog` fallbacks removed

**Custom files (expanded with constructors):**
- `data/src/data_manager.cr` — full constructor with inlined initialization
- `data/src/post/initializers.cr` — full constructor + process method
- `data/src/validator.cr` — full run method
- `data/src/mod_watcher.cr` — path properties for current_state_of
- `data/src/renderer.cr` — late-bound properties
- `data/src/post_collection.cr` — late-bound properties
- `data/src/post.cr` — exif_db, photo_tags properties

**7 caller files simplified** to `Blog.for_env(...)` (see Step 1)

### Test Results

**533 Crystal tests passing**, 161 E2E tests passing

---

*Last updated: 2026-02-09*
