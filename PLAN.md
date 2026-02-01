# Renderer & Views Refactoring Plan

## Progress Summary

### Phase 1: Cleanup & Documentation ✅ COMPLETE

**Commit `9ddf621`** (2026-02-01):
- Deleted 14 deprecated view files (`*ListView`, `*MasonryView` variants)
- Removed dead code from renderer mixins
- Created `VIEWS.md` documenting all 50+ active views
- **-731 lines of dead code removed**

### Phase 1.5: Testing Infrastructure ✅ COMPLETE

**Commit `95d6ecf`** (2026-02-01):
- Created `RenderContext` class (Context Object pattern)
- Created `MockRenderContext`, `MockPost`, `MockHtmlBuffer` for testing
- Added **96 tests** covering all view categories
- Updated `BaseView` to use context via lazy property

### Phase 2: View Registry + Coordinator ✅ COMPLETE

**Decision**: Changed from Pipeline to Registry approach for better:
- Explicit dependency declarations per view
- Queryable "what runs when X changes?"
- Eventually remove mixins entirely

**Created files** (`data/src/view_registry/`):

Core infrastructure:
- `base.cr` ✅ - ViewRegistry class with `register()` and `task()` methods
- `coordinator.cr` ✅ - RenderCoordinator executes based on what changed
- `setup.cr` ✅ - Combines all registrations
- `all.cr` ✅ - Requires everything

Tasks (6 registered):
- `tasks/setup_tasks.cr` ✅ - dev render, copy assets (priority 1-2)
- `tasks/exif_tasks.cr` ✅ - EXIF initialization (priority 4)
- `tasks/cache_tasks.cr` ✅ - nav_stats, town_photo, coord_quant (priority 5-6)

Views (35 registered):
- `views/entity_views.cr` ✅ - towns, tags, voivodeships, lands (priority 10-13)
- `views/home_views.cr` ✅ - home, map, pois (priority 20-22)
- `views/photo_views.cr` ✅ - galleries, photo maps (priority 30-35)
- `views/stats_views.cr` ✅ - summary, year reports, burnout, towns history/timeline (priority 40-44)
- `views/feed_views.cr` ✅ - RSS, Atom, JSON, sitemap, robots (priority 50-58)
- `views/index_views.cr` ✅ - towns index, lands index (priority 60-61)
- `views/static_views.cr` ✅ - more, about, english, JS pages (priority 90-96)
- `views/debug_views.cr` ✅ - posts, camera stuff, missing EXIF (priority 100-102)

Tests:
- `spec/view_registry_spec.cr` ✅ - **49 tests** covering registry functionality

**Integration**:
- `blog.cr` ✅ - Added `view_registry`, `render_coordinator`, `render_with_registry` methods

**Deleted abandoned files**:
- ~~`data/src/render_pipeline.cr`~~ ✅ deleted
- ~~`data/src/render_stages/`~~ ✅ deleted

---

## Current State Analysis

### Architecture Overview

The project uses a **mixin-based renderer** pattern:

```
Blog (data/src/blog.cr)
  └─> Renderer (data/src/renderer.cr)
       ├─> includes 13 renderer mixins
       └─> each mixin has multiple render_* methods
            └─> each method instantiates View classes
```

### Problems with Current Approach

1. **Poor discoverability**: Mixins scatter 100+ methods across 13 files
   - Hard to find what methods are available
   - No clear naming convention for when methods run
   - Method names like `render_fast_only_post_related` are unclear

2. **Unclear execution flow**:
   - `blog.cr` calls high-level methods
   - Those methods internally call many sub-methods
   - Hard to trace: "when does TownDynamicView get rendered?"

3. **Mixed old/new patterns**:
   - Some entities have 3 versions: `*ListView`, `*MasonryView`, `*DynamicView`
   - Many commented with `# DEPRECATED` but still in codebase
   - `# DEPRECATED` code could be removed if it's not used or can be removed
   - Unclear which is actually used

4. **Tight coupling**:
   - Blog class knows about renderer implementation details
   - Renderer mixins directly access blog internals via `@blog`
   - Hard to test or change independently

