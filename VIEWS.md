# View Registry

*Auto-generated from ViewRegistry. Source: `data/src/view_registry/`*

## Summary

- **Tasks**: 6
- **Views**: 35
- **Total entries**: 41

## What runs when...

| Trigger | Entries |
|---------|---------|
| `:posts` changed | 27 entries |
| `:yamls` changed | 20 entries |
| `:exifs` changed | 9 entries |
| Always runs | 5 entries |

## Entries by Category

### Setup tasks (priority 1..2)

Dev render, copy assets

| Priority | Name | Triggers |
|----------|------|----------|
| 1 | Setup: dev render | always |
| 2 | Setup: copy assets | always |

### EXIF tasks (priority 3..4)

Initialize EXIF data

| Priority | Name | Triggers |
|----------|------|----------|
| 4 | EXIF: init all posts | exifs |

### Cache tasks (priority 5..9)

Refresh caches

| Priority | Name | Triggers |
|----------|------|----------|
| 5 | Cache: nav stats | yamls |
| 6 | Cache: town photos | exifs |
| 6 | Cache: coord quant | exifs |

### Entity views (priority 10..19)

Towns, tags, voivodeships, lands

| Priority | Name | Triggers |
|----------|------|----------|
| 10 | Towns: all pages | posts, yamls |
| 11 | Tags: all pages | posts, yamls |
| 12 | Voivodeships: all pages | posts, yamls |
| 13 | Lands: all pages | posts, yamls |

### Home views (priority 20..29)

Home, map, POIs

| Priority | Name | Triggers |
|----------|------|----------|
| 20 | Home: main page | posts |
| 21 | Home: map page | posts |
| 22 | Home: POIs page | posts |

### Photo views (priority 30..39)

Galleries, photo maps

| Priority | Name | Triggers |
|----------|------|----------|
| 30 | Photo galleries: all | exifs |
| 35 | Photo maps: all | exifs |

### Stats views (priority 40..49)

Summary, year reports, burnout

| Priority | Name | Triggers |
|----------|------|----------|
| 40 | Stats: summary page | posts, yamls |
| 41 | Stats: year reports | posts, yamls |
| 42 | Stats: burnout | posts, yamls |
| 43 | Stats: towns history | posts, yamls |
| 44 | Stats: towns timeline | posts, yamls |

### Feed views (priority 50..59)

RSS, Atom, JSON, sitemap

| Priority | Name | Triggers |
|----------|------|----------|
| 50 | Feed: RSS | posts, yamls |
| 51 | Feed: Atom | posts, yamls |
| 52 | Feed: payload JSON | posts, yamls |
| 53 | Feed: ideas JSON | posts, yamls |
| 54 | Feed: photos JSON | posts, yamls |
| 55 | Feed: train stations JSON | posts, yamls |
| 56 | Feed: nav stats JSON | posts, yamls |
| 57 | Feed: sitemap | posts |
| 58 | Feed: robots.txt | always |

### Index views (priority 60..69)

Entity indexes

| Priority | Name | Triggers |
|----------|------|----------|
| 60 | Index: towns | posts, yamls |
| 61 | Index: lands | posts, yamls |

### Static views (priority 90..99)

About, more, JS pages

| Priority | Name | Triggers |
|----------|------|----------|
| 90 | Static: more page | always |
| 91 | Static: about page | always |
| 92 | Static: english page | always |
| 93 | Static: JS ideas | posts |
| 94 | Static: JS timeline | posts |
| 95 | Static: JS panoramio | posts |
| 96 | Static: JS exif stats | posts |

### Debug views (priority 100..199)

Diagnostic pages

| Priority | Name | Triggers |
|----------|------|----------|
| 100 | Debug: posts | posts |
| 101 | Debug: camera stuff | exifs |
| 102 | Debug: missing EXIF | exifs |

## Dependency Matrix

