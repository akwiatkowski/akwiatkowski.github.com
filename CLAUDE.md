# Project Context for Claude Code

This file provides context for maintaining this Crystal static site generator project.
Load this file at the start of a session for project continuity.

## Project Overview

- **Language**: Crystal
- **Type**: Static site generator for a travel/photography blog
- **Posts**: ~100 blog posts with routes, photos, EXIF data
- **Entities**: Towns, tags, voivodeships, lands, meso/macro regions

## Key Documentation Files

| File | Purpose | Update When |
|------|---------|-------------|
| `PLAN.md` | Current and next phase work | Completing tasks, starting new phases |
| `PLAN_DONE.md` | Completed phases archive | Phase completion |
| `PLAN_FUTURE.md` | Future ideas backlog | New ideas, deprioritizing work |
| `VIEWS.md` | Registry documentation | Adding/removing views or tasks |
| `CLAUDE.md` | This file - project context | Structure changes |

## Code Structure

### Core Files

```
data/src/
├── blog.cr              # Main Blog class, render orchestration
├── post_renderer.cr     # Per-post rendering (articles, galleries)
├── render_context.cr    # Context object for views
├── renderer.cr          # Thin wrapper, asset handling
├── data_manager.cr      # Entity loading, caches
└── validator.cr         # Output validation
```

### View Registry (Single Source of Truth for Rendering)

```
data/src/view_registry/
├── base.cr              # ViewRegistry class, PRIORITY_GROUPS, Priority module
├── coordinator.cr       # RenderCoordinator - executes entries
├── setup.cr             # Registration orchestration
├── all.cr               # Requires everything
├── tasks/               # Data preparation (priority 1-9)
│   ├── setup_tasks.cr   #   Priority 1-2: dev render, copy assets
│   ├── exif_tasks.cr    #   Priority 3-4: EXIF initialization
│   └── cache_tasks.cr   #   Priority 5-9: cache refresh
└── views/               # Output rendering (priority 10+)
    ├── entity_views.cr  #   Priority 11: tags only (areas handled by area_views.cr)
    ├── area_views.cr    #   Priority 14-16: area pages (show, post list, gallery)
    ├── home_views.cr    #   Priority 20-29: home, map, POIs
    ├── photo_views.cr   #   Priority 30-39: galleries, photo maps
    ├── stats_views.cr   #   Priority 40-49: summary, year reports
    ├── feed_views.cr    #   Priority 50-59: RSS, Atom, JSON, sitemap
    ├── index_views.cr   #   Priority 60-69: entity indexes
    ├── static_views.cr  #   Priority 90-99: about, JS pages
    └── debug_views.cr   #   Priority 100+: diagnostic pages
```

### View Classes

```
data/src/views/
├── base_view.cr         # BaseView - all views inherit from this (includes AssetAware)
├── concerns/
│   └── asset_aware.cr   # Asset bundle declaration module
├── page_view.cr         # PageView - HTML page wrapper
├── area_show_view.cr    # Area detail page (uses template)
├── post_list_view/      # Entity collection pages (towns, tags, etc.)
├── dynamic_view/        # Data-heavy pages (stats, reports)
├── debug_view/          # Debug/diagnostic pages (DebugView namespace)
├── static_view/         # JS-heavy pages (map, timeline)
├── gallery_view/        # Photo galleries
├── special_view/        # RSS, Atom, JSON generators
├── photo_map/           # SVG map views
└── model_view/          # Index pages
```

### Services

```
data/src/services/
├── router.cr                 # Centralized URL generation with alias support
├── asset_bundle_loader.cr    # Load/resolve asset bundles from YAML config
├── html_processor.cr         # HTML comment removal, validation
├── html_validators/          # HTML validation rules
│   ├── all.cr
│   ├── base.cr
│   ├── title_validators.cr
│   ├── duplicate_id_validator.cr
│   ├── placeholder_validator.cr
│   ├── accessibility_validators.cr
│   └── link_validators.cr
├── area_data_loader.cr       # Load area entities from config
├── area_photo_selector.cr    # Select photos for areas
├── nav_stats_cache.cr        # Navigation statistics
├── output_history.cr         # Track file changes
└── ...
```

### Layout Templates

```
data/layout/
├── area/
│   └── show.html        # Area show page template (React/Leaflet, uses placeholders)
├── page.html            # Standard page wrapper
└── ...
```

