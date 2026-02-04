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
- `/pomysly.html` - JS Ideas page
- `/pomysly2.html` - JS Bicycle Planner page

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

*Last updated: 2026-02-04*