```
Entry                            | Type | Pri | posts | yamls | exifs |
---------------------------------|------|-----|-------|-------|-------|
Setup: dev render                | task |   1 |       |       |       |
Setup: copy assets               | task |   2 |       |       |       |
EXIF: init all posts             | task |   4 |       |       |   ✓   |
Cache: nav stats                 | task |   5 |       |   ✓   |       |
Cache: town photos               | task |   6 |       |       |   ✓   |
Cache: coord quant               | task |   6 |       |       |   ✓   |
Towns: all pages                 | view |  10 |   ✓   |   ✓   |       |
Tags: all pages                  | view |  11 |   ✓   |   ✓   |       |
Voivodeships: all pages          | view |  12 |   ✓   |   ✓   |       |
Lands: all pages                 | view |  13 |   ✓   |   ✓   |       |
Home: main page                  | view |  20 |   ✓   |       |       |
Home: map page                   | view |  21 |   ✓   |       |       |
Home: POIs page                  | view |  22 |   ✓   |       |       |
Photo galleries: all             | view |  30 |       |       |   ✓   |
Photo maps: all                  | view |  35 |       |       |   ✓   |
Stats: summary page              | view |  40 |   ✓   |   ✓   |       |
Stats: year reports              | view |  41 |   ✓   |   ✓   |       |
Stats: burnout                   | view |  42 |   ✓   |   ✓   |       |
Stats: towns history             | view |  43 |   ✓   |   ✓   |       |
Stats: towns timeline            | view |  44 |   ✓   |   ✓   |       |
Feed: RSS                        | view |  50 |   ✓   |   ✓   |       |
Feed: Atom                       | view |  51 |   ✓   |   ✓   |       |
Feed: payload JSON               | view |  52 |   ✓   |   ✓   |       |
Feed: ideas JSON                 | view |  53 |   ✓   |   ✓   |       |
Feed: photos JSON                | view |  54 |   ✓   |   ✓   |       |
Feed: train stations JSON        | view |  55 |   ✓   |   ✓   |       |
Feed: nav stats JSON             | view |  56 |   ✓   |   ✓   |       |
Feed: sitemap                    | view |  57 |   ✓   |       |       |
Feed: robots.txt                 | view |  58 |       |       |       |
Index: towns                     | view |  60 |   ✓   |   ✓   |       |
Index: lands                     | view |  61 |   ✓   |   ✓   |       |
Static: more page                | view |  90 |       |       |       |
Static: about page               | view |  91 |       |       |       |
Static: english page             | view |  92 |       |       |       |
Static: JS ideas                 | view |  93 |   ✓   |       |       |
Static: JS timeline              | view |  94 |   ✓   |       |       |
Static: JS panoramio             | view |  95 |   ✓   |       |       |
Static: JS exif stats            | view |  96 |   ✓   |       |       |
Debug: posts                     | view | 100 |   ✓   |       |       |
Debug: camera stuff              | view | 101 |       |       |   ✓   |
Debug: missing EXIF              | view | 102 |       |       |   ✓   |
```

## Priority Guide

| Range | Name | Description |
|-------|------|-------------|
| 1..2 | Setup tasks | Dev render, copy assets |
| 3..4 | EXIF tasks | Initialize EXIF data |
| 5..9 | Cache tasks | Refresh caches |
| 10..19 | Entity views | Towns, tags, voivodeships, lands |
| 20..29 | Home views | Home, map, POIs |
| 30..39 | Photo views | Galleries, photo maps |
| 40..49 | Stats views | Summary, year reports, burnout |
| 50..59 | Feed views | RSS, Atom, JSON, sitemap |
| 60..69 | Index views | Entity indexes |
| 90..99 | Static views | About, more, JS pages |
| 100..199 | Debug views | Diagnostic pages |

---

## Source Files

The registry is defined in `data/src/view_registry/`:

- `base.cr` - ViewRegistry class and PRIORITY_GROUPS
- `coordinator.cr` - RenderCoordinator execution
- `setup.cr` - Registration orchestration
- `tasks/*.cr` - Task registrations
- `views/*.cr` - View registrations

---

# View Decoupling Analysis

This section documents what each view needs from `@blog` to help plan migration to context-only views.

## Current State

- **91 total view files** in `data/src/views/`
- **39 files** use `@blog.*` directly
- **52 files** don't use `@blog` (already decoupled or use inherited data)

## @blog Usage Summary

| Usage | Count | Notes |
|-------|-------|-------|
| `@blog.data_manager` | 74 | Config values, entities, caches |
| `@blog.post_collection` | 25 | Posts array |
| `@blog.pages_path` | 2 | Markdown pages path |
| `@blog.data_path` | 2 | Data directory path |
| `@blog.validator` | 1 | Output validation |
| `@blog.markdown_wrapper` | 1 | Markdown processing |

## RenderContext Design

### Principle: Explicit Methods, No Generic Access

Instead of `context["key"]` or `context.data_manager.something`, prefer explicit methods:
- `context.train_stations` (not `context.data_manager.train_stations.not_nil!`)
- `context.page_meta("summary")` (not `context["summary.title"]`)

This makes dependencies explicit and hides `not_nil!` boilerplate.

### Currently Available

