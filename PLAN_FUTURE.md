# Renderer & Views Refactoring - Future Work

This document contains ideas and plans for future phases (beyond current work).

---

## Phase 5: View Decoupling

**Goal**: Remove `blog` dependency from view classes, improve testability

### Problem

Currently views receive the entire `blog` object:
```crystal
PoisView.new(blog: ctx.blog, url: "/pois.html")
```

This has issues:
- Views have access to everything (poor encapsulation)
- Hard to test without full Blog instance
- URL is passed at call site, not defined in view

### Solution

1. **Default URLs in view classes** - Each view defines its own URL
2. **Views receive RenderContext** - Or only the specific data they need
3. **No `blog` parameter** - Views don't know about Blog class

### Target Pattern

```crystal
# Before (current):
PoisView.new(blog: ctx.blog, url: "/pois.html")
PostListView::TownDynamicView.new(blog: ctx.blog, town: town)

# After (target):
PoisView.new(context: ctx)  # URL defined in class
TownDynamicView.new(context: ctx, town: town)
```

### View Class Changes

```crystal
# Before:
class PoisView < BaseView
  def initialize(@blog : Blog, @url : String)
  end
end

# After:
class PoisView < BaseView
  URL = "/pois.html"

  def initialize(@context : RenderContext)
    @url = URL
  end

  # Access data via context
  def posts
    context.posts
  end
end
```

### Migration Steps

1. [ ] Add `context` property to BaseView
2. [ ] For each view class:
   - [ ] Define `URL` constant (or method for dynamic URLs)
   - [ ] Change constructor to receive `context` instead of `blog`
   - [ ] Update internal `blog.xxx` calls to `context.xxx`
3. [ ] Update registry blocks to use new pattern
4. [ ] Remove `blog` parameter from view constructors

### Benefits

- **Better encapsulation** - Views only see what they need
- **Easier testing** - MockRenderContext works directly
- **Self-documenting** - URL defined where view is defined
- **Consistent** - All views follow same pattern

### Priority Order

Start with simple views (single URL, few dependencies):
1. StaticView classes (MoreView, MapView, etc.)
2. PoisView
3. DynamicView classes
4. PostListView classes (have entity parameter)
5. GalleryView classes (complex, many sub-views)

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

Directories needing `all.cr`:
- [ ] `views/dynamic_view/`
- [x] `views/static_view/` (already has it)
- [x] `views/post_list_view/` (already has it)
- [ ] `views/gallery_view/`
- [x] `views/special_view/` (already has it)
- [ ] `views/photo_map/`
- [x] `views/model_view/` (already has it)

### Debug Views Reorganization

Debug views could be moved to a separate namespace:
- [ ] Create `DebugView` namespace (currently in `DynamicView::Debug*`)
- [ ] Move to `/debug/` URL prefix (already done for some)
- [ ] Consider priority: sometimes useful to render first for quick debugging
- [ ] Views to migrate:
  - `DynamicView::DebugPostView` → `DebugView::PostsView`
  - `DynamicView::DebugPostCameraStuffView` → `DebugView::CameraStuffView`
  - `DynamicView::DebugPostMissingPhotosExifView` → `DebugView::MissingExifView`

---

## Testing Improvements

Future testing enhancements:
- [ ] Snapshot testing for HTML output
- [ ] Integration tests for full coordinator
- [ ] More tests for photo, feed, debug views
