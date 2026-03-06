# Phase 2: Data Loading & Struct Definitions

## Goal

Build typed Go structs for all data and implement loaders that parse
YAML/markdown/JSON into those structs. This phase consumes the pipeline
outputs from Phase 1 and produces the in-memory SiteData used by views.

Phase 1 handles *when* and *whether* to regenerate derived data.
This phase handles *how* to parse and structure that data in memory.

## Key Difference from Crystal

Crystal has:
- 5 separate command executables for preprocessing
- 7 task registry entries for per-build data prep
- Manual running of commands when data changes
- Implicit cache invalidation (or none — full rebuild)

Go will have:
- Single dependency graph connecting everything
- Automatic staleness detection (file hashes / mtimes)
- Lazy regeneration — only recompute what's stale
- Parallel execution of independent nodes

## Dependency Graph Design

```
┌─────────────────────────────────────────────┐
│ LAYER 0: Source files (never generated)     │
│                                             │
│ • data/config/*.yml (hand-edited)           │
│ • data/external/*.yaml (polygon sources)    │
│ • env/{env}/data/posts/**/*.md              │
│ • env/{env}/data/images/**/*.jpg            │
│ • env/{env}/data/json/*.json (route coords) │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│ LAYER 1: Derived configs (rarely changes)   │
│                                             │
│ • areas/*.yml ← depends on external/*.yaml  │
│ • polygons/**/*.json ← depends on external  │
│                                             │
│ Staleness: hash of source external files    │
│ Regen: ~2 min (area matching + simplify)    │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│ LAYER 2: Post-dependent data                │
│                                             │
│ • Post structs ← depends on *.md files      │
│ • EXIF caches ← depends on source images    │
│ • areas_for_post cache ← posts + polygons   │
│ • photos_in_area cache ← photos + polygons  │
│                                             │
│ Staleness: per-file mtime comparison        │
│ Regen: seconds (per changed post)           │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│ LAYER 3: Computed indexes (always in memory)│
│                                             │
│ • SiteData indexes (postsByArea, etc.)      │
│ • PhotoIndex (spatial, EXIF grouping)       │
│ • NavStats (aggregated statistics)          │
│ • CoordQuant (quantized route/photo coords) │
│                                             │
│ Staleness: always recomputed from Layer 2   │
│ Regen: <100ms                               │
└─────────────────────────────────────────────┘
```

## Requirements

### R1: Config Loader

Load all YAML config files into typed Go structs.

**Input files:**
- `data/config/config.yml` — key-value site metadata
- `data/config/tags.yml` — array of Tag objects
- `data/config/photo_tags.yml` — array of PhotoTag objects
- `data/config/land_types.yml` — array of LandType objects
- `data/config/lands.yml` — array of Land objects
- `data/config/route_colors.yml` — map of route type → color/weight/opacity
- `data/config/train_stations.yml` — array of TrainStation objects
- `data/config/transport_pois.yml` — array of TransportPOI objects
- `data/config/todo_routes.yml` — array of TodoRoute objects
- `data/config/asset_bundles.yml` — bundle definitions + composites

**Requirements:**
- All files loaded in parallel (independent of each other)
- Strict validation — fail fast on missing required fields
- config.yml is key-value (dotted keys like `site.title`), not nested struct
- Tags must have both `slug` (English) and `slug_pl` (Polish)
- Expose via typed accessor methods, not string map lookups

### R2: Area Loader

Load all area entities from `data/config/areas/*.yml`.

**5 area types, identical YAML format:**
- towns.yml (2,477 records)
- counties.yml (314)
- voivodeships.yml (16)
- meso_regions.yml (~420)
- macro_regions.yml (~20)

**Per area:** slug, name, code, voivodeship (optional), bbox (optional)

**Requirements:**
- Load all 5 files in parallel
- Build lookup indexes:
  - `areasBySlug[type:slug]` → Area
  - `areasByType[type]` → []Area (sorted by slug)
  - `areasByVoivodeship[voivSlug]` → []Area
- BBox struct with `Contains(lat, lon)` method
- AreaType with Polish inflections (nominative/genitive)

### R3: Post Parser

Parse markdown posts with YAML front matter.

**Input:** `env/{env}/data/posts/{year}/*.md`

