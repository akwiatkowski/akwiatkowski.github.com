# Area Entity Refactoring Plan

## Status: IN PROGRESS (Phase 7 & 10 Complete)

**Goal**: Unified area entity system with 5 area types, calculated route data, photo selection, and Polish URL paths.

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases archive
- `PLAN_FUTURE.md` - Future ideas

---

## Completed Work

### Phase 1-4: Core Infrastructure (DONE)
- [x] `AreaType` enum with 5 types (Town, County, Voivodeship, MesoRegion, MacroRegion)
- [x] `AreaEntity` struct with bbox, center, lat/lon, URL helpers
- [x] `AreaAssociation` for route distance data
- [x] `AreaDataLoader` service for loading area configs and post associations
- [x] `AreaPhotoSelector` for best photo selection within bbox

### Phase 5: Area Views (DONE)
- [x] `AreaShowView` - area detail page with stats
- [x] `AreaPostListView` - post list filtered by area
- [x] `AreaGalleryView` - photo gallery filtered by bbox
- [x] `area_views.cr` - registry entries for all area types (priorities 14-16)
- [x] Updated `payload_json_generator.cr` to use AreaEntity system
- [x] Updated `dynamic.html` JS filtering for all area types

### Phase 6: Legacy Migration (COMPLETE)
- [x] Deleted legacy view files:
  - `data/src/views/post_list_view/town_dynamic_view.cr`
  - `data/src/views/post_list_view/voivodeship_dynamic_view.cr`
  - `data/src/views/post_list_view/land_dynamic_view.cr`
  - `data/src/views/land_view.cr`
  - `data/src/services/town_photo_cache.cr` (replaced by AreaPhotoSelector)
- [x] Updated `entity_views.cr` - now only registers tags (areas handled by `area_views.cr`)
- [x] Updated `TownsTimelineView` to use AreaEntity
- [x] Updated `TownsHistoryView` to use AreaEntity
- [x] Updated `TownsIndexView` to use AreaEntity
- [x] Removed legacy requires from `renderer.cr` and `post_list_view/all.cr`
- [x] Updated `validator.cr` - removed TownEntity validation (areas use auto-selected photos)
- [x] Updated `post/accessors.cr` - `was_in?` now only accepts TagEntity
- [x] Updated `coord_range.cr` - added AreaEntity initializer, commented out VoivodeshipEntity initializer
- [x] Updated `map/link_generator.cr` - added AreaEntity methods, commented out VoivodeshipEntity methods
- [x] Updated `idea_entity.cr` - methods now accept AreaEntity or String arrays
- [x] Updated `nav_stats_cache.cr` - uses AreaEntity for voivodeships and meso_regions
- [x] Updated `photo_views.cr` - voivodeship maps use AreaEntity
- [x] Updated `ideas_json_generator.cr` - uses AreaEntity with AreaPhotoSelector
- [x] Updated `data_manager.cr` - added `visited_town_slugs/areas_selfpropelled` methods, commented out town_photo_cache
- [x] Updated `render_context.cr` - exposed new visited towns methods, commented out town_photo_cache method
- [x] Commented out deprecated sections with PHASE6_DEPRECATED markers:
  - `article_view.cr` - lands, towns, voivodeships taggable sections
  - `year_stat_report_view.cr` - voivodeships_stats method
  - `lands_index_view.cr` - registration commented out in index_views.cr
  - `cache_tasks.cr` - town photos cache task
- [x] Updated spec files with PHASE6_DEPRECATED markers:
  - `view_registry_spec.cr` - updated task/view counts and dependency queries
  - `post_list_view_spec.cr` - commented out deprecated view tests, added AreaPostListView test
  - `other_views_spec.cr` - commented out LandsIndexView and LandView tests
- [x] Added prominent PHASE6_DEPRECATED headers to deprecated entity files

---

## Deprecated Classes

The following classes are **DEPRECATED** and should be migrated to `AreaEntity`:

