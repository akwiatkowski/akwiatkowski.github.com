# Renderer & Views Refactoring - Future Work

This document contains ideas and plans for future phases (beyond current work).

---

## Phase 5: View Decoupling - COMPLETE

**Status**: All views migrated to `context: RenderContext`. See PLAN.md for details.

- [x] 55+ views migrated
- [x] Photo Map Views (10 files) - migrated, `Map::Base` now takes `posts` parameter
- [x] `IdeaEntity#routes` updated to take `data_path` instead of `blog`

**External dependency (unchanged):**
- `SiteMapGenerator` in Tremolite library still uses `blog`

---

## Phase 6: Nice to Have

### Image Size Optimization

1. [ ] Check defined image size (downscaled photos). Some may not be needed, some should be changed
2. [ ] Analyze where sizes are used (check json serializers)
3. [ ] Write documentation about sizes we use
4. [ ] Tweak sizes to suit current width of post (images could be bigger on laptop)
5. [ ] Consider stronger jpeg compression

---

## Phase 7: New Features

### Town/Voivodeship Show Pages

Frontend page render as standalone html in `env/<env>/public/<target>/test.html`.

1. [ ] Create "show" page for towns and voivodeships with:
   - Leaflet JS map with polygon area rendered (frozen, no zoom/move)
   - Gradient transparency to middle of page
   - Best photos on map (like Panoramio)
   - Important stats (distance on foot, bicycle, etc.)

---

## Code Organization Ideas

### `all.cr` Convention

Every directory with multiple `.cr` files should have an `all.cr` that requires all files:

```crystal
# data/src/views/dynamic_view/all.cr
require "./summary_view"
require "./year_stat_report_view"
require "./burnout_stat_view"
# ... etc
```

Benefits:
- Single require for entire namespace: `require "./dynamic_view/all"`
- No need to track individual file names at call sites
- Adding new view only requires updating `all.cr`

Directories with `all.cr`:
- [x] `views/dynamic_view/`
- [x] `views/static_view/`
- [x] `views/post_list_view/`
- [x] `views/gallery_view/`
- [x] `views/special_view/`
- [x] `views/photo_map/`
- [x] `views/model_view/`

**Status:** All view directories have `all.cr` - COMPLETE

### Debug Views Reorganization ✓ COMPLETE

Debug views moved to separate `DebugView` namespace:
- [x] Created `DebugView` namespace in `views/debug_view/`
- [x] URLs unchanged (`/debug/*`)
- [x] Priority unchanged (100+, runs last)
- [x] Views migrated:
  - `DynamicView::DebugPostView` → `DebugView::PostsView`
  - `DynamicView::DebugPostCameraStuffView` → `DebugView::CameraStuffView`
  - `DynamicView::DebugPostMissingPhotosExifView` → `DebugView::MissingExifView`
  - `DynamicView::DebugTagStatsView` → `DebugView::TagStatsView`

---

## BuildContext: Separate Pipeline from Rendering

`RenderContext` currently serves two roles:
1. **View rendering** — read-only data access (posts, entities, router, asset bundles)
2. **Pipeline operations** — mutating services (exif_db, photo_analysis_cache, image_resizer)

PostRenderer uses RenderContext for both: pipeline services to process data, then passes the same context to views for rendering. This conflates two different interfaces.

**Proposed split:**
- **RenderContext** — stays read-only, used by views. Remove pipeline service proxies (exif_db, photo_analysis_cache) that views don't need.
- **BuildContext** (new) — holds pipeline/mutating services: exif_db, photo_analysis_cache, image_resizer. Passed to PostRenderer. Contains a reference to RenderContext for the view-rendering step.

**Benefits:**
- Clear separation: views can't accidentally call `save_cache()` or `process_photos()`
- PostRenderer dependencies become explicit through BuildContext
- Adding new pipeline services doesn't pollute the view interface
- Easier to reason about what views can and cannot do

**When to do:** When the pipeline grows beyond 2-3 services, or during next major refactor.

---

## Testing Improvements

Future testing enhancements:
- [ ] Snapshot testing for HTML output
- [ ] Integration tests for full coordinator
- [ ] More tests for photo, feed, debug views