**YAML header fields (all optional except title, date):**
- title, subtitle, desc, keywords, date, finished_at
- author, categories, image_filename, image_position
- tags (→ tag slugs), towns (→ town slugs), lands (→ land slugs)
- coords, coords_file, coords_type, distance, time_spent, elevation
- temperature, strava, pois, map_zooms

**Body content:**
- Standard markdown
- `{% photo "filename.jpg","Caption" %}` — photo references
- `{% photo "filename.jpg","Caption","tag:good,tag:best" %}` — with photo tags
- `{% photo_header "Caption","tag:summer" %}` — header photo with tags
- `{% post_url 2021-06-03-slug %}` — cross-references to other posts
- `[wiki-link]: https://...` — reference-style links

**Requirements:**
- Parse YAML front matter (split on `---`)
- Extract photo references from body (regex: `{% photo "..." %}`)
- Extract photo_header from body
- Extract post_url cross-references
- Build slug from filename (strip date prefix and .md)
- Build URL from date: `/{year}/{month}/{day}-{slug}.html`
- Determine published status: `finished_at != nil`
- Load route coordinates from coords_file JSON if specified
- Parse all posts in parallel (each file independent)

### R4: EXIF Cache Loader

Load pre-computed EXIF data from cache files.

**Input:** `env/{env}/cache/exifs/{post_slug}.yml`

**Per photo entry:**
- image_filename, post_slug
- lat, lon, altitude (optional — not all photos have GPS)
- focal_length, focal_length_35, crop
- aperture, exposure, exposure_string
- focus_distance, iso, width, height
- lens, camera, time

**Requirements:**
- Load all EXIF files in parallel
- Match EXIF entries to Post photo references by filename
- Build PhotoEntity structs with merged data (post reference + EXIF)
- Handle missing EXIF gracefully (photo exists but no EXIF entry)

### R5: Area-Post Association Loader

Load pre-computed area assignments from cache.

**Input:** `env/{env}/cache/areas_for_post/{post_slug}.yml`

**Per entry:**
- Route type (hike, bicycle, etc.)
- Distance breakdown by area type (towns, counties, voivodeships, regions)
- Each area: slug, name, code, distance_meters/km/percent

**Requirements:**
- Load all association files in parallel
- Merge with Post's manual town/land slugs from YAML header
- Build reverse index: area → posts
- Handle missing cache files (post without route = no associations)

### R6: Polygon Loader

Load pre-generated GeoJSON polygon files.

**Input:** `data/config/polygons/{type}/{slug}.json`
**Count:** 1,630 files

**Requirements:**
- Load lazily or on demand (not all polygons needed for every build)
- For area show pages: load specific polygon as raw JSON string
- For area matching: load as parsed GeoJSON (if reimplementing matching)
- Cache loaded polygons in memory

### R7: Dependency Graph Runner

The core innovation — a DAG-based pipeline that replaces Crystal's
separate commands and implicit caching.

**Node types:**
```
FileSource     — watches file(s) for changes, no computation
DerivedData    — reads inputs, produces output, cached on disk
ComputedIndex  — reads inputs, produces in-memory structure, always recomputed
```

**Graph definition:**
```
configs       = FileSource(data/config/*.yml)
externals     = FileSource(data/external/*.yaml)
postFiles     = FileSource(env/{env}/data/posts/**/*.md)
imageFiles    = FileSource(env/{env}/data/images/**/*.jpg)

areaConfigs   = DerivedData(externals → areas/*.yml)        # Layer 1
polygonJsons  = DerivedData(externals → polygons/**/*.json) # Layer 1

posts         = ComputedIndex(postFiles, configs)            # Layer 2
exifCaches    = DerivedData(imageFiles → exifs/*.yml)        # Layer 2
areaForPost   = DerivedData(posts, polygonJsons → cache)     # Layer 2
photosInArea  = DerivedData(posts, exifCaches, polygonJsons) # Layer 2

siteData      = ComputedIndex(posts, areaConfigs, exifCaches, # Layer 3
                              areaForPost, photosInArea, configs)
```

**Staleness check:**
- FileSource: mtime of files
- DerivedData: max(input mtimes) > output mtime
- ComputedIndex: always recompute (cheap, in-memory)