| Class | File | Status |
|-------|------|--------|
| `TownEntity` | `data/src/models/town_entity.cr` | DEPRECATED |
| `VoivodeshipEntity` | `data/src/models/voivodeship_entity.cr` | DEPRECATED |
| `LandEntity` | `data/src/models/land_entity.cr` | DEPRECATED |

### Dependencies on Deprecated Classes

Files that still use deprecated entity classes:

| File | Uses | Status |
|------|------|--------|
| `data/src/data_manager.cr` | All 3 | Loads legacy entities. Keep for now, provides context.towns/lands/voivodeships |
| `data/src/validator.cr` | - | ✅ Migrated (TownEntity validation removed) |
| `data/src/post/accessors.cr` | TagEntity only | ✅ Migrated (deprecated types removed) |
| `data/src/models/coord_range.cr` | - | ✅ VoivodeshipEntity initializer commented out |
| `data/src/services/map/link_generator.cr` | - | ✅ VoivodeshipEntity methods commented out |
| `data/src/models/idea_entity.cr` | - | ✅ Migrated to AreaEntity |
| `data/src/views/model_view/lands_index_view.cr` | LandEntity | Registration commented out, view marked deprecated |
| `data/src/views/post_view/article_view.cr` | - | ✅ Deprecated sections commented out |
| `data/src/views/dynamic_view/year_stat_report_view.cr` | - | ✅ voivodeships_stats commented out |

### Internal Dependencies (within deprecated classes)

| File | Depends On |
|------|------------|
| `town_entity.cr` | `LandEntity` (internal use) |
| `voivodeship_entity.cr` | Uses `TownEntityHash` alias |

---

## Remaining Work

### Phase 6: Final Cleanup (Complete - Deprecated Code Preserved)

All deprecated code has been commented out with PHASE6_DEPRECATED markers.
The following can be fully removed in a future cleanup phase:

1. ~~**TownPhotoCache**~~ - ✅ Removed (AreaPhotoSelector is the replacement)
2. **DataManager** - keep legacy entity loading (still provides context.towns/lands/voivodeships for display)
3. ~~**CoordRange**~~ - ✅ VoivodeshipEntity initializer commented out
4. ~~**Map::LinkGenerator**~~ - ✅ VoivodeshipEntity methods commented out
5. **Deprecated entity files** - kept with PHASE6_DEPRECATED headers, can be deleted when confirmed safe

### Phase 7: Area Show Page Design (DONE)

**Goal:** Create a visually appealing show page for AreaEntity with full-screen map hero.

**Implementation:**
- [x] Prototype: `env/dev/public/local/area_show.html`
- [x] Template: `data/layout/area/show.html`
- [x] View: `AreaShowView` uses `load_html("area/show", data)` with template placeholders
- [x] React/Leaflet frontend with real data loading from `payload.json` and `photos.json`

**Features Implemented:**
1. **Hero Section (Full-screen map)**
   - Leaflet map locked (no zoom/pan) - acts as background
   - Uses local tiles (`/tiles/ump/{z}/{x}/{y}.png`)
   - Routes drawn as colored polylines from post coords
   - Polygon outline with gray mask outside area
   - Large overlay with area name, type badge, parent link
   - Quick stats preview (km, trips, photos)

2. **Scroll Behavior**
   - Map fades to semi-transparent (15%) on scroll
   - Overlay fades out faster
   - Smooth gradient transition to content

3. **Stats Section**
   - Cards: distance (with bicycle/hike breakdown), time, trips (with first/last dates), photos
   - Navigation links to post list & gallery

4. **Photos Section**
   - Masonry-style grid (12 photos)
   - Shuffled on page load for variety
   - Hover reveals title/date from post
   - Filters to published photos only

5. **Recent Posts**
   - Horizontal scrollable cards
   - Image, title, date, stats from payload.json

6. **Footer**
   - Related areas links (parent voivodeship)

**Template Placeholders:**
- `{{slug}}`, `{{name}}`, `{{area_type}}`, `{{area_type_label}}`, `{{area_field}}`
- `{{parent_name}}`, `{{parent_url}}`, `{{voivodeship_name}}`, `{{voivodeship_url}}`
- `{{bbox_south}}`, `{{bbox_north}}`, `{{bbox_west}}`, `{{bbox_east}}`