5. **Conditional rendering logic spread everywhere**:
   - `posts_changed`, `yamls_changed`, `exifs_changed` flags
   - Logic in `blog.cr` determines what to render
   - No central place to understand the dependency graph

### Current File Structure

**Renderer Mixins** (`data/src/renderer_mixin/`):
- `accessors.cr` - Helper methods
- `render_fast.cr` - Fast static renders (home, map, about, summary, timeline, year reports, etc.)
- `render_post_related.cr` - Post-dependent renders (lists, pagination, redirects, debug)
- `render_post_and_photo_related.cr` - Combined post+photo renders
- `render_photo_related.cr` - Photo galleries and stats
- `render_photo_maps.cr` - SVG map generation
- `render_tags.cr` - Tag pages
- `render_towns.cr` - Town pages
- `render_voivodeships.cr` - Voivodeship pages
- `render_lands.cr` - Land pages
- `render_special.cr` - RSS, Atom, JSON feeds
- `render_overalls.cr` - Model-based renders (all tags, all towns, etc.)
- `render_todo.cr` - TODO routes

**View Types** (`data/src/views/`):
- `StaticView::*` - Static JS pages (map, ideas, timeline, exif stats) - there is no big logic when rendering html
- `DynamicView::*` - Dynamic pages (summary, timeline, year reports, towns history/timeline, burnout stats, debug views) - a lot of processing is being done here
- `PostListView::*` - Post collections (pagination, tags, towns, voivodeships, lands)
  - Old: `*ListView`, `*MasonryView`
  - New: `*DynamicView`, `CollectionDynamicView`, `NewPostsDynamicView` - while `NewPostsDynamicView` is just
  - while `PostListView::CollectionDynamicView` is new version of post index page
  - but `DynamicView::SummaryView` DynamicView is a namespace and it's confusing
- `PostView::ArticleView` - Individual post rendering
- `GalleryView::*` - Photo galleries (camera, lens, ISO, exposure, focal length, tag, location)
- `PhotoMap::*` - Various SVG map views - it's not deprecated but I'll focus on JS leaflet more now
- `SpecialView::*` - RSS, Atom, JSON generators, redirects
- `ModelView::*` - Index pages (towns index, lands index)

### Rendering Triggers (from blog.cr)

Full render (`force_full_render=true` or `mod_watcher.enabled=false`):
```crystal
renderer.render_all_photo_related
renderer.render_all_photo_maps
renderer.render_fast_only_post_related
renderer.render_fast_post_and_yaml_related
renderer.render_fast_static_renders
renderer.render_sitemap
```

Incremental render (mod_watcher):
- If exifs_changed: `render_all_photo_related`, `render_all_photo_maps`
- If posts_changed: `render_fast_only_post_related`
- If posts_changed || yamls_changed: `render_fast_post_and_yaml_related`
- Always: `render_fast_static_renders` (unclear why "fast" if always runs?)

### Views Status (Needs Verification)

**Confirmed New renderers**:
- `PostListView::CollectionDynamicView` (home page)
- `PostListView::NewPostsDynamicView` (new, latests posts)
- `PostListView::TownDynamicView` (town pages)
- `PostListView::TagDynamicView` (tag pages)
- `PostListView::VoivodeshipDynamicView` (voivodeship pages)
- `PostListView::LandDynamicView` (land/area pages)

**Not truly deprecated but need to be refreshed**:
- `DynamicView::*` (summary, timeline, year reports, towns history/timeline, burnout stats)

**Confirmed Deprecated**:
- `PostListView::HomeMasonryView` - commented out in render_home
- `PostListView::NewPostsView` - commented out
- `PostListView::NewPostsMasonryView` - commented out
- `PostListView::TownListView` - commented out
- `PostListView::TownMasonryView` - commented out
- `DynamicView::MountainRangePlannerView` - marked DEPRECATED
- `PostListView::PaginatedListView` - not uded. There will be some paginated view in future but current one is deprecated

