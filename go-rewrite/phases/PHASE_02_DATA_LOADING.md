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
- Single dependency graph connecting everything (Phase 1)
- Automatic staleness detection (file hashes / mtimes)
- Lazy regeneration — only recompute what's stale
- Parallel execution of independent nodes

## Data Layers

```
┌─────────────────────────────────────────────┐
│ LAYER 0: Source files (never generated)     │
│                                             │
│ • data/config/*.yml (hand-edited)           │
│ • data/external/*.yaml (polygon sources)    │
│ • env/{env}/data/posts/**/*.md              │
│ • env/{env}/data/images/**/*.jpg            │
│ • env/{env}/data/routes/*.json (route coords)│
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│ LAYER 1: Generated configs (rarely changes) │
│                                             │
│ • go-rewrite/cache/areas/*.yml              │
│ • go-rewrite/cache/polygons/**/*.json       │
│                                             │
│ Staleness: hash of source external files    │
│ Regen: ~2 min (area matching + simplify)    │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│ LAYER 2: Cached computations                │
│                                             │
│ • Post structs ← depends on *.md files      │
│ • EXIF caches ← depends on source images    │
│ • route_coverage ← posts + polygons         │
│ • area_photos ← photos + polygons           │
│ • route_grid, photo_grid ← coords + EXIF   │
│                                             │
│ Cache dir: env/{env}/cache-go/              │
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
│                                             │
│ Staleness: always recomputed from Layer 2   │
│ Regen: <100ms                               │
└─────────────────────────────────────────────┘
```

## Requirements

### R1: Config Loader

Load all YAML config files into typed Go structs.

**Input files:**
- `data/config/config.yml` — site-level metadata only (see simplification below)
- `data/config/tags.yml` — array of Tag objects (51 tags)
- `data/config/photo_tags.yml` — array of PhotoTag objects (15 photo tags)
- `data/config/route_colors.yml` — map of route type → color/weight/opacity (primary config)
- `data/config/train_stations.yml` — array of TrainStation objects (~200 stations)
- `data/config/transport_pois.yml` — array of TransportPOI objects (merge into train_stations later)
- `data/config/asset_bundles.yml` — bundle definitions (simplified role with templ)

**Not loaded in Go:**
- `data/config/land_types.yml` — removed feature
- `data/config/lands.yml` — removed feature
- `data/config/todo_routes.yml` — trip ideas not in scope
- `data/config/todo_routes_done.yml` — trip ideas not in scope
- `data/config/gpx_rectifier.yml` — old config, replaced by local YAML

**config.yml simplification:**
Crystal's `config.yml` mixes site metadata with page-specific data (titles,
backgrounds, etc.). Go only loads site-level config from this file:
- `site.title`, `site.url`, `site.author`, `site.email`, `site.desc`

Page titles, subtitles, and background images move to templ components (Phase 3).
Each view owns its display metadata — no config file needed for page-level strings.

**asset_bundles.yml with templ:**
With templ components replacing template files, asset bundles are simplified:
- Each templ view declares which CSS/JS files it needs
- No composite bundle resolution chain needed
- Bundle resolver still useful as a lookup table (bundle name → file paths)
- Integrity hashes still needed for external libraries

**transport_pois note:**
Currently a separate file. Plan to merge its data into `train_stations.yml`
in a future cleanup — they share the same domain (transport infrastructure).

**Requirements:**
- All files loaded in parallel (independent of each other)
- Strict validation — fail fast on missing required fields
- Tags must have both `slug` (English) and `slug_pl` (Polish)
- Expose via typed accessor methods, not string map lookups

### R2: Area Loader

Load all area entities from `go-rewrite/cache/areas/*.yml` (or `data/config/areas/*.yml`
during Crystal compatibility phase).

**5 area types, identical YAML format:**
- towns.yml (2,477 records)
- counties.yml (314)
- voivodeships.yml (16)
- meso_regions.yml (~420)
- macro_regions.yml (~20)

**Per area:** slug, name, code, voivodeship (optional), bbox (optional)

**Area slug uniqueness:** Towns can have duplicate names (e.g., Grudziądz has both
"gmina miejska" and "gmina wiejska"). Slugs are disambiguated by appending voivodeship
and type: `grudziadz-kujawsko-pomorskie-miejska`, `grudziadz-kujawsko-pomorskie-wiejska`.
Check Crystal code for the full disambiguation logic when implementing.

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
- tags (→ tag slugs), towns (→ town slugs)
- coords, coords_file, coords_type, distance, time_spent, elevation
- temperature, strava, pois, map_zooms

Note: `lands` field exists in some posts but is not needed in Go (lands feature removed).

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
  - Route files are in `env/{env}/data/routes/`
  - Format: array of route segments, each segment is array of [lat, lon] pairs
- Parse all posts in parallel (each file independent)

### R4: EXIF Cache Loader

Load pre-computed EXIF data from cache files.

**Input:** `env/{env}/cache-go/exif/{post_slug}.yml`

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

