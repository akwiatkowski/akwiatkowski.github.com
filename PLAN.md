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

## Step 6: Output History Comparator

Replace the basic diff in `HtmlBuffer` with a persistent history tracking system.

### 6.1 Requirements

**Purpose:** Track changes to rendered outputs across render sessions. Helps detect
when small code changes cause unexpected large output changes.

**What to track:**
- HTML and SVG files only
- Exclude: JSON files, binary files, files > 500KB

**Storage location:** `env/dev/history/<target>/` where target is `local` or `release`

**Storage structure:**
```
env/dev/history/
└── local/                               # Target subdirectory
    ├── index.html                       # Summary page (open in browser)
    └── tag__najnowsze.html/             # Directory per output (flattened path)
        ├── 2026-02-03__14-30            # Version 1 (oldest)
        ├── 2026-02-03__14-35            # Version 2
        ├── 2026-02-03__14-40            # Version 3 (newest)
        └── 2026-02-03__14-40.diff       # Diff: v2 → v3
```

**Path flattening:** `/tag/najnowsze.html` → `tag__najnowsze.html`

**Version limit:** Keep only 3 versions per file. Delete oldest when adding new.

**Timestamp format:** `YYYY-mm-dd__HH-MM` (no colons, filesystem safe)

### 6.2 Behavior

**When content changes:**
1. `HtmlBuffer#check` returns `true` (content differs)
2. If file is trackable (HTML/SVG, <500KB, non-JSON):
   - Save new content to history directory with timestamp
   - Run `diff -u old_version new_version > timestamp.diff`
   - Delete oldest version if > 3 versions
3. Write file to disk (existing behavior)

**When content unchanged:**
- No history entry created
- No diff generated

**At end of render:**
- Generate `index.html` listing all files that changed this session

### 6.3 Integration Details

**IMPORTANT:** OutputHistory must be initialized BEFORE PostRenderer runs.

The render flow is:
1. `Blog#render()` is called
2. `PostRenderer` renders individual posts (uses `ctx.write_output`)
3. `render_with_registry()` renders aggregate views

OutputHistory must be initialized at step 1, not step 3, otherwise post
changes won't be tracked.

**Target detection:**
- `output_path` is like `env/dev/public/local` or `env/dev/public/release`
- Extract target from last path component of output_path
- Include inline diff preview or links to .diff files

### 6.3 Implementation

**New service:** `OutputHistory` class in `data/src/services/output_history.cr`

```crystal
class OutputHistory
  MAX_SIZE = 500_000  # 500KB
  MAX_VERSIONS = 3
  HISTORY_PATH = "env/dev/history"

  def initialize(target : String = "local")  # "local" or "release"
  def trackable?(url : String, content : String) : Bool
  def track(url : String, old_content : String, new_content : String)
  def generate_index_html
end
```

**Integration point:** Hook into `write_output` after `HtmlBuffer#check` returns true.

**Remove:** `HtmlBuffer#display_diff_of_content` and `#diff_lines` methods (replaced by this feature).

### 6.4 index.html Format

Simple HTML page showing:
- Render timestamp
- List of changed files with:
  - File path/URL
  - Link to view diff
  - Optionally: inline diff preview (collapsible)

---

## Deferred (Next Iteration)

### Photo Map Views Migration
- 10 photo_map views still use `@blog`
- Requires migrating `Map::Base` and `Map::Main` services first
- Lower priority - SVG generation works fine

### After All Views Migrated
- Remove `context.config` public access
- Remove `context[]` and `context[]?` methods
- Services decoupling (separate work)

### Logging Improvements
- Reduce log noise
- Remove redundant log lines
- Simplify timestamp format
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

### Completed Infrastructure Changes

- [x] Step 1: RenderContext methods added (train_stations, ideas, portfolios, exif_db, photo_coord_quant_cache, page_meta, photo_tags, layout_path, data_path, pages_path, markdown_wrapper, photo_map_dictionary, next_to, prev_to, towns_already_visited_only_selfpropelled)
- [x] Made `@blog` nilable in `Tremolite::Views::BaseView` (data/src/tremolite/base_view.cr)
- [x] Added context-based constructor to BaseView hierarchy
- [x] Changed `PhotoEntity` to accept `photo_tags` instead of `blog`
- [x] Updated `post_function_parser.cr` to use context