**Unclear Status** (Need to check):
- Various `*ListView` and `*MasonryView` classes
- Some TODO-marked views - which one?

## Goals

### Immediate Goals (Low-Cost, High-Value)

1. ✅ **Clean up deprecated code** - Removed 14 deprecated views, -731 lines
2. ✅ **Document what's actually used** - Created VIEWS.md
3. ✅ **Consolidate naming** - Clarified in VIEWS.md
4. ✅ **Extract render registry** - ViewRegistry implemented, all views registered

### Medium-Term Goals (Moderate Investment)

5. ✅ **Separate concerns** - RenderContext + Coordinator decouple Blog from views
6. ~~**Create render pipeline**~~ → Changed to Registry approach
7. ✅ **Add view metadata** - Views registered with `depends_on` arrays
8. ✅ **Simplify conditional rendering** - Coordinator handles based on `changed` set

### Long-Term Goals (Future Refactoring)

9. ✅ **Architecture chosen** - Registry + Coordinator (not command/event-driven)
10. ✅ **Testing infrastructure** - 96 tests, MockRenderContext
11. ✅ **Lazy/on-demand rendering** - Registry enables this (only run entries matching `changed`)
12. [ ] **Remove `blog` dependency from views** - Views should receive only what they need
13. [ ] **Default URLs in view classes** - URLs defined in view class, not at call site

## Proposed Incremental Improvements

### Phase 1: Cleanup & Documentation ✅ COMPLETE

**Goal**: Understand what's actually used without changing behavior

1. ✅ **Audit views** - Listed all view classes in VIEWS.md
2. ✅ **Remove deprecated code** - Deleted 14 files, -731 lines
3. ✅ **Document render flow** - Created VIEWS.md with full render flow

### Phase 1.5: Testing Infrastructure ✅ COMPLETE

**Goal**: Enable independent view testing

1. ✅ **RenderContext** - Context object pattern for view data access
2. ✅ **MockRenderContext** - Testing without full Blog instance
3. ✅ **96 tests** - Coverage for all view categories

### Phase 2: View Registry + Coordinator ✅ COMPLETE

**Goal**: Centralize render logic, enable mixin removal

**Core classes** (implemented):
```crystal
# Register views with dependencies
registry = ViewRegistry.new
registry.task("Load EXIF", [:exifs], priority: 1) { |ctx| ... }
registry.register("Town pages", [:posts, :yamls], priority: 10) { |ctx| ... }

# Execute based on what changed
coordinator = RenderCoordinator.new(registry)
coordinator.render(context, changed: Set{:posts})
```

**Benefits**:
- Single source of truth for all views
- Queryable: `registry.names_depending_on(:posts)`
- Tasks (priority 1-9) run before views (priority 10+)
- Explicit dependencies enable lazy rendering
- Gradual mixin removal

**Migration path**:
1. Register all tasks (cache refresh, EXIF init, asset copy)
2. Register all views (one category at a time)
3. Test output matches current render
4. Remove mixin methods as views migrate
5. Delete empty mixin files

### Phase 3: Full Mixin Removal (Future)

**Goal**: All render logic in registry, no mixins

Once Phase 2 complete:
- Delete `renderer_mixin/` directory
- Renderer class becomes thin wrapper
- All logic in `view_registry/tasks/` and `view_registry/views/`

## Questions for Architectural Discussion

### Question 1: Incremental vs Full Refactoring? ✅ DECIDED

**Chosen**: Option A - Incremental approach
- Phase 1 cleanup completed
- Phase 2 Pipeline in progress
- Mixins still exist but wrapped by pipeline stages

### Question 2: What architecture for future? ✅ DECIDED

**Chosen**: Option D - Registry + Coordinator

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

**A. Command Pattern**: Each render is a command object
- Pros: Self-contained, testable
- Cons: Verbose (50+ command classes)
- Verdict: Similar benefits to Registry but more files

**B. Event-Driven**: Views subscribe to data change events
- Pros: Very decoupled
- Cons: Hard to trace flow
- Verdict: **Not suitable** - discoverability is already a problem