**Future Ideas:**
- Animated route drawing
- Photo markers on map
- Achievement badges
- Mini timeline of visits
- Area comparison

### Phase 8: External Towns (Future)
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry (Planned)

**Goal:** Unified system for periodic/scheduled tasks with tracking.

**Problem:** Commands in `commands/` are run manually with no tracking of when they last ran
or whether they need to run again.

**Task Types by Trigger:**

| Trigger | Example | Description |
|---------|---------|-------------|
| Manual | Initial setup, migrations | Explicit invocation only |
| Periodic | Refresh area photos | Time-based (every N days) |
| FileChanged | Regenerate polygons | When source files change |
| PostRender | Update search index | After successful render |

**Proposed Structure:**
```
data/src/command_registry/
├── base.cr              # Registry class, TaskDef struct
├── runner.cr            # Executes due tasks
└── tasks/
    ├── area_tasks.cr    # generate_areas, generate_polygons
    └── photo_tasks.cr   # refresh_area_photos
```

**Task Tracking Cache:**
```yaml
# cache/command_runs.yml
generate_polygons:
  last_run: 2026-02-01T10:00:00Z
  duration_ms: 4500
  result: success
  file_hashes:
    data/external/towns.yaml: "a1b2c3..."
```

**Runner Interface:**
```bash
crystal run commands/run_tasks.cr              # Run all due tasks
crystal run commands/run_tasks.cr --task=X     # Run specific task
crystal run commands/run_tasks.cr --dry-run    # Show what would run
```

