# Phase 2: Data Loading & Struct Definitions

**Status: COMPLETE**

## Goal

Build typed Go structs for all data and implement loaders that parse
YAML/markdown/JSON into those structs. This is the foundation for rendering.

## Key Decisions Made

- **EXIF**: Read directly from JPEG files using `dsoprea/go-exif/v3` (tolerant
  of malformed tags, handles Olympus files that fail with goexif). Generate
  our own cache at `env/{env}/cache-go/exif/`.
- **Markdown**: Use goldmark with custom AST extension for `{% photo %}`,
  `{% photo_header %}`, `{% post_url %}` — proper block/inline parsers,
  not regex. Same extension reusable for HTML rendering in Phase 3.
- **Areas**: Load from `data/config/areas/` (Crystal-compatible format).
- **Naming**: `*Slugs` suffix for `[]string` arrays of slugs, no suffix for
  `[]*Model` arrays. Lookup methods use 2 params `(areaType, slug)` not
  composite key strings.

## What Was Implemented

### Step 1: Model Structs (`internal/model/`)

| File | Types | Notes |
|------|-------|-------|
| `tag.go` | `Tag`, `PhotoTag` | YAML-tagged for direct unmarshaling |
| `area.go` | `AreaType` (enum), `Area`, `BBox` | Polish inflections (nominative/genitive), `ParseAreaType()`, `AreaMapKey()` for internal indexing |
| `post.go` | `Post`, `PhotoRef` | `TagSlugs`, `TownSlugs`, `LandSlugs`, `CrossRefSlugs` (slug arrays), `Photos` (model array) |
| `photo.go` | `PhotoEntity`, `ExifData` | Extended EXIF fields: Make, WhiteBalance, MeteringMode, Flash, Orientation, ColorSpace, Software |
| `route.go` | `Route`, `LatLon`, `CoordRange` | Segments-based routes, CoordRange with Contains/Center/Merge |
| `config.go` | `SiteConfig`, `RouteColor` | Site-level metadata only (page config deferred to templ) |
| `poi.go` | `TrainStation`, `TransportPOI` | `PoznanTimeDistance()` helper |

### Step 2: Config Loaders (`internal/loader/config.go`)

- `LoadSiteConfig` — parses `config.yml` dot-notation (`site.title`, etc.)
- `LoadTags`, `LoadPhotoTags` — simple YAML array unmarshaling
- `LoadRouteColors` — YAML map unmarshaling
- `LoadTrainStations`, `LoadTransportPOIs` — YAML array unmarshaling
- `LoadAllConfigs` — loads all 6 config files in parallel via goroutines

### Step 3: Area Loader (`internal/loader/areas.go`)

- `LoadAreas` — loads all 5 YAML files in parallel, sets `Type` on each area
- Returns combined sorted slice (by type then slug)
- Loads from `data/config/areas/` (Crystal-compatible path)

### Step 4: Goldmark Markdown Extension (`internal/markdown/extension.go`)

Custom goldmark extension with proper AST nodes and parsers:

- **Block parser** for `{% photo "filename","caption","tags" %}` and
  `{% photo_header "caption","tags" %}` — triggered by `{` at line start
- **Inline parser** for `{% post_url slug %}` — triggered by `{` within text
- **AST nodes**: `PhotoNode`, `PhotoHeaderNode`, `PostURLNode`
- **Extraction**: `Extract(doc)` walks AST and returns `ExtractedData`
  (photos, header photo, cross-ref slugs)
- Tag parsing: `"tag:good,tag:best"` → `["good", "best"]`

### Step 5: Post Loader (`internal/loader/posts.go`)

- `LoadPosts` — walks directory recursively, parses all `.md` files in parallel
- Front matter parsing with `yaml.Unmarshal` (handles optional fields, commented-out dates)
- `yamlStrava` custom unmarshaler — handles int, string, or `[]string` strava field
- Slug extraction from filename: `2021-07-18-slug.md` → `"slug"`
- URL construction: `/2021/07/18-slug.html`
- Route JSON loading: `[[[lat, lon], ...]]` format
- Posts sorted by date descending

### Step 6: EXIF Reader (`internal/exif/reader.go`)

Uses `dsoprea/go-exif/v3` via `SearchFileAndExtractExif` + `GetFlatExifDataUniversalSearch`:

- Flat tag enumeration indexed into `map[tagKey]ExifTag` for O(1) lookup
- GPS: DMS rational → decimal degrees conversion with N/S/E/W reference
- Full field extraction: focal length, aperture, exposure, ISO, dimensions,
  camera, lens, time, orientation, white balance, metering, flash, color space