**C. Render Pipeline**: Sequential stages
- Pros: Explicit order, stages are testable
- Cons: Views still hidden inside stages, less queryable
- Verdict: Started but abandoned for Registry

### Question 3: View Lifecycle? ✅ DECIDED

**Chosen**: Option D - Context Object Pattern

Implementation in `data/src/render_context.cr`:
- `RenderContext` wraps Blog and provides typed accessors
- Views access `context.posts`, `context.towns`, etc.
- `BaseView` has lazy `context` property
- `MockRenderContext` enables testing without Blog

**Why Context Object won**:
- Single parameter simplifies signatures
- Can be built once, passed everywhere
- Easy to mock for testing
- Natural fit for pipeline architecture

### Question 4: Testing Strategy? ✅ IMPLEMENTED

**Infrastructure created**:
- `MockRenderContext` - test views without Blog
- `MockPost` - minimal post interface
- `MockHtmlBuffer` - buffer mock

**Test coverage** (136 tests total):

View tests (96 tests):
- PostListView: 8 tests
- DynamicView: 13 tests
- StaticView: 7 tests
- GalleryView: 17 tests
- SpecialView: 8 tests
- PhotoMap: 10 tests
- Other views: 14 tests
- RenderContext/mocks: 14 tests
- Example patterns: 5 tests

Registry tests (49 tests):
- ViewRegistry core: 13 tests
- Task registration: 4 tests
- View registration: 8 tests (entity, home, stats, feed, index, static, debug)
- Priority ordering: 10 tests
- Dependencies: 11 tests
- Query methods: 6 tests

**Future improvements** (not yet done):
- Snapshot testing for HTML output
- Integration tests for full coordinator
- Tests for remaining views (photo, feed, debug)

## Success Criteria

### Phase 1 Success (Cleanup): ✅ COMPLETE
- [x] All deprecated views removed
- [x] All active views documented
- [x] VIEWS.md created listing render flow
- [x] No behavior changes (validates successfully manually by human)

### Phase 2 Success (Registry): ✅ COMPLETE
- [x] ViewRegistry class implemented
- [x] RenderCoordinator class implemented
- [x] Task/View distinction with priorities
- [x] Register all data-loading tasks (6 tasks)
- [x] Register entity views (4 views)
- [x] Register home views (3 views)
- [x] Register photo views (2 views: galleries, maps)
- [x] Register stats views (5 views)
- [x] Register feed views (9 views)
- [x] Register index views (2 views)
- [x] Register static views (7 views)
- [x] Register debug views (3 views)
- [x] 49 tests for registry
- [x] Integrate coordinator with blog.cr (`render_with_registry`)
- [ ] Remove mixin methods as views are migrated (Phase 3)
- [ ] All render calls go through coordinator (Phase 3)

### Long-Term Success:
- [x] Can understand render flow in under 5 minutes (VIEWS.md + Registry)
- [ ] Can add new view type easily (just add `.register()` call)
- [x] Views are independently testable (96 tests)
- [ ] No duplicate render logic
- [ ] Clear separation: Blog → Coordinator → Registry → Views
- [ ] Mixins fully removed
- [ ] `registry.print_dependency_matrix` shows all dependencies

## Migration Safety

**To ensure no regressions**:

2. **Compare outputs**: Before/after file comparison for test render
3. **Incremental migration**: Change one mixin at a time
4. **Feature flags**: Keep old and new paths, switch gradually

## Next Steps

1. ~~**Review this plan** - Discuss with Opus~~ ✅ Done
2. ~~**Choose approach**~~ ✅ Chose Registry + Coordinator
3. ~~**Phase 2A: Register Tasks**~~ ✅ Done (6 tasks)
   - [x] `tasks/setup_tasks.cr` - copy assets, dev render
   - [x] `tasks/cache_tasks.cr` - refresh nav_stats, town_photo, coord_quant caches
   - [x] `tasks/exif_tasks.cr` - initialize EXIF data for posts
