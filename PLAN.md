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

### Phase 6: Legacy Migration (PARTIAL)
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

---

## Deprecated Classes

The following classes are **DEPRECATED** and should be migrated to `AreaEntity`:

| Class | File | Status |
|-------|------|--------|
| `TownEntity` | `data/src/models/town_entity.cr` | DEPRECATED |
| `VoivodeshipEntity` | `data/src/models/voivodeship_entity.cr` | DEPRECATED |
| `LandEntity` | `data/src/models/land_entity.cr` | DEPRECATED |

### Dependencies on Deprecated Classes

Files that still use deprecated entity classes and need migration:

| File | Uses | Migration Notes |
|------|------|-----------------|
| `data/src/data_manager.cr` | All 3 | Still loads legacy entities for backward compat. Keep until all dependents migrated. |
| `data/src/validator.cr` | TownEntity | `validate_town` method. Update to validate AreaEntity or remove. |
| `data/src/services/town_photo_cache.cr` | TownEntity | Replace with `AreaPhotoSelector` or update to use AreaEntity. |
| `data/src/post/accessors.cr` | All 3 | `was_in?` method. Keep TagEntity support, remove others. |
| `data/src/models/coord_range.cr` | VoivodeshipEntity | Initializer. Update to use AreaEntity.bbox or remove. |
| `data/src/services/map/link_generator.cr` | VoivodeshipEntity | `url_photomap_for_voivodeship_*` methods. Update to AreaEntity. |
| `data/src/models/idea_entity.cr` | TownEntity | `towns_already_visited`, `towns_not_visited`. Update to use AreaEntity. |

### Internal Dependencies (within deprecated classes)

| File | Depends On |
|------|------------|
| `town_entity.cr` | `LandEntity` (internal use) |
| `voivodeship_entity.cr` | Uses `TownEntityHash` alias |

---

## Remaining Work

### Phase 6: Complete Legacy Migration

1. **TownPhotoCache** - decide: remove entirely (use AreaPhotoSelector) or migrate to AreaEntity
2. **Validator** - update `validate_town` to work with AreaEntity or remove
3. **CoordRange** - update VoivodeshipEntity initializer to use AreaEntity.bbox
4. **Map::LinkGenerator** - update voivodeship methods to use AreaEntity
5. **IdeaEntity** - update town visitor methods to use AreaEntity
6. **Post accessors** - update `was_in?` to drop deprecated types (keep TagEntity)
7. **DataManager** - remove legacy entity loading after all dependents migrated

### Phase 7: External Towns (Future)
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

---

## Migration Priority

**High Priority** (blocking other work):
1. `validator.cr` - currently validates TownEntity objects
2. `post/accessors.cr` - `was_in?` method used by some views

**Medium Priority** (can work around):
3. `town_photo_cache.cr` - can be replaced by AreaPhotoSelector
4. `coord_range.cr` - used by photo maps
5. `map/link_generator.cr` - used by photo maps

**Low Priority** (isolated):
6. `idea_entity.cr` - only used by ideas view
7. `data_manager.cr` - final cleanup after all others done

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

*Last updated: 2026-02-03 - Phase 5 complete, Phase 6 partial*