### Views Migrated to Context (constructor takes `context: RenderContext`)

- [x] `debug_post_view.cr`
- [x] `collection_dynamic_view.cr`
- [x] `map_view.cr`
- [x] `pois_view.cr`
- [x] `quant_coord_index_view.cr`
- [x] `gallery_view/index_view.cr`
- [x] `debug_tag_stats_view.cr`
- [x] `timeline_photo_view.cr`
- [x] `portfolio_view.cr`
- [x] `exif_stats_view.cr`
- [x] `gallery_view/abstract_view.cr` (uses context.posts, context.config)
- [x] `photo_map/index_view.cr`
- [x] `summary_view.cr`
- [x] `year_stat_report_view.cr`
- [x] `burnout_stat_view.cr` (and `BurnoutStat` service)
- [x] `towns_history_view.cr`
- [x] `towns_timeline_view.cr`
- [x] `towns_index_view.cr`
- [x] `lands_index_view.cr`
- [x] `more_view.cr`
- [x] `markdown_page_view.cr`
- [x] `debug_post_camera_stuff_view.cr`
- [x] `debug_post_missing_photos_exif_view.cr`
- [x] `js_ideas_view.cr`
- [x] `js_timeline_view.cr`
- [x] `js_panoramio_view.cr`
- [x] `js_exif_view.cr`
- [x] `town_dynamic_view.cr`
- [x] `tag_dynamic_view.cr`
- [x] `voivodeship_dynamic_view.cr`
- [x] `land_dynamic_view.cr`
- [x] `train_stations_json_generator.cr`
- [x] `ideas_json_generator.cr`
- [x] `photos_json_generator.cr`
- [x] `nav_stats_json_generator.cr`
- [x] `payload_json_generator.cr`
- [x] `rss_generator.cr` (removed unused @blog param)
- [x] `atom_generator.cr` (removed unused @blog param)
- [x] `post_gallery_stats_view.cr`
- [x] `mountain_range_planner_view.cr`
- [x] `land_view.cr`
- [x] `new_posts_dynamic_view.cr`
- [x] `post_view/article_view.cr`
- [x] `gallery_view/post_view.cr`
- [x] `gallery_view/tag_view.cr`, `camera_view.cr`, `lens_view.cr`
- [x] `gallery_view/focal_length_view.cr`, `iso_view.cr`, `exposure_view.cr`
- [x] `gallery_view/quant_coord_view.cr`
- [x] `gallery_view/*_index_view.cr` (all 7 index views)
- [x] `special_view/redirect_view.cr` (unused @blog removed)
- [x] `static_view/js_bicycle_planner_view.cr` (unused @blog removed)

### Views Still Using @blog (require service refactoring)

**photo_map views** (10 files) - pass `@blog` to `Map::Base`/`Map::Main` services:
- `abstract_svg_view.cr` (base class)
- `global_grid_map_svg_view.cr`
- `global_grid_and_routes_map_svg_view.cr`
- `global_animated_routes_map_svg_view.cr`
- `global_dots_map_svg_view.cr`
- `post_big_map_svg_view.cr`
- `post_route_map_svg_view.cr`
- `multiple_posts_grid_and_routes_map_svg_view.cr`
- `multiple_photo_entities_grid_map_svg_view.cr`
- `idea_route_map_svg_view.cr`

**Note:** These require migrating `Map::Base` and `Map::Main` services first.

**External dependency:**
- `SiteMapGenerator` (Tremolite library)

### Current Session State

**Tests:** 146 examples, 0 failures, 0 errors, 2 pending

**Next steps (choose one):**
1. Migrate `Map::Base`/`Map::Main` services → enables photo_map views migration
2. Implement Step 6.0 (versioning history for HTML/SVG outputs)
3. Clean up: remove `blog = ctx.blog` from registry where unused