**Execution:**
- Walk graph from leaves to root
- Execute stale nodes in topological order
- Parallelize independent branches
- Report: "Skipping areaConfigs (up to date)" / "Regenerating exifCaches (3 posts changed)"

**Requirements:**
- Define graph declaratively (not procedural)
- Each node has: name, inputs, outputs, stale?(), run()
- Runner resolves execution order from graph
- Parallel execution of independent nodes
- Dry-run mode: show what would execute without running
- Verbose mode: show timing per node

### R8: SiteData Builder

Combine all loaded data into a single immutable SiteData struct.

**Indexes to build:**
- `postsByArea[type:slug]` → []Post (sorted by date desc)
- `postsByTag[slug]` → []Post
- `postsByYear[year]` → []Post
- `areasBySlug[type:slug]` → Area
- `areasWithPosts[type]` → []Area (only areas that have ≥1 post)
- `tagBySlug[slug]` → Tag
- `photosByArea[type:slug]` → []Photo
- `photosByCamera[model]` → []Photo
- `photosByLens[model]` → []Photo
- `photosByISO[iso]` → []Photo

**NavStats to compute:**
- bicycle_distance, bicycle_time_length, bicycle_count
- hike_distance, hike_time_length, hike_count
- total self_distance, self_time_length

**Requirements:**
- Built after all data loaded
- Immutable after construction (no setters, no mutation)
- All lookups are O(1) map access
- Expose as interfaces for easy mocking in tests

## What to Validate (Phase 1 Acceptance)

Run loader, print summary, compare with Crystal:

```
Posts:           6 loaded (6 published, 0 drafts)
Tags:           51 loaded (6 is_nav)
Photo Tags:     15 loaded
Areas:          3,247 loaded (2,477 towns + 314 counties + ...)
EXIF entries:   120 loaded across 6 posts
Photos:         210 referenced in posts (120 with EXIF)
Area-post:      18 associations loaded
Nav Stats:      bicycle=165km, hike=17km
Indexes:        postsByArea=42 entries, postsByTag=12 entries, ...
Pipeline:       7 nodes, 3 stale, 4 up-to-date
Time:           247ms (posts: 45ms, configs: 12ms, exif: 89ms, index: 101ms)
```

## Files to Create

```
go-rewrite/
├── cmd/odkrywajac/main.go       — CLI entry point
├── internal/
│   ├── model/
│   │   ├── post.go              — Post struct
│   │   ├── area.go              — Area + AreaType
│   │   ├── photo.go             — Photo + EXIF data
│   │   ├── tag.go               — Tag + PhotoTag
│   │   ├── config.go            — SiteConfig
│   │   ├── route.go             — Route coordinates
│   │   └── poi.go               — POI, TrainStation, TodoRoute
│   ├── loader/
│   │   ├── config.go            — Config YAML loader
│   │   ├── areas.go             — Area YAML loader
│   │   ├── posts.go             — Post markdown parser
│   │   ├── exif.go              — EXIF cache loader
│   │   ├── associations.go      — Area-post cache loader
│   │   └── polygons.go          — Polygon JSON loader
│   ├── pipeline/
│   │   ├── graph.go             — Dependency graph definition
│   │   ├── node.go              — Node interface + types
│   │   ├── runner.go            — Graph executor (parallel)
│   │   └── staleness.go         — Mtime/hash checking
│   └── index/
│       ├── site_data.go         — SiteData builder
│       ├── photo_index.go       — Photo spatial/EXIF index
│       └── nav_stats.go         — Computed statistics
├── go.mod
└── go.sum
```

## Open Questions

- [ ] Should we reimplement area matching (needs GEOS or pure-Go geo library)?
      Or keep using Crystal's precomputed cache files?
      **Recommendation:** Use cache files for now, reimplement later if needed.

- [ ] Should polygon loading be eager or lazy?
      **Recommendation:** Lazy — only ~120 polygons needed for area show pages
      in dev mode, not all 1,630.

- [ ] markdown parsing: use goldmark or custom parser?
      Posts use custom `{% photo %}` syntax that needs preprocessing before
      markdown parsing.
      **Recommendation:** Preprocess custom tags first (regex), then goldmark.
