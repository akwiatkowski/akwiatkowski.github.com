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
