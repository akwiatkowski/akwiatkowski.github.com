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
    ├── entity_views.cr  #   Priority 10-19: towns, tags, voivodeships, lands
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
├── base_view.cr         # BaseView - all views inherit from this
├── page_view.cr         # PageView - HTML page wrapper
├── post_list_view/      # Entity collection pages (towns, tags, etc.)
├── dynamic_view/        # Data-heavy pages (stats, reports)
├── static_view/         # JS-heavy pages (map, timeline)
├── gallery_view/        # Photo galleries
├── special_view/        # RSS, Atom, JSON generators
├── photo_map/           # SVG map views
└── model_view/          # Index pages
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

### Running Tests

```bash
crystal spec                    # Run all tests
crystal spec spec/views/        # Run view tests only
```

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
- 2026-02-03: Major view decoupling - 39 views migrated from @blog to context: RenderContext

---

*Current stats: 6 tasks + 35 views = 41 registry entries, 146 tests*