| Method | Description |
|--------|-------------|
| `posts`, `posts_from_latest`, `ready_posts` | Post arrays |
| `posts_descending`, `last_updated_at`, `years` | Post helpers |
| `voivodeships`, `towns`, `lands`, `tags` | Entity arrays |
| `posts_for(entity)`, `posts_for_year(year)` | Filtered posts |
| `site_title`, `site_url`, `site_desc`, `site_email`, `site_author` | Site config |
| `nav_stats_cache` | Navigation stats |
| `validator` | Output validation |
| `output_path`, `html_buffer`, `write_output` | Rendering |

### To Add (Phase 1)

| Method | Used By | Notes |
|--------|---------|-------|
| `exif_db` | Gallery views, debug views | High priority |
| `train_stations` | train_stations_json_generator | |
| `ideas` | ideas_json_generator | |
| `portfolios` | portfolio_view | |
| `photo_coord_quant_cache` | quant_coord views | |
| `page_meta(name)` | All page views | Returns `{title, subtitle, backgrounds}` |

### Defer to Later

| Need | Used By | Notes |
|------|---------|-------|
| `pages_path`, `data_path` | markdown_page_view, more_view | Only 2 views |
| `markdown_wrapper` | markdown_page_view | Only 1 view |
| `photo_map_dictionary` | SVG map views | Low priority (Leaflet focus) |

## Config Key Patterns

Views access page-specific config like `["summary.title"]`, `["summary.backgrounds"]`.

**Pattern found:**
- 14 page types use `.title`, `.subtitle`, `.backgrounds`
- Pattern: `{page}.title`, `{page}.subtitle`, `{page}.backgrounds`

**Solution:** Add `page_meta(name)` helper:
```crystal
def page_meta(name : String)
  {
    title: config["#{name}.title"].to_s,
    subtitle: config["#{name}.subtitle"]?.try(&.to_s) || "",
    backgrounds: config["#{name}.backgrounds"].to_s
  }
end
```

## Other @blog Consumers

Not just views use `@blog` - services do too:

| File | Needs |
|------|-------|
| `services/nav_stats_cache.cr` | cache_path, data_manager, post_collection |
| `services/town_photo_cache.cr` | cache_path, data_manager |
| `services/burnout_stat.cr` | post_collection |
| `services/post_coord_quant_cache.cr` | blog |
| `services/photo_coord_quant_cache.cr` | blog |
| `post_renderer.cr` | blog (for image_resizer, data_manager, ctx) |
| `renderer.cr` | blog |
| `validator.cr` | blog |

**Note:** Services decoupling is separate work - focus on views first, but be aware services exist.

## Views by Migration Complexity

### Already Decoupled (52 files)

These don't use `@blog.*` directly - either base classes or receive data through constructor:

**Base/Layout classes:**
- `base_view`, `page_view`, `wide_page_view`, `wider_page_view`, `widest_page_view`

**Post list views (receive entity in constructor):**
- `town_dynamic_view`, `tag_dynamic_view`, `voivodeship_dynamic_view`, `land_dynamic_view`

**Gallery views (inherit from abstract_view):**
- `camera_view`, `lens_view`, `iso_view`, `exposure_view`, `focal_length_view`
- `tag_view`, `quant_coord_view`
- All `*_index_view` variants

**Static JS pages:**
- `js_ideas_view`, `js_timeline_view`, `js_panoramio_view`, `js_bicycle_planner_view`, `js_exif_view`

**Feed generators:**
- `rss_generator`, `atom_generator`

**Other:**
- `redirect_view`, `burnout_stat_view`, `item_mixin`

### Simple Migration (12 files)

Only need `posts` and/or `config["key"]` - already in RenderContext:

| View | Needs |
|------|-------|
| `collection_dynamic_view` | `data_manager["home.title"]` |
| `new_posts_dynamic_view` | `post_collection.posts` |
| `land_view` | `post_collection` |
| `debug_post_view` | `post_collection.posts` |
| `debug_post_camera_stuff_view` | `post_collection.posts` |
| `debug_post_missing_photos_exif_view` | `post_collection.posts` |
| `map_view` | `data_manager["map.*"]` |
| `index_view` (gallery) | `data_manager["gallery.*"]` |
| `index_view` (model) | `data_manager`, `towns`, `lands` |
| `lands_index_view` | `data_manager["lands.*"]`, `lands` |
| `towns_index_view` | `data_manager["towns.*"]`, `towns` |

### Medium Migration (15 files)

Need `posts` + `entities` + `config` - mostly in RenderContext:

