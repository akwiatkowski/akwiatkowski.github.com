# Renderer & Views Refactoring Plan

## Goal

Replace `@blog` dependency in views with explicit `RenderContext` methods.

**Principle:** No generic access like `context["key"]` or `context.data_manager.x`. Use explicit methods that hide `not_nil!` boilerplate.

**Related docs:**
- `VIEWS.md` - Full analysis of what each view needs
- `CLAUDE.md` - Project structure reference

---

## Step 1: Add Entity Methods to RenderContext

**File:** `data/src/render_context.cr`

**Task:** Add methods for entities not yet exposed.

### 1.1 Add `train_stations` method

After the `tags` method (~line 106), add:

```crystal
def train_stations
  config.train_stations.not_nil!
end
```

**Used by:** `special_view/train_stations_json_generator.cr`

### 1.2 Add `ideas` method

```crystal
def ideas
  config.ideas.not_nil!
end
```

**Used by:** `special_view/ideas_json_generator.cr`

### 1.3 Add `portfolios` method

```crystal
def portfolios
  config.portfolios.not_nil!
end
```

**Used by:** `dynamic_view/portfolio_view.cr`

### 1.4 Add `exif_db` method

```crystal
def exif_db
  config.exif_db
end
```

**Used by:** Gallery views, `exif_stats_view.cr`, `debug_tag_stats_view.cr`, `timeline_photo_view.cr`

### 1.5 Add `photo_coord_quant_cache` method

```crystal
def photo_coord_quant_cache
  config.photo_coord_quant_cache.not_nil!
end
```

**Used by:** `gallery_view/quant_coord_index_view.cr`

### 1.6 Add `page_meta` helper

Add new section after Caches (~line 115):

```crystal
# ============================================
# Page Metadata
# ============================================

# Returns title, subtitle, backgrounds for a page type
# Usage: meta = context.page_meta("summary")
#        meta[:title], meta[:subtitle], meta[:backgrounds]
def page_meta(name : String)
  {
    title: config["#{name}.title"].to_s,
    subtitle: config["#{name}.subtitle"]?.try(&.to_s) || "",
    backgrounds: config["#{name}.backgrounds"].to_s,
  }
end
```

**Used by:** summary_view, towns_history_view, towns_timeline_view, map_view, pois_view, lands_index_view, towns_index_view, and more.

### 1.7 Verify

Run `crystal spec` - all 146 tests should pass.

---

## Step 2: Migrate Simple Post-Only Views

These views only use `@blog.post_collection.posts`. Change to use `context.posts`.

### 2.1 Migrate `debug_post_view.cr`

**File:** `data/src/views/dynamic_view/debug_post_view.cr`

**Find:** `@blog.post_collection.posts`
**Replace with:** Pass posts via constructor or add context

**Pattern:**
```crystal
# Before:
@blog.post_collection.posts.each do |post|

# After (if view has @context):
@context.posts.each do |post|

# Or if view receives @blog, access via context in registry block
```

**Note:** Check how view is instantiated in `view_registry/views/debug_views.cr`

### 2.2 Migrate `debug_post_camera_stuff_view.cr`

**File:** `data/src/views/dynamic_view/debug_post_camera_stuff_view.cr`

Same pattern as 2.1.

### 2.3 Migrate `debug_post_missing_photos_exif_view.cr`

**File:** `data/src/views/dynamic_view/debug_post_missing_photos_exif_view.cr`

Same pattern as 2.1.

### 2.4 Migrate `new_posts_dynamic_view.cr`

**File:** `data/src/views/post_list_view/new_posts_dynamic_view.cr`

**Find:** Usage of `@blog.post_collection`
**Check:** How posts are accessed

### 2.5 Migrate `photos_json_generator.cr`

**File:** `data/src/views/special_view/photos_json_generator.cr`

**Find:** `@blog.post_collection`
**Replace:** Use context or pass posts in constructor

### 2.6 Verify

Run `crystal spec` after each migration.

---

## Step 3: Migrate Config-Using Views

These views use `@blog.data_manager["page.title"]` pattern. Change to `context.page_meta("page")`.

### 3.1 Migrate `summary_view.cr`

**File:** `data/src/views/dynamic_view/summary_view.cr`

**Current code (around line 8-10):**
```crystal
@image_url = @blog.data_manager.not_nil!["summary.backgrounds"].as(String)
@title = @blog.data_manager.not_nil!["summary.title"].as(String)
@subtitle = @blog.data_manager.not_nil!["summary.subtitle"].as(String)
```

**Options:**
1. Add `@context` to view, use `context.page_meta("summary")`
2. Pass title/subtitle/backgrounds via constructor from registry

**Recommended:** Option 2 - keep view simple, registry does the lookup.

**Registry change** (`view_registry/views/stats_views.cr`):
```crystal
r.register("Stats: summary page", [:posts, :yamls], priority: 40) do |ctx|
  meta = ctx.page_meta("summary")
  ctx.write_output(DynamicView::SummaryView.new(
    blog: ctx.blog,
    title: meta[:title],
    subtitle: meta[:subtitle],
    image_url: meta[:backgrounds]
  ))
end
```

### 3.2 Migrate `towns_history_view.cr`

**File:** `data/src/views/dynamic_view/towns_history_view.cr`

Same pattern - use `ctx.page_meta("towns_history")` in registry.

### 3.3 Migrate `towns_timeline_view.cr`