4. ~~**Phase 2B: Register Entity/Home/Index Views**~~ ✅ Done (9 views)
   - [x] `views/entity_views.cr` - towns, tags, voivodeships, lands pages
   - [x] `views/home_views.cr` - home, map, pois
   - [x] `views/index_views.cr` - towns index, lands index
5. ~~**Phase 2C: Register Photo Views**~~ ✅ Done (2 views)
   - [x] `views/photo_views.cr` - galleries (priority 30) + SVG maps (priority 35)
6. ~~**Phase 2D: Register Stats/Static Views**~~ ✅ Done (12 views)
   - [x] `views/stats_views.cr` - summary, year reports, burnout, towns history/timeline
   - [x] `views/static_views.cr` - about, more, JS pages
7. ~~**Phase 2E: Register Feed/Debug Views**~~ ✅ Done (12 views)
   - [x] `views/feed_views.cr` - RSS, Atom, JSON, sitemap, robots (9 views)
   - [x] `views/debug_views.cr` - debug pages (3 views)
8. ~~**Phase 2F: Integration**~~ ✅ Done
   - [x] Add `view_registry` and `render_coordinator` to Blog class
   - [x] Add `blog.render_with_registry` method (wrapper)
   - [x] Add `blog.render_all_with_registry` convenience method
   - [ ] Test output matches current render (manual validation needed)
   - [ ] Replace `blog.render` internals with coordinator (Phase 3)
   - [ ] Remove mixin methods one by one (Phase 3)
9. ~~**Phase 2G: Cleanup**~~ ✅ Done
   - [x] Delete abandoned pipeline files (`render_pipeline.cr`, `render_stages/`)
   - [ ] Delete empty mixin files (Phase 3)
   - [ ] Update VIEWS.md (or auto-generate from registry) (Phase 3)

## Phase 3: Full Migration 🚧 IN PROGRESS

**Goal**: Replace old render path with registry-based rendering

### Progress

**Infrastructure added:**
- [x] `RenderContext.write_output(view)` - render views from registry blocks
- [x] `RenderContext.validator` - access validator from registry blocks
- [x] `RenderContext.posts_descending`, `site_email`, `site_author`, `last_updated_at`, `years` - helpers for feed/stats views
- [x] `Renderer.render_view(view)` - public wrapper for write_output

**Views migrated (33 total):**
- [x] entity_views.cr (4): Towns, Tags, Voivodeships, Lands
- [x] index_views.cr (2): Towns index, Lands index
- [x] home_views.cr (3): Home, Map, POIs
- [x] stats_views.cr (5): Summary, Year reports, Burnout, Towns history/timeline
- [x] static_views.cr (7): More, About, English, JS pages
- [x] feed_views.cr (9): RSS, Atom, JSON files, Sitemap, Robots
- [x] debug_views.cr (3): Debug posts, camera, missing EXIF

**Still using wrappers:**
- [ ] photo_views.cr (2): Complex interdependencies - galleries return index views

### Remaining Steps

1. [ ] Validate `render_with_registry` output matches `render` output
2. [ ] Replace `make_it_so` to use `render_with_registry`
3. [ ] Migrate photo_views.cr (complex gallery logic)
4. [ ] Delete empty mixin files
5. [ ] Auto-generate VIEWS.md from registry

## Phase 4: View Decoupling (Future)

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

### Code Organization: `all.cr` Convention

Every directory with multiple `.cr` files should have an `all.cr` that requires all files in that directory:

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
- [ ] `views/static_view/` (already has it)
- [ ] `views/post_list_view/` (already has it)
- [ ] `views/gallery_view/`
- [ ] `views/special_view/` (already has it)
- [ ] `views/photo_map/`
- [ ] `views/model_view/` (already has it)

### Debug Views Reorganization

Debug views will be moved to a separate namespace:
- [ ] Create `DebugView` namespace (currently in `DynamicView::Debug*`)
- [ ] Move to `/debug/` URL prefix (already done for some)
- [ ] Consider priority: sometimes useful to render first for quick debugging
- [ ] Views to migrate:
  - `DynamicView::DebugPostView` → `DebugView::PostsView`
  - `DynamicView::DebugPostCameraStuffView` → `DebugView::CameraStuffView`
  - `DynamicView::DebugPostMissingPhotosExifView` → `DebugView::MissingExifView`