### Test Support

```
spec/
├── spec_helper.cr
├── support/
│   ├── all.cr
│   ├── mock_render_context.cr
│   ├── mock_post.cr
│   └── mock_html_buffer.cr
└── views/               # View tests
```

### Commands (Standalone Scripts)

```
commands/
├── generate_areas_for_posts.cr   # Match routes to areas, generate cache
├── generate_polygon_json.cr      # Generate GeoJSON for frontend (NEW)
├── fetch_map_tiles.cr            # Download map tiles for offline use
└── ...
```

### External Data & Polygons

```
data/external/                    # Source polygon data (large YAML files)
├── towns.yaml                    # 2,477 towns with full polygons (~4MB)
├── counties.yaml
├── voivodeships.yaml
├── meso_regions.yaml             # Geographic regions (~44MB)
└── ...

data/config/areas/                # Generated area configs (bbox only)
├── towns.yml                     # Metadata + bbox, no polygons
├── counties.yml
└── ...

env/<env>/public/<target>/polygons/  # Generated GeoJSON for frontend
├── towns/
│   └── <slug>.json               # Individual polygon files (~1-4KB each)
├── counties/
└── ...
```

## Priority System

Defined in `ViewRegistry::PRIORITY_GROUPS` (base.cr):

| Range | Type | Name | Description |
|-------|------|------|-------------|
| 1-2 | task | Setup | Dev render, copy assets |
| 3-4 | task | EXIF | Initialize EXIF data |
| 5-9 | task | Cache | Refresh caches |
| 10-19 | view | Entity | Towns, tags, voivodeships, lands |
| 20-29 | view | Home | Home, map, POIs |
| 30-39 | view | Photo | Galleries, photo maps |
| 40-49 | view | Stats | Summary, year reports |
| 50-59 | view | Feed | RSS, Atom, JSON, sitemap |
| 60-69 | view | Index | Entity indexes |
| 90-99 | view | Static | About, JS pages |
| 100+ | view | Debug | Diagnostic pages |

## Dependency Types

- `:posts` - Post content changed (markdown files)
- `:yamls` - YAML config changed (entities, settings)
- `:exifs` - EXIF data changed (photo metadata)
- Empty `[]` - Always runs

## Image Sizes

Defined in `data/src/image_resizer.cr`:

| Name | Dimensions | Quality | Used for |
|------|------------|---------|----------|
| `article` | 1000×800 | 85% | Article inline photos, lightbox |
| `card` | 700×525 | 82% | Homepage cards, prev/next pager |
| `grid` | 560×420 | 80% | Gallery grids, related posts |
| `thumbnail` | 150×112 | 72% | Small thumbnails |

## Router Service

Centralized URL generation with alias support (`data/src/services/router.cr`).

### Usage

```crystal
# Access via RenderContext
router = context.router

# Direct URL generation
router.area_show_url(area)       # /gmina/pobiedziska.html
router.area_post_list_url(area)  # /wpisy-dla/gminy/pobiedziska.html
router.area_gallery_url(area)    # /galeria/gminy/pobiedziska.html

# Semantic/aliased URLs (controlled by Router constants)
router.area_link_url(area)       # Returns show_url by default
router.tag_link_url(tag)         # Returns show_url by default
```

### Alias Configuration

Change `Router::AREA_LINK_TARGET` to control where `area_link_url` points:

```crystal
# In router.cr
AREA_LINK_TARGET = AreaLinkTarget::Show      # Default: /gmina/slug.html
AREA_LINK_TARGET = AreaLinkTarget::PostList  # /wpisy-dla/gminy/slug.html
AREA_LINK_TARGET = AreaLinkTarget::Gallery   # /galeria/gminy/slug.html
```

### JSON Serializers

Use semantic URLs in JSON so page destination can be changed via Router:

```crystal
# Good - semantic name, Router controls destination
json.field("url", router.area_link_url(area))

# Also include explicit URLs when needed
json.field("show_url", router.area_show_url(area))
json.field("post_list_url", router.area_post_list_url(area))
```

## View Style Guidelines

- Views receive `context : RenderContext` in constructor, not `@blog`
- Store data in instance variables, use `getter` for access
- Don't define methods that call context repeatedly - fetch once in constructor