**Initial Tasks:**
- `generate_area_configs` - FileChanged trigger (external/*.yaml)
- `generate_polygons` - FileChanged trigger, depends on area_configs
- `generate_areas_for_posts` - FileChanged trigger (posts changed)
- `refresh_area_photos` - Periodic (7 days)

### Phase 10: Polygon Support (DONE)

**Goal:** Generate and use polygon data for accurate area rendering on maps.

**Implementation:**
- [x] `commands/generate_polygon_json.cr` - Douglas-Peucker simplification, generates GeoJSON
- [x] Only generates for visited areas (from areas_for_post cache)
- [x] Configurable tolerance via `--tolerance=N` flag (default 0.005)
- [x] Frontend loads polygons on-demand with fallback to bbox rectangle
- [x] Gray mask overlay outside polygon area

**Data Flow:**
```
data/external/towns.yaml          # Source: full polygon coords
        ↓
commands/generate_polygon_json.cr # Transform (Douglas-Peucker simplification)
        ↓
env/<env>/public/<target>/polygons/<type>/<slug>.json  # Output: GeoJSON
```

**Output Structure:**
```
public/polygons/
├── towns/           # Only visited towns
├── counties/        # Only visited counties
├── voivodeships/    # Only visited voivodeships
├── meso_regions/    # Only visited meso regions
└── macro_regions/   # Only visited macro regions
```

**GeoJSON Format:**
```json
{
  "type": "Feature",
  "properties": {
    "slug": "gruta",
    "name": "Gruta",
    "type": "town",
    "original_points": 31,
    "simplified_points": 26,
    "reduction_percent": 16.1
  },
  "geometry": {
    "type": "Polygon",
    "coordinates": [[[18.845874, 53.400479], ...]]
  }
}
```

**Usage in Area Renderers:**
- [x] AreaShowView map hero - polygon outline with gray mask outside
- [x] Photo selection - keep bbox (simpler, good enough)
- [x] Route clipping - no clipping, show full routes
- [x] Neighboring areas - not needed, only selected area

**Command Usage:**
```bash
crystal run commands/generate_polygon_json.cr                    # Default tolerance 0.005
crystal run commands/generate_polygon_json.cr --tolerance=0.001  # More detail
crystal run commands/generate_polygon_json.cr --force            # Regenerate all
```

**Results with tolerance 0.005:**
- Total size: ~6.2MB
- Reduction: ~25% for larger polygons

---

## Migration Status

**Completed:**
- ✅ `validator.cr` - TownEntity validation removed
- ✅ `post/accessors.cr` - `was_in?` simplified to TagEntity only
- ✅ `coord_range.cr` - AreaEntity initializer added
- ✅ `map/link_generator.cr` - AreaEntity methods added
- ✅ `idea_entity.cr` - migrated to AreaEntity
- ✅ `nav_stats_cache.cr` - uses AreaEntity for voivodeships/lands
- ✅ `photo_views.cr` - voivodeship maps use AreaEntity
- ✅ `ideas_json_generator.cr` - uses AreaEntity + AreaPhotoSelector

**Optional cleanup (can be done later):**
- ~~`town_photo_cache.cr`~~ - ✅ Deleted (replaced by AreaPhotoSelector)
- `data_manager.cr` - keeps loading legacy entities for context.towns/lands/voivodeships
- Deprecated entity files - kept with PHASE6_DEPRECATED markers, can be deleted when confirmed safe

---

## Key Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| Entity approach | **Unified AreaEntity** | Single struct with `area_type` enum |
| Data source | **Supplement** | Manual YAML primary, calculated areas_for_post as additional |
| Filtering | **Configurable** | Default >1% of route distance |
| Photo selection | **Bbox intersection** | Fallback to closest photo if none in bbox |
| URL paths | **Polish** | `/gminy/`, `/powiaty/`, `/wojewodztwa/`, `/regiony/`, `/obszary/` |
| Backward compat | **Not needed** | Clean break, app works after finishing |

---

## Area Types (5)

| Type | Polish | URL Prefix | Example |
|------|--------|------------|---------|
| Town | gmina | `/gminy/` | `/gminy/pobiedziska.html` |
| County | powiat | `/powiaty/` | `/powiaty/poznanski.html` |
| Voivodeship | województwo | `/wojewodztwa/` | `/wojewodztwa/wielkopolskie.html` |
| MesoRegion | region | `/regiony/` | `/regiony/pojezierze-gnieznienskie.html` |
| MacroRegion | obszar | `/obszary/` | `/obszary/pojezierza-wielkopolskie.html` |

---

## Files Created (This Refactoring)

| File | Purpose |
|------|---------|
| `data/src/models/area_type.cr` | AreaType enum with `payload_field`, `polygon_dir` methods |
| `data/src/models/area_entity.cr` | Unified AreaEntity struct |
| `data/src/models/area_association.cr` | Route distance data |
| `data/src/services/area_data_loader.cr` | Load areas_for_post YAML |
| `data/src/services/area_photo_selector.cr` | Best photo for area |
| `data/src/views/area_show_view.cr` | Area detail page (uses template) |
| `data/src/views/post_list_view/area_post_list_view.cr` | Area post list |
| `data/src/views/gallery_view/area_gallery_view.cr` | Area photo gallery |
| `data/src/view_registry/views/area_views.cr` | Registry entries |
| `data/src/post/areas.cr` | Post area extensions |
| `data/layout/area/show.html` | Area show page template (React/Leaflet) |
| `commands/generate_polygon_json.cr` | Generate GeoJSON polygons with simplification |

## Files Deleted (This Refactoring)

| File | Reason |
|------|--------|
| `data/src/views/post_list_view/town_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/post_list_view/voivodeship_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/post_list_view/land_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/land_view.cr` | Not used, replaced by AreaShowView |
| `data/src/services/town_photo_cache.cr` | Replaced by AreaPhotoSelector |
| `data/src/views/dynamic_view/mountain_range_planner_view.cr` | Unused, never registered |

## Files to Delete (After Full Migration)

| File | Blocker |
|------|---------|
| `data/src/models/town_entity.cr` | data_manager, validator, town_photo_cache, idea_entity |
| `data/src/models/voivodeship_entity.cr` | data_manager, coord_range, map/link_generator |
| `data/src/models/land_entity.cr` | data_manager, town_entity |

---

*Last updated: 2026-02-04 - Phase 6 cleanup complete (deprecated code commented with PHASE6_DEPRECATED markers)*