### Priority Order

Start with simple views (single URL, few dependencies):
1. StaticView classes (MoreView, MapView, etc.)
2. PoisView
3. DynamicView classes
4. PostListView classes (have entity parameter)
5. GalleryView classes (complex, many sub-views)

## Cost Estimates (Actual)

- **Phase 1 (Cleanup)**: ~2 hours ✅ Complete
- **Phase 1.5 (Testing)**: ~2 hours ✅ Complete
- **Phase 2 (Registry)**:
  - Infrastructure (base, coordinator, setup): ~1 hour ✅
  - Tasks (setup, exif, cache): ~0.5 hour ✅
  - Views (entity, home, stats, index, static): ~1.5 hours ✅
  - Views (feed, debug): ~0.5 hour ✅
  - Tests (49 specs): ~0.5 hour ✅
  - **Remaining**: photo views, integration (~1-2 hours)

---

## Phase 2 Detailed Design: Registry + Coordinator

### File Structure

```
data/src/view_registry/
  base.cr                 # ✅ ViewRegistry class
  coordinator.cr          # ✅ RenderCoordinator class
  all.cr                  # ✅ Requires everything
  setup.cr                # ✅ Combines all registrations
  tasks/
    setup_tasks.cr        # ✅ Copy assets, dev render (2 tasks)
    exif_tasks.cr         # ✅ EXIF initialization (1 task)
    cache_tasks.cr        # ✅ Cache refresh tasks (3 tasks)
  views/
    entity_views.cr       # ✅ Towns, tags, voivodeships, lands (4 views)
    home_views.cr         # ✅ Home, map, pois (3 views)
    photo_views.cr        # ✅ Photo galleries + SVG maps (2 views)
    stats_views.cr        # ✅ Summary, year reports, burnout, towns (5 views)
    feed_views.cr         # ✅ RSS, Atom, JSON, sitemap, robots (9 views)
    index_views.cr        # ✅ Towns index, lands index (2 views)
    static_views.cr       # ✅ About, more, JS pages (7 views)
    debug_views.cr        # ✅ Debug posts, camera, missing EXIF (3 views)

spec/
  view_registry_spec.cr   # ✅ 49 tests
```

**Current totals**: 6 tasks + 35 views = 41 entries registered

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

### Integration Strategy

**Step 1: Wrapper** (safe, parallel testing)
```crystal
class Blog
  def render_with_registry(posts_changed, yamls_changed, exifs_changed)
    context = RenderContext.new(self)
    changed = Set(Symbol).new
    changed << :posts if posts_changed
    changed << :yamls if yamls_changed
    changed << :exifs if exifs_changed
    coordinator.render(context, changed)
  end
end
```

**Step 2: Validate** - Compare output of both methods

**Step 3: Replace** - Once validated, replace `render` internals

**Step 4: Remove mixins** - Delete as views migrate to registry

### Migration Pattern for Each View

1. Find mixin method (e.g., `render_town_page` in `render_towns.cr`)
2. Create registration in `views/entity_views.cr`
3. Move logic into registration block (or keep calling mixin temporarily)
4. Test that view still renders correctly
5. Once all views from mixin are migrated, delete mixin file

### Querying the Registry

```crystal
# What runs when posts change?
registry.names_depending_on(:posts)
# => ["Town pages", "Tag pages", "Home page", "RSS feed", ...]

# Print full dependency matrix
registry.print_dependency_matrix

# Generate markdown documentation
File.write("VIEWS_AUTO.md", registry.to_markdown)
```

---

## Project Context

- Crystal static site generator
- ~100 blog posts with routes, photos, EXIF data
- Multiple entity types: towns, tags, voivodeships, lands, meso/macro regions
- Various view types: lists, galleries, maps, feeds
- Incremental rendering with mod_watcher for fast dev cycle
- Full rendering for production deployment
