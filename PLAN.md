# Area Entity Refactoring Plan

## Status: IN PROGRESS (Phase 5 Complete)

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

### Phase 6: Legacy Migration (MOSTLY COMPLETE)
- [x] Deleted legacy view files:
  - `data/src/views/post_list_view/town_dynamic_view.cr`
  - `data/src/views/post_list_view/voivodeship_dynamic_view.cr`
  - `data/src/views/post_list_view/land_dynamic_view.cr`
  - `data/src/views/land_view.cr`
- [x] Updated `entity_views.cr` - now only registers tags (areas handled by `area_views.cr`)
- [x] Updated `TownsTimelineView` to use AreaEntity
- [x] Updated `TownsHistoryView` to use AreaEntity
- [x] Updated `TownsIndexView` to use AreaEntity
- [x] Removed legacy requires from `renderer.cr` and `post_list_view/all.cr`
- [x] Updated `validator.cr` - removed TownEntity validation (areas use auto-selected photos)
- [x] Updated `post/accessors.cr` - `was_in?` now only accepts TagEntity
- [x] Updated `coord_range.cr` - added AreaEntity initializer
- [x] Updated `map/link_generator.cr` - added `url_photomap_for_area_big/small` methods
- [x] Updated `idea_entity.cr` - methods now accept AreaEntity or String arrays
- [x] Updated `nav_stats_cache.cr` - uses AreaEntity for voivodeships and meso_regions
- [x] Updated `photo_views.cr` - voivodeship maps use AreaEntity
- [x] Updated `ideas_json_generator.cr` - uses AreaEntity with AreaPhotoSelector
- [x] Updated `data_manager.cr` - added `visited_town_slugs/areas_selfpropelled` methods
- [x] Updated `render_context.cr` - exposed new visited towns methods

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
| `data/src/data_manager.cr` | All 3 | Loads legacy entities. Keep for now, remove when safe. |
| `data/src/services/town_photo_cache.cr` | TownEntity | Can be removed (AreaPhotoSelector replaces it). |
| `data/src/validator.cr` | - | ✅ Migrated (TownEntity validation removed) |
| `data/src/post/accessors.cr` | TagEntity only | ✅ Migrated (deprecated types removed) |
| `data/src/models/coord_range.cr` | VoivodeshipEntity | ✅ Has AreaEntity initializer, legacy kept for compat |
| `data/src/services/map/link_generator.cr` | VoivodeshipEntity | ✅ Has AreaEntity methods, legacy kept for compat |
| `data/src/models/idea_entity.cr` | - | ✅ Migrated to AreaEntity |

### Internal Dependencies (within deprecated classes)

| File | Depends On |
|------|------------|
| `town_entity.cr` | `LandEntity` (internal use) |
| `voivodeship_entity.cr` | Uses `TownEntityHash` alias |

---

## Remaining Work

### Phase 6: Final Cleanup (Optional)

1. **TownPhotoCache** - remove entirely (AreaPhotoSelector is the replacement)
2. **DataManager** - remove legacy entity loading (towns, voivodeships, lands)
3. **CoordRange** - remove deprecated VoivodeshipEntity initializer
4. **Map::LinkGenerator** - remove deprecated voivodeship methods
5. **Delete deprecated entity files** after confirming nothing breaks

### Phase 7: External Towns (Future)
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

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
- `town_photo_cache.cr` - can be deleted (replaced by AreaPhotoSelector)
- `data_manager.cr` - can remove legacy entity loading
- Deprecated entity files - can be deleted after testing

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
| `data/src/models/area_type.cr` | AreaType enum |
| `data/src/models/area_entity.cr` | Unified AreaEntity struct |
| `data/src/models/area_association.cr` | Route distance data |
| `data/src/services/area_data_loader.cr` | Load areas_for_post YAML |
| `data/src/services/area_photo_selector.cr` | Best photo for area |
| `data/src/views/area_show_view.cr` | Area detail page |
| `data/src/views/post_list_view/area_post_list_view.cr` | Area post list |
| `data/src/views/gallery_view/area_gallery_view.cr` | Area photo gallery |
| `data/src/view_registry/views/area_views.cr` | Registry entries |
| `data/src/post/areas.cr` | Post area extensions |

## Files Deleted (This Refactoring)

| File | Reason |
|------|--------|
| `data/src/views/post_list_view/town_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/post_list_view/voivodeship_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/post_list_view/land_dynamic_view.cr` | Replaced by AreaPostListView |
| `data/src/views/land_view.cr` | Not used, replaced by AreaShowView |

## Files to Delete (After Full Migration)

| File | Blocker |
|------|---------|
| `data/src/models/town_entity.cr` | data_manager, validator, town_photo_cache, idea_entity |
| `data/src/models/voivodeship_entity.cr` | data_manager, coord_range, map/link_generator |
| `data/src/models/land_entity.cr` | data_manager, town_entity |

---

*Last updated: 2026-02-03 - Phase 6 mostly complete, only cleanup tasks remain*