```crystal
# Good
def initialize(context : RenderContext, @url : String)
  super(context: context, url: @url)
  meta = context.page_meta("summary")
  @title = meta[:title].as(String)
  @image_url = meta[:backgrounds].as(String)
end

getter :title, :image_url

# Bad - calls context on every access
def title
  context["summary.title"]
end
```

## Asset Bundle System

Views declare which asset bundles they need via the `AssetAware` module (included in `BaseView`).

### Bundle Configuration

Bundles are defined in `data/config/asset_bundles.yml`:
- **Granular bundles**: `bootstrap-css`, `leaflet-js`, `react`, etc.
- **Composites**: `core` (includes Bootstrap, jQuery, nav), `leaflet`, `openlayers`

### Declaring Bundles in Views

```crystal
class MyView < PageView
  # Add bundles to parent's list
  def additional_bundles : Array(String)
    ["leaflet", "react-runtime"]
  end

  # Optional: page-specific JS file
  def page_js : String?
    "/js/self/my_page.js"
  end
end
```

### Available Methods (from AssetAware)

- `asset_bundles` - Base bundles (default: `["core"]`)
- `additional_bundles` - Append to parent's bundles
- `excluded_bundles` - Remove from inherited list
- `page_js` - Optional page-specific JS file
- `resolved_bundles` - Final computed bundle list

### Current Bundle Declarations

| View | Bundles |
|------|---------|
| `BaseView` | `["core"]` |
| `AreaShowView` | `["core", "leaflet", "react-runtime"]` |
| `RouteMapView` | `["core", "leaflet"]` |
| `JsIdeasView` | `["core", "ideas-css", "leaflet", "react-runtime"]` |
| `GalleryView::AbstractView` | `["core", "gallery"]` |

## URL Patterns

Area pages use Polish grammatical cases for URLs:

| Page Type | Pattern | Example |
|-----------|---------|---------|
| Area show | `/<type>/<slug>.html` | `/gmina/pobiedziska.html` |
| Area post list | `/wpisy-dla/<type>/<slug>.html` | `/wpisy-dla/gminy/pobiedziska.html` |
| Area gallery | `/galeria/<type>/<slug>.html` | `/galeria/gminy/pobiedziska.html` |
| Tag post list | `/wpisy-dla/tagu/<slug_pl>.html` | `/wpisy-dla/tagu/najlepsze.html` |
| Tag gallery | `/galeria/tagu/<slug_pl>.html` | `/galeria/tagu/najlepsze.html` |
| Tag redirect | `/tag/<slug_pl>.html` → redirect | `/tag/najlepsze.html` → 302 to post list |
| Post | `/<year>/<month>/<day>-<slug>.html` | `/2021/07/18-pagorki.html` |
| Post gallery | `/galeria/<year>/<month>/<day>-<slug>.html` | `/galeria/2021/07/18-pagorki.html` |

Area types use nominative (show) vs genitive (post-list/gallery) forms:
- `gmina` / `gminy` (town)
- `powiat` / `powiatu` (county)
- `wojewodztwo` / `wojewodztwa` (voivodeship)
- `mezoregion` / `regionu` (meso region)
- `makroregion` / `obszaru` (macro region)

**Slug Convention (Tags):**
- Tags have two slugs: `slug` (English) and `slug_pl` (Polish)
- English `slug` is used for internal matching/lookups (e.g., `bicycle`, `hike`)
- Polish `slug_pl` is used in all public URLs (e.g., `rowerem`, `pieszo`)
- English slugs are **never** displayed in public HTML URLs
- Example: Tag with `slug=bicycle`, `slug_pl=rowerem` → URL `/wpisy-dla/tagu/rowerem.html`
- Legacy URLs (`/tag/*.html`) redirect via `TemporaryRedirectView` (302)

## Common Tasks

### Adding a New View

1. Choose appropriate priority range from PRIORITY_GROUPS
2. Add registration in correct `views/*.cr` file:
   ```crystal
   r.register("Category: name", [:deps], priority: N) do |ctx|
     ctx.write_output(MyView.new(context: ctx, ...))
   end
   ```
3. Create view class in `data/src/views/`
4. Add test in `spec/views/`
5. Regenerate VIEWS.md (see below)

### Adding a New Task

1. Choose priority 1-9 based on when it should run
2. Add registration in correct `tasks/*.cr` file:
   ```crystal
   r.task("Category: name", [:deps], priority: N) do |ctx|
     # task implementation
   end
   ```
3. Regenerate VIEWS.md