- Tolerant of malformed EXIF — processes whatever tags are available
- **Comparison test**: 25,538/25,641 images read successfully (99.6%),
  0 mismatches on camera/GPS/ISO. Lens mismatches only on Pentax (no LensModel
  tag — Crystal uses a lens ID database).

### Step 7: EXIF Cache (`internal/exif/cache.go`)

- Per-post YAML cache files at `{cacheDir}/exif/{post_slug}.yml`
- `IsStale` — compares cache mtime vs source image mtimes
- `Generate` — reads EXIF from all post JPEGs, writes cache
- `LoadOrGenerate` — loads from cache if fresh, regenerates otherwise
- Cache format uses `---` header for Crystal compatibility

### Step 8: SiteData Builder (`internal/index/site_data.go`)

- `BuildSiteData()` — constructs all lookup indexes
- **Internal maps** (private): `postsByTagSlug`, `postsByArea`, `areaByKey`
- **Public lookup methods**: `PostsForTag(tagSlug)`, `FindArea(areaType, slug)`,
  `PostsForArea(areaType, slug)`, `FindAreaByTypeSlug(typeStr, slug)`
- **Exported maps**: `PostsByYear`, `AreasByType`, `AreasWithPosts`, `TagBySlug`, `PhotoTagBySlug`
- NavStats computed from finished posts (bicycle/hike distance, time, count)

### Step 9: CLI Integration (`cmd/odkrywajac/main.go`)

`build` command loads all data and prints summary:

```
Posts: 6 loaded
Tags: 28 loaded (10 is_nav)
Photo Tags: 33 loaded
Areas: 3276 loaded
NavStats: bicycle=139km, hike=17km
Total: 28ms
```

## Files Created

```
go-rewrite/internal/
├── model/
│   ├── tag.go
│   ├── area.go          + area_test.go
│   ├── post.go          + post_test.go
│   ├── photo.go
│   ├── route.go
│   ├── config.go
│   └── poi.go
├── markdown/
│   └── extension.go     + extension_test.go
├── loader/
│   ├── config.go        + config_test.go
│   ├── areas.go         + areas_test.go
│   └── posts.go         + posts_test.go
├── exif/
│   ├── reader.go        + reader_test.go
│   ├── cache.go         + cache_test.go
│   └── compare_test.go  (Crystal comparison)
└── index/
    └── site_data.go     + site_data_test.go
```

**Modified:** `cmd/odkrywajac/main.go` (wired up loaders)

## Dependencies Added

- `gopkg.in/yaml.v3` — YAML parsing
- `github.com/yuin/goldmark` — Markdown parser (with custom extension)
- `github.com/dsoprea/go-exif/v3` — EXIF reader (tolerant of malformed tags)
- `github.com/dsoprea/go-jpeg-image-structure/v2` — JPEG structure parser

## Test Results

```
ok  odkrywajac/internal/model       — 11 tests (area types, bbox, post URL)
ok  odkrywajac/internal/markdown    — 7 tests (photo, header, post_url, args)
ok  odkrywajac/internal/loader      — 15 tests (configs, areas, posts, routes)
ok  odkrywajac/internal/exif        — 7 tests (reader, cache, format, comparison)
ok  odkrywajac/internal/index       — 9 tests (indexes, lookups, nav stats)
ok  odkrywajac/internal/pipeline    — (Phase 1, cached)
```

EXIF comparison (full env, 25,641 images):
- Go read OK: 25,538 (99.6%), 38 failures (corrupt/non-standard JPEG)
- Camera match: 25,529 (99.96%)
- GPS match: 24,111 (100% of available)
- ISO match: 25,529 (100%)
- Lens: 19,802 matches (Pentax images lack LensModel EXIF tag)

## What's Deferred

- **Route Coverage (R5)**: ~~Pipeline nodes for area-route intersection computation~~ **DONE** — implemented in `internal/spatial/` using GEOS (twpayne/go-geos). Pipeline node `spatialMatching` generates `areas_for_post/*.yml` with route→area distances. Output matches Crystal format (same slugs, distances, percentages). Go has 5 area types vs Crystal's 8 (missing mega_regions, subprovinces, provinces).
- **Area Photos**: ~~Photo→area assignment~~ **DONE** — same `spatialMatching` pipeline node generates `photos_in_area/{type}/{slug}.yml` using GEOS point-in-polygon. Processes AllPhotos (not just published).
- **Grid Data (R7)**: Spatial grid computation for maps and photo planner
- **Polygon Loader (R6)**: Simple file read — implement when area show views need it
- **Photo Index**: Camera/lens/ISO grouping indexes — implement when gallery views need it
- **Asset Bundles**: Simplified with templ — implement in Phase 3
- **Pentax Lens IDs**: Crystal has a lens ID→name database. Go reads raw EXIF only.
  Could add lens database if needed, but affects <5% of images.
