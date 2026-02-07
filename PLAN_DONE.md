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

*Last updated: 2026-02-07*