### Regenerating VIEWS.md

1. Extract entries: `grep -h "r\.task\|r\.register" data/src/view_registry/**/*.cr`
2. Count by type and dependency
3. Generate sections: Summary, What runs when, Entries by Category, Dependency Matrix, Priority Guide
4. Verify structure matches PRIORITY_GROUPS in base.cr

### Building the Project

```bash
make dev-render-local           # Compile and run project (dev environment)
```

### Running Tests

```bash
crystal spec                    # Run all tests
crystal spec spec/views/        # Run view tests only
```

### Running E2E Tests (Playwright)

E2E tests are in `tests/e2e/` directory.

**First-time setup:**
```bash
cd tests/e2e
npm install                     # Install Playwright
npx playwright install chromium # Download Chromium browser
```

**Running tests:**
```bash
cd tests/e2e
npx playwright test             # Run all tests
npx playwright test --ui        # Interactive UI mode
npx playwright test specs/map.spec.js  # Run specific file
npx playwright test --headed    # See browser while testing
```

**Prerequisites:**
- Dev server must be running on `localhost:5001`
- Run `make dev-render-local` first to build the site

### Running Commands

Commands are standalone Crystal scripts in `commands/` directory:

```bash
# Generate area associations for posts (run when posts or external data changes)
crystal run commands/generate_areas_for_posts.cr
crystal run commands/generate_areas_for_posts.cr --overwrite  # Force regenerate all

# Generate polygon JSON files for frontend (run when external data changes)
crystal run commands/generate_polygon_json.cr
crystal run commands/generate_polygon_json.cr --tolerance=0.001  # Custom simplification
```

### Command Registry (Planned)

See `PLAN.md` Phase 9 for the upcoming unified command system with:
- Periodic tasks (time-based triggers)
- FileChanged tasks (source file triggers)
- Task run tracking in `cache/command_runs.yml`

## Validation Checklist

When making changes, verify:

- [ ] All tests pass (`crystal spec`)
- [ ] Entry priorities match their file's designated range
- [ ] Entry names follow "Category: description" convention
- [ ] New views have corresponding tests
- [ ] VIEWS.md reflects current registry state
- [ ] No duplicate entry names in registry

## Structure Verification Commands

```bash
# List all registered entries
grep -h "r\.task\|r\.register" data/src/view_registry/**/*.cr

# Count entries by file
grep -c "r\.task\|r\.register" data/src/view_registry/**/*.cr

# Check priority distribution
grep -oh "priority: [0-9]*" data/src/view_registry/**/*.cr | sort -t: -k2 -n | uniq -c

# Verify PRIORITY_GROUPS
grep -A 15 "PRIORITY_GROUPS = \[" data/src/view_registry/base.cr

# Check for entry name duplicates
grep -oh '"[^"]*"' data/src/view_registry/**/*.cr | grep -E "^\"[A-Z]" | sort | uniq -d
```

## Self-Maintenance

### When to Update This File

- New directory added to project structure
- New documentation file added
- Priority ranges changed
- New dependency type added
- New common task pattern established

### Changelog