**File:** `data/src/views/dynamic_view/towns_timeline_view.cr`

Same pattern - use `ctx.page_meta("towns_timeline")` in registry.

### 3.4 Migrate `map_view.cr`

**File:** `data/src/views/static_view/map_view.cr`

Use `ctx.page_meta("map")` in registry.

### 3.5 Migrate `pois_view.cr`

**File:** `data/src/views/pois_view.cr`

Use `ctx.page_meta("pois")` in registry.

### 3.6 Migrate `lands_index_view.cr`

**File:** `data/src/views/model_view/lands_index_view.cr`

Use `ctx.page_meta("lands")` in registry.

### 3.7 Migrate `towns_index_view.cr`

**File:** `data/src/views/model_view/towns_index_view.cr`

Use `ctx.page_meta("towns")` in registry.

### 3.8 Verify

Run `crystal spec` after each migration.

---

## Step 4: Migrate Entity-Using Views

### 4.1 Migrate `train_stations_json_generator.cr`

**File:** `data/src/views/special_view/train_stations_json_generator.cr`

**Current:** `@blog.data_manager.train_stations!`
**Change:** Use `ctx.train_stations` in registry, pass to constructor

### 4.2 Migrate `ideas_json_generator.cr`

**File:** `data/src/views/special_view/ideas_json_generator.cr`

**Current:** `@blog.data_manager.ideas!`
**Change:** Use `ctx.ideas` in registry, pass to constructor

### 4.3 Migrate `portfolio_view.cr`

**File:** `data/src/views/dynamic_view/portfolio_view.cr`

**Current:** `@blog.data_manager.portfolios!`
**Change:** Use `ctx.portfolios` in registry, pass to constructor

### 4.4 Migrate `payload_json_generator.cr`

**File:** `data/src/views/special_view/payload_json_generator.cr`

**Current:** Uses `@blog.post_collection.posts`, `@blog.data_manager.towns`, etc.
**Change:** Pass entities via constructor from registry using `ctx.towns`, `ctx.voivodeships`, etc.

### 4.5 Verify

Run `crystal spec` after each migration.

---

## Step 5: Migrate EXIF-Using Views

### 5.1 Migrate `exif_stats_view.cr`

**File:** `data/src/views/dynamic_view/exif_stats_view.cr`

**Current:** Uses `@blog.data_manager` and `@blog.post_collection`
**Change:** Use `ctx.exif_db`, `ctx.posts` in registry

### 5.2 Migrate `debug_tag_stats_view.cr`

**File:** `data/src/views/dynamic_view/debug_tag_stats_view.cr`

Same pattern.

### 5.3 Migrate `timeline_photo_view.cr`

**File:** `data/src/views/dynamic_view/timeline_photo_view.cr`

Same pattern.

### 5.4 Verify

Run `crystal spec` after each migration.

---

## Deferred (Next Iteration)

### Complex Views
- `markdown_page_view.cr` - needs `pages_path`, `markdown_wrapper`
- `more_view.cr` - needs `pages_path`, `data_path`
- `article_view.cr` - critical path, needs careful testing
- SVG map views - low priority
- Gallery `abstract_view.cr` - base class, affects many views

### After All Views Migrated
- Remove `context.config` public access
- Remove `context[]` and `context[]?` methods
- Services decoupling (separate work)

### Logging Improvements (Phase 4)
- Reduce log noise
- Remove redundant log lines
- Simplify timestamp format

---

## How to Work on This

1. Load `CLAUDE.md` for project structure
2. Load `VIEWS.md` for detailed analysis
3. Pick ONE step (e.g., "Step 1.1: Add train_stations method")
4. Make the change
5. Run `crystal spec`
6. Commit with descriptive message
7. Update this file: mark step as `[x]` done
8. Proceed to next step

---

## Progress Tracking

### Step 1: RenderContext Methods
- [ ] 1.1 `train_stations`
- [ ] 1.2 `ideas`
- [ ] 1.3 `portfolios`
- [ ] 1.4 `exif_db`
- [ ] 1.5 `photo_coord_quant_cache`
- [ ] 1.6 `page_meta`
- [ ] 1.7 Verify all tests pass

### Step 2: Simple Post-Only Views
- [ ] 2.1 `debug_post_view`
- [ ] 2.2 `debug_post_camera_stuff_view`
- [ ] 2.3 `debug_post_missing_photos_exif_view`
- [ ] 2.4 `new_posts_dynamic_view`
- [ ] 2.5 `photos_json_generator`
- [ ] 2.6 Verify

### Step 3: Config-Using Views
- [ ] 3.1 `summary_view`
- [ ] 3.2 `towns_history_view`
- [ ] 3.3 `towns_timeline_view`
- [ ] 3.4 `map_view`
- [ ] 3.5 `pois_view`
- [ ] 3.6 `lands_index_view`
- [ ] 3.7 `towns_index_view`
- [ ] 3.8 Verify

### Step 4: Entity-Using Views
- [ ] 4.1 `train_stations_json_generator`
- [ ] 4.2 `ideas_json_generator`
- [ ] 4.3 `portfolio_view`
- [ ] 4.4 `payload_json_generator`
- [ ] 4.5 Verify

### Step 5: EXIF-Using Views
- [ ] 5.1 `exif_stats_view`
- [ ] 5.2 `debug_tag_stats_view`
- [ ] 5.3 `timeline_photo_view`
- [ ] 5.4 Verify