### R5: Route Coverage Loader (was Area-Post Association)

Load pre-computed route-area assignments from cache.

**Input:** `env/{env}/cache-go/route_coverage/{post_slug}.yml`

**Per entry:**
- Route type (hike, bicycle, etc.)
- Total distance/time
- Distance breakdown by area type:
  - towns, counties, voivodeships
  - meso_regions, macro_regions
  - mega_regions, subprovinces, provinces
- Each area: slug, name, code, distance_meters/km/percent
- Touched areas lists (areas route enters, any distance):
  - touched_towns, touched_counties, touched_voivodeships
  - touched_meso_regions, touched_macro_regions
  - touched_mega_regions, touched_subprovinces, touched_provinces

**Requirements:**
- Load all association files in parallel
- Merge with Post's manual town slugs from YAML header
- Build reverse index: area → posts
- Handle missing cache files (post without route = no associations)

### R6: Polygon Loader

Load pre-generated GeoJSON polygon files.

**Input:** `go-rewrite/cache/polygons/{type}/{slug}.json`
**Count:** 1,630 files

**Requirements:**
- Load lazily or on demand (not all polygons needed for every build)
- For area show pages: load specific polygon as raw JSON string
- For area matching: load as parsed GeoJSON (if reimplementing matching)
- Cache loaded polygons in memory

### R7: Grid Data Loader

Load pre-computed grid data (route and photo spatial indexes).

**Input:**
- `env/{env}/cache-go/route_grid.yml` — route → grid cells + related posts
- `env/{env}/cache-go/photo_grid.yml` — photo → grid cells + nearest town

**Requirements:**
- Used by map views and photo planner
- Simple YAML load into structs

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

**NavStats — computed in memory (no cache file):**
- bicycle_distance, bicycle_time_length, bicycle_count
- hike_distance, hike_time_length, hike_count
- total self_distance, self_time_length

Computed from loaded posts during SiteData construction. Crystal cached this
to `nav_stats.yml` but Go computes it fresh — it's cheap (<100ms) and
avoids an extra cache file.

**Route colors — primary config (not derived):**
Loaded from `data/config/route_colors.yml` and exposed via SiteData.
Not a computed value — it's hand-edited primary configuration.

**Requirements:**
- Built after all data loaded
- Immutable after construction (no setters, no mutation)
- All lookups are O(1) map access
- Expose as interfaces for easy mocking in tests

## What to Validate (Phase 2 Acceptance)

Run loader, print summary, compare with Crystal:

```
Posts:           6 loaded (6 published, 0 drafts)
Tags:           51 loaded (6 is_nav)
Photo Tags:     15 loaded
Areas:          3,247 loaded (2,477 towns + 314 counties + ...)
EXIF entries:   120 loaded across 6 posts
Photos:         210 referenced in posts (120 with EXIF)
Route coverage: 18 associations loaded
Nav Stats:      bicycle=165km, hike=17km (computed, not cached)
Route colors:   loaded from config (primary data)
Indexes:        postsByArea=42 entries, postsByTag=12 entries, ...
Pipeline:       8 nodes, 3 stale, 5 up-to-date
Time:           247ms (posts: 45ms, configs: 12ms, exif: 89ms, index: 101ms)
```

## Files to Create

```
go-rewrite/
├── cmd/odkrywajac/main.go       — CLI entry point
├── internal/
│   ├── model/
│   │   ├── post.go              — Post struct
│   │   ├── area.go              — Area + AreaType (with Polish inflections)
│   │   ├── photo.go             — Photo + EXIF data
│   │   ├── tag.go               — Tag + PhotoTag
│   │   ├── config.go            — SiteConfig (site-level only)
│   │   ├── route.go             — Route coordinates
│   │   └── poi.go               — TrainStation, TransportPOI
│   ├── loader/
│   │   ├── config.go            — Config YAML loader (site-level fields only)
│   │   ├── areas.go             — Area YAML loader
│   │   ├── posts.go             — Post markdown parser
│   │   ├── exif.go              — EXIF cache loader
│   │   ├── route_coverage.go    — Route-area association loader
│   │   ├── polygons.go          — Polygon JSON loader (lazy)
│   │   └── grids.go             — Route grid + photo grid loader
│   ├── pipeline/
│   │   └── ...                  — (from Phase 1)
│   └── index/
│       ├── site_data.go         — SiteData builder (includes nav_stats computation)
│       └── photo_index.go       — Photo spatial/EXIF index
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

- [ ] Markdown parsing: use goldmark or custom parser?
      Posts use custom `{% photo %}` syntax that needs preprocessing before
      markdown parsing.
      **Recommendation:** Preprocess custom tags first (regex), then goldmark.

- [ ] Should Go read from `go-rewrite/cache/areas/` or `data/config/areas/`?
      **Recommendation:** Start with `data/config/areas/` for Crystal compatibility.
      Switch to `go-rewrite/cache/areas/` when Go generates its own area configs.