| View | Needs | Missing |
|------|-------|---------|
| `summary_view` | posts, config | - |
| `year_stat_report_view` | posts, config | - |
| `towns_history_view` | posts, towns, config | - |
| `towns_timeline_view` | posts, towns, config | - |
| `pois_view` | posts, towns, config | - |
| `payload_json_generator` | posts, towns, voivodeships, tags, lands | - |
| `nav_stats_json_generator` | nav_stats_cache | - |
| `train_stations_json_generator` | train_stations | `train_stations` |
| `ideas_json_generator` | ideas | `ideas` |
| `photos_json_generator` | post_collection | - |
| `portfolio_view` | posts, portfolios, config | `portfolios` |
| `timeline_photo_view` | posts, exif_db, config | `exif_db` |
| `debug_tag_stats_view` | posts, exif_db | `exif_db` |
| `exif_stats_view` | posts, exif_db | `exif_db` |
| `quant_coord_index_view` | photo_coord_quant_cache | `photo_coord_quant_cache` |

### Complex Migration (12 files)

Need EXIF data, caches, or special infrastructure:

| View | Needs | Notes |
|------|-------|-------|
| `abstract_view` (gallery) | data_manager, post_collection | Base for all gallery views |
| `article_view` | data_manager, post_collection, validator | Main post renderer |
| `post_view` (gallery) | post_collection | Post gallery page |
| `post_gallery_stats_view` | post_collection | Post stats page |
| `seo_helper` | data_manager | SEO metadata |
| `more_view` | data_manager, pages_path, data_path | Loads markdown |
| `markdown_page_view` | pages_path, data_path, markdown_wrapper | Loads markdown |
| `mountain_range_planner_view` | data_manager | DEPRECATED |
| All `*_map_svg_view` | data_manager | SVG map generation |

## Migration Plan

### Step 1: Extend RenderContext

Add explicit methods (no generic `[]` access):

```crystal
# Entities
def train_stations
  config.train_stations.not_nil!
end

def ideas
  config.ideas.not_nil!
end

def portfolios
  config.portfolios.not_nil!
end

# EXIF
def exif_db
  config.exif_db
end

# Caches
def photo_coord_quant_cache
  config.photo_coord_quant_cache.not_nil!
end

# Page metadata helper
def page_meta(name : String)
  {
    title: config["#{name}.title"].to_s,
    subtitle: config["#{name}.subtitle"]?.try(&.to_s) || "",
    backgrounds: config["#{name}.backgrounds"].to_s
  }
end
```

### Step 2: Migrate Simple Views

Views that only need posts or entities (already in context):

| View | Change |
|------|--------|
| `debug_post_view` | `@blog.post_collection.posts` → `context.posts` |
| `debug_post_camera_stuff_view` | Same |
| `debug_post_missing_photos_exif_view` | Same |
| `new_posts_dynamic_view` | Same |
| `photos_json_generator` | Same |

### Step 3: Migrate Config-Using Views

Views using `data_manager["key"]` for page metadata:

| View | Change |
|------|--------|
| `summary_view` | Use `context.page_meta("summary")` |
| `towns_history_view` | Use `context.page_meta("towns_history")` |
| `towns_timeline_view` | Use `context.page_meta("towns_timeline")` |
| `timeline_photo_view` | Use `context.page_meta("timeline")` |
| `map_view` | Use `context.page_meta("map")` |
| `pois_view` | Use `context.page_meta("pois")` |
| `lands_index_view` | Use `context.page_meta("lands")` |
| `towns_index_view` | Use `context.page_meta("towns")` |

### Step 4: Migrate Entity-Using Views

Views using entity arrays:

| View | Needs |
|------|-------|
| `payload_json_generator` | `context.towns`, `context.voivodeships`, `context.tags`, `context.lands` |
| `train_stations_json_generator` | `context.train_stations` (add to context) |
| `ideas_json_generator` | `context.ideas` (add to context) |
| `portfolio_view` | `context.portfolios` (add to context) |

### Step 5: Migrate EXIF-Using Views

Views using exif_db:

| View | Needs |
|------|-------|
| `exif_stats_view` | `context.exif_db` |
| `debug_tag_stats_view` | `context.exif_db` |
| `timeline_photo_view` | `context.exif_db` |
| Gallery `abstract_view` | `context.exif_db` |

### Defer to Next Iteration

| View | Reason |
|------|--------|
| `markdown_page_view` | Needs `pages_path`, `markdown_wrapper` |
| `more_view` | Needs `pages_path`, `data_path` |
| `article_view` | Critical path, needs careful testing |
| SVG map views | Low priority, Leaflet focus |
| Gallery inheritance chain | Complex, do after `abstract_view` |

## Notes

- Gallery views use inheritance - migrate `abstract_view` first, others follow
- Post list views already decoupled (receive entity in constructor)
- Remove `context.config` and `context[]` access after migration
- Services decoupling is separate work (see PLAN.md)