- 2026-02-02: Initial creation with view registry structure
- 2026-02-02: PostRenderer extracted from blog.cr
- 2026-02-03: View decoupling complete - all 55+ views use context: RenderContext
- 2026-02-03: Output History Comparator added (data/src/services/output_history.cr)
- 2026-02-03: DebugView namespace created (moved from DynamicView)
- 2026-02-03: Map::Base migrated to take posts parameter instead of blog
- 2026-02-03: AreaEntity system complete - unified 5 area types (Town, County, Voivodeship, MesoRegion, MacroRegion)
- 2026-02-03: Legacy entity views deleted (TownDynamicView, VoivodeshipDynamicView, LandDynamicView, LandView)
- 2026-02-03: TownEntity, VoivodeshipEntity, LandEntity marked DEPRECATED (see PLAN.md for dependencies)
- 2026-02-03: Command Registry and Polygon Support planned (Phase 9-10 in PLAN.md)
- 2026-02-03: Added commands documentation section
- 2026-02-04: Polygon support complete - generate_polygon_json.cr with Douglas-Peucker simplification
- 2026-02-04: Area show page template created (data/layout/area/show.html) with React/Leaflet frontend
- 2026-02-04: AreaShowView converted to use load_html() template system
- 2026-02-04: AreaType extended with payload_field and polygon_dir methods
- 2026-02-04: Map hero with gray mask outside polygon area
- 2026-02-04: Phase 6 cleanup complete - deprecated code commented with PHASE6_DEPRECATED markers
- 2026-02-04: Deleted unused MountainRangePlannerView
- 2026-02-04: Fixed CoordRange#overlap_other logic bug
- 2026-02-04: OutputHistory improved - env/target separation, pages/ subdirectory
- 2026-02-04: Replaced deprecated Time.monotonic with Time.instant
- 2026-02-04: Asset Bundle System added (Phase 11) - AssetBundleLoader, AssetAware module
- 2026-02-04: HTML Processor and validators added (Phase 13) - comment removal, validation
- 2026-02-04: External nav_stats.js extracted from inline script
- 2026-02-04: Split head_open.html into head_meta, head_icons, head_feeds
- 2026-02-04: Bootstrap 5 migration - jQuery removed (-88K)
- 2026-02-04: map.js rewritten to vanilla JS (no jQuery)
- 2026-02-04: AreaType refactored with Polish inflections (nominative/genitive cases)
- 2026-02-04: ASCII-safe URL slugs added (wojewodztwo not województwo)
- 2026-02-04: AreaEntity aliases added (view_url, post_areas_link_url)
- 2026-02-04: Navigation thumbnails - prev/next pager and related posts grid
- 2026-02-04: Fixed page_css/page_js cache key bug in head_open_html
- 2026-02-04: Registered JsBicyclePlannerView at /pomysly2.html
- 2026-02-04: Replaced OpenLayers with Leaflet on map page (-590K)
- 2026-02-04: Added Playwright e2e test infrastructure
- 2026-02-05: New homepage implemented (NewHomePageView at `/index.html`)
- 2026-02-05: HomePageJsonGenerator - optimized JSON for homepage (6KB vs 836KB payload.json)
- 2026-02-05: Homepage JS with fuzzy logic selection (hero, posts grid, category chips)
- 2026-02-05: Top 4 photos per post (by points) included in homepage JSON for hero selection
- 2026-02-05: Tag URLs changed from `/tag/` to `/wpisy-dla/tagu/` (genitive case)
- 2026-02-05: TemporaryRedirectView added for 302 redirects (JS-based)
- 2026-02-05: Legacy tag redirects: `/tag/*.html` → `/wpisy-dla/tagu/*.html`
- 2026-02-05: Homepage navigation URLs now generated by Router (not hardcoded)
- 2026-02-05: E2E tests for homepage links (specs/homepage.spec.js)
- 2026-02-05: Voivodeship names lowercase in generated config
- 2026-02-05: Fixed homepage stats - use English tag slugs (bicycle/hike not rowerem/pieszo)
- 2026-02-05: Homepage stats units moved next to values (69km, 15km, 26h)
- 2026-02-05: E2E test added to verify stats are not zero
- 2026-02-04: Preact migration - React replaced with Preact (-114K, 82% smaller)
- 2026-02-04: summary.js rewritten to vanilla JS (jQuery removed)
- 2026-02-04: E2E tests fixed - 36 passing (Polish slugs, area filtering)
- 2026-02-05: Related posts use grid images (560x420) instead of thumbnail (150x112)
- 2026-02-05: URL format: /wpisy_dla/ → /wpisy-dla/ (hyphen instead of underscore)
- 2026-02-05: Phase 19 planned - new index page with dynamic content
- 2026-02-05: Router service added - centralized URL generation with alias support
- 2026-02-05: PayloadJsonGenerator updated to use Router with semantic URLs
- 2026-02-05: NewHomePageView created with fuzzy logic content selection
- 2026-02-05: HomePageJsonGenerator added at /jsons/homepage.json (6KB vs 836KB payload.json)
- 2026-02-05: Router DRY fix - tag methods delegate to slug-based overloads
- 2026-02-05: Tag URLs now use slug_pl (Polish) - English slug for matching only
- 2026-02-06: Map page renamed: /mapa.html → /mapa_tras.html (MapView → RouteMapView)
- 2026-02-06: Photo map renamed: /mapa2.html → /mapa_zdjec.html (JsPanoramioView → PhotoMapView)
- 2026-02-06: More page (/wiecej.html) - added links to timeline and route map

---

*Current stats: 5 tasks + 35 views = 40 registry entries, 275 tests, 82 e2e tests*
