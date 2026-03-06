# Data Sources & Preprocessing Pipeline

Complete inventory of all data consumed by the blog engine,
how it's generated, and how often it changes.

## Go Directory Structure

```
# SHARED (Crystal + Go read from here, unchanged)
data/
├── config/                     # primary config
│   ├── config.yml              # site-level metadata (shrink for Go — see notes)
│   ├── tags.yml                # 51 post tags
│   ├── photo_tags.yml          # 15 photo tags
│   ├── route_colors.yml        # map route colors (PRIMARY CONFIG, not cache)
│   ├── train_stations.yml      # ~200 stations (transport_pois merged later)
│   ├── transport_pois.yml      # transport POIs → merge into train_stations later
│   ├── asset_bundles.yml       # CSS/JS bundles → simplify with templ
│   ├── areas/                  # GENERATED from external (Crystal needs here)
│   └── polygons/               # GENERATED from external (Crystal needs here)
├── external/                   # polygon sources (~90MB, primary)
├── assets/                     # CSS/JS/fonts (shared)
└── pages/                      # static markdown → convert to templ in Go

# GO PROJECT
go-rewrite/
├── cache/                      # Go's generated data (from external)
│   ├── areas/                  # area configs (bbox only)
│   └── polygons/               # GeoJSON polygon files
├── internal/                   # Go source code
│   └── templates/              # templ components (replaces data/layout/)
└── phases/                     # planning docs

# PER-ENVIRONMENT
env/{env}/
├── data/
│   ├── posts/{year}/*.md       # primary: blog posts
│   ├── images/{year}/{slug}/   # primary: source photos
│   └── routes/*.json           # primary: route coordinates (from GPX rectifier)
├── cache-go/                   # Go's per-env caches
│   ├── exif/{slug}.yml         # EXIF metadata per post
│   ├── route_coverage/{slug}.yml    # distance/time per area per post
│   ├── area_photos/{type}/{slug}.yml # photos per area
│   ├── route_grid.yml          # route → grid cells + related posts
│   ├── photo_grid.yml          # photo → grid cells + nearest town
│   ├── photo_hashes/{slug}.yml # perceptual hashes (optional)
│   └── build_manifest.json     # SHA256 per output file (for FTP sync)
└── public/
    ├── local/                  # Crystal output
    └── go/                     # Go output
```

## Data Classification

### Primary Data (hand-edited, source of truth)

| Data | Location | Changes When |
|------|----------|--------------|
| Blog posts | `env/{env}/data/posts/{year}/*.md` | Author writes/edits |
| Source photos | `env/{env}/data/images/{year}/{slug}/*.jpg` | Author adds photos |
| Route coords | `env/{env}/data/routes/*.json` | GPX rectifier output |
| Polygon sources | `data/external/*.yaml` (~90MB) | Rarely (GIS data update) |
| Tags | `data/config/tags.yml` | Author edits |
| Photo tags | `data/config/photo_tags.yml` | Author edits |
| Route colors | `data/config/route_colors.yml` | Developer changes map colors |
| Train stations | `data/config/train_stations.yml` | Rarely |
| Transport POIs | `data/config/transport_pois.yml` | Rarely (merge into train_stations later) |
| Site config | `data/config/config.yml` | Developer changes site metadata |
| CSS/JS assets | `data/assets/**/*` | Developer changes frontend |

### Generated Data (derived from external, expensive, cached)

Stored in `go-rewrite/cache/` (Go) or `data/config/areas/` + `data/config/polygons/` (Crystal).

| Data | Source | Generator | Output |
|------|--------|-----------|--------|
| Area configs | `data/external/*.yaml` | area generator | `areas/{type}.yml` (5 files, bbox only) |
| Polygon GeoJSON | `data/external/*.yaml` | polygon simplifier | `polygons/{type}/{slug}.json` (1,630 files) |

**Area slug uniqueness:** Towns can have duplicate names (e.g., Grudziądz has both
"gmina miejska" and "gmina wiejska"). Slugs are disambiguated by appending voivodeship
and type: `grudziadz-kujawsko-pomorskie-miejska`, `grudziadz-kujawsko-pomorskie-wiejska`.
Check Crystal code for the full disambiguation logic when implementing.

### Cached Data (expensive to compute, persisted per-environment)

Stored in `env/{env}/cache-go/`.

| Cache | Old name | New name | What it stores | Time |
|-------|----------|----------|---------------|------|
| Route coverage | `areas_for_post/` | `route_coverage/` | Per-post: km/time breakdown by area (towns, counties, voivodeships, meso/macro regions, provinces, subprovinces, mega regions) + touched areas list | ~3 min full |
| Area photos | `photos_in_area/` | `area_photos/` | Per-area: list of photos taken within polygon. A photo can belong to multiple areas (border overlap). | ~2 min full |
| EXIF metadata | `exifs/` | `exif/` | Per-post: extracted JPEG metadata (GPS, lens, camera, etc.) | Cached, expensive for 14K+ photos |
| Route grid | `post_coord_quant.yml` | `route_grid.yml` | Route → quantized grid cells + related posts (spatial overlap) | Cached |
| Photo grid | `photo_coord_quant.yml` | `photo_grid.yml` | Photo → grid cells + closest town info | Cached |
| Photo hashes | `photo_analysis/` | `photo_hashes/` | Perceptual hashes (pHash, color) — optional | Cached |
| Build manifest | `mod_watcher.yml` | `build_manifest.json` | SHA256 per output file (replaces mod_watcher, enables FTP sync) | Updated every build |

### Computed in Memory (no cache file needed)

| Data | What | Notes |
|------|------|-------|
| Nav stats | bicycle/hike distance, time, count | Computed from posts every build, no file |
| Route colors | Map colors per transport type | **Primary config** loaded from `route_colors.yml`, not cache |

### Not Needed in Go

| File | Reason |
|------|--------|
| `data/config/land_types.yml` | Removed feature |
| `data/config/lands.yml` | Removed feature |
| `data/config/todo_routes.yml` | Trip ideas not in scope |
| `data/config/todo_routes_done.yml` | Trip ideas not in scope |
| `data/config/towns/` | Legacy directory, replaced by `data/config/areas/` |
| `data/config/gpx_rectifier.yml` | Old config, replaced by new local YAML approach |
| `env/{env}/cache/nav_stats.yml` | Computed in memory instead |
| `env/{env}/cache/mod_watcher.yml` | Replaced by build manifest |

## config.yml Simplification

Crystal's `config.yml` mixes site metadata with page titles/backgrounds.
Go splits this:

**Keep in config (site-level):**
- `site.title`, `site.url`, `site.author`, `site.email`, `site.desc`

**Move to templ components (page-specific):**
- Page titles (`map.title`, `about.title`, `towns.title`, etc.)
- Page subtitles
- Page background images

**Rationale:** With templ partials, each view owns its title and metadata.
No need for a config file to store page-level strings for a single-language site.

## asset_bundles.yml with templ

With templ components replacing template files, asset bundles are simplified:
- Each templ view declares which CSS/JS files it needs
- No composite bundle resolution chain
- Bundle resolver still useful as a lookup table (bundle name → file paths)
- Integrity hashes still needed for external libraries

## Static Pages

Crystal renders `data/pages/about.md`, `en.md`, `todo_notes.md` as pages.
Go converts these to templ components — the content is stable Polish text that
doesn't change often enough to justify a markdown file.

## Data Dependency Graph

```
EXTERNAL / RARELY CHANGES
│
├─ data/external/*.yaml (polygons, ~80MB total)
│   │
│   ├──[area generator]────→ go-rewrite/cache/areas/*.yml (bbox only)
│   ├──[polygon simplifier]→ go-rewrite/cache/polygons/**/*.json (1,630 files)
│   └──[area matcher]──────→ env/*/cache-go/area_photos/**/*.yml
│
├─ data/config/*.yml (hand-edited primary configs)
│   ├── config.yml          — site metadata (title, url, author only in Go)
│   ├── tags.yml             — 51 tags (slug, slug_pl, name, is_nav)
│   ├── photo_tags.yml       — 15 photo tags (slug, title, points)
│   ├── route_colors.yml     — PRIMARY CONFIG: route colors for maps
│   ├── train_stations.yml   — ~200 stations (transport_pois merged later)
│   └── transport_pois.yml   — transport POIs → merge into train_stations later
│
CHANGES PER POST EDIT
│
├─ env/{env}/data/posts/{year}/*.md (markdown with YAML front matter)
│   │  Dev: 6 posts, Full: 726 posts
│   │
│   └──[post parser]──→ Post structs in memory
│
├─ env/{env}/data/routes/*.json (route coordinates, from GPX rectifier)
│   │  Array of [lat, lon] coordinate arrays
│   │
│   └──[loaded by post]──→ Post.detailed_routes
│
CHANGES ON PHOTO ADD/EDIT
│
├─ env/{env}/data/images/{year}/{post_slug}/*.jpg (source photos)
│   │
│   ├──[image_resizer]──→ 4 sizes × 2 formats = 8 variants per photo
│   └──[EXIF reader]────→ env/{env}/cache-go/exif/{post_slug}.yml
│
CACHED COMPUTATIONS (env/{env}/cache-go/)
│
├─ exif/{slug}.yml                    — EXIF metadata per post
├─ route_coverage/{slug}.yml          — distance/time per area per post
├─ area_photos/{type}/{slug}.yml      — photos per area
├─ route_grid.yml                     — route → grid cells + related posts
├─ photo_grid.yml                     — photo → grid cells + nearest town
├─ photo_hashes/{slug}.yml            — perceptual hashes (optional)
└─ build_manifest.json                — SHA256 per output file
```

## Post Markdown Format

```yaml
---
layout:          post
title:           "Pagórki przed żniwami"
subtitle:        "wycieczka, której bardzo potrzebowałem"
desc:            "SEO description text"
keywords:        [laskowice pomorskie, grudziądz, motyle]
date:            2021-07-18 19:00:00
finished_at:     2022-02-07 16:00:00    # nil = draft
author:          "Aleksander Kwiatkowski"
categories:      trip
image_filename:  2021_07_18__16_52__7180460.jpg
image_position:  "50% 46%"
tags:            [bicycle, best, main]
towns:           [kujawsko_pomorskie, jezewo, dragacz, grudziadz]
coords:          [{"route": [], "type": "bicycle"}]
coords_file:     "2021-07-18-pagorki-przed-zniwami.json"
coords_type:     "bicycle"
distance:        69        # km
time_spent:      8         # hours
elevation:       424       # meters
temperature:     29        # celsius
strava:          5649609085
pois:
  - lat: 54.45911
    lon: 18.56281
    name: POI name
    type: visited
---

[wiki-link]: https://pl.wikipedia.org/wiki/...

{% photo_header "Caption","tag:summer,tag:timeline" %}

## Heading

Text with [links][wiki-link] and cross-references:
({% post_url 2021-06-03-slug %})

{% photo "filename.jpg","Caption text" %}
{% photo "filename.jpg","Caption","tag:macro,tag:bird" %}
```

### Photo Reference Syntax

```
{% photo "FILENAME","CAPTION" %}
{% photo "FILENAME","CAPTION","TAGS" %}
{% photo_header "CAPTION","TAGS" %}
```

Tags format: `tag:good,tag:best,tag:timeline` (photo_tags slugs)

### Cross-reference Syntax

```
{% post_url 2021-06-03-slug %}  → resolves to post URL
```

## EXIF Cache Format (per post)

```yaml
---
- image_filename: 2018_11_05__09_35__B053778.jpg
  post_slug: 2018-11-05-spacer-na-przedmiescia
  lat: 50.29620833333333
  lon: 16.651277777777775
  altitude: 335.0
  focal_length: 50.0
  focal_length_35: 100.0
  crop: 2.0
  aperture: 4.0
  exposure: 0.01
  exposure_string: "1/100 s"
  focus_distance: 2.47
  iso: 400
  width: 5240
  height: 3912
  lens: "OLYMPUS M.12-100mm F4.0"
  camera: "E-M1MarkII"
  time: 2018-11-05 09:35:54.000000000+01:00
```

Not all fields are present for every photo — only those with EXIF data.
Photos without GPS have no lat/lon fields.

## Route Coverage Cache Format (was areas_for_post)

Per-post breakdown of distance/time across all area types.
Also includes `touched_` lists (areas the route physically enters, even briefly).

```yaml
---
- type: bicycle
  total_distance_meters: 62652.74
  total_distance_km: 62.653
  points_count: 171.0
  towns:
  - slug: grudziadz-kujawsko-pomorskie-miejska  # disambiguated slug
    name: Grudziądz
    code: "0462011"
    distance_meters: 6664.21
    distance_km: 6.664
    distance_percent: 10.6367
  - slug: grudziadz-kujawsko-pomorskie-wiejska   # same name, different type
    name: Grudziądz
    code: "0406012"
    distance_meters: 3931.48
    distance_km: 3.931
    distance_percent: 6.275
  counties:
  - slug: grudziadzki
    ...
  voivodeships:
  - slug: kujawsko-pomorskie
    ...
  meso_regions:
  - slug: pojezierze_chelminskie
    ...
  macro_regions:
  - slug: pojezierze_chelminsko-dobrzynskie
    ...
  mega_regions: [...]
  subprovinces: [...]
  provinces: [...]
  touched_towns: [...]         # areas route enters (any distance)
  touched_counties: [...]
  touched_voivodeships: [...]
  touched_meso_regions: [...]
  touched_macro_regions: [...]
  touched_mega_regions: [...]
  touched_subprovinces: [...]
  touched_provinces: [...]
```

## Area Photos Cache Format (was photos_in_area)

Per-area list of photos taken within that area's polygon.
A photo can appear in multiple areas when taken near a border.

```yaml
---
- filename: 2021_07_18__11_18__7189980.jpg
  post_slug: 2021-07-18-pagorki-przed-zniwami
- filename: 2021_07_18__11_38__7189990.jpg
  post_slug: 2021-07-18-pagorki-przed-zniwami
```

Organized by area type: `area_photos/{type}/{slug}.yml`

## Areas Config Format (all types identical)

```yaml
---
- slug: pobiedziska
  name: Pobiedziska
  code: "3021082"           # TERC code (towns/counties/voivodeships)
  voivodeship: wielkopolskie # parent (towns/counties only)
  bbox:
    south: 52.37...
    north: 52.50...
    west: 17.05...
    east: 17.29...
```

Meso/macro regions have `code` but no `voivodeship`.

## Polygon GeoJSON Format

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[[lon, lat], [lon, lat], ...]]
  }
}
```

1,630 polygon files across 5 area types.

## Route Coordinates Format

```json
[
  [[lat, lon], [lat, lon], ...],   // route segment 1
  [[lat, lon], [lat, lon], ...]    // route segment 2 (optional)
]
```

Array of route segments. Each segment is array of [lat, lon] pairs.

## GPX Rectifier Tool (planned for Go)

Converts raw GPX from GPS device to clean route data.

**Input config** (gitignored, not committed):
```yaml
# gpx_rectifier.local.yml (example)
privacy_zones:
  - lat: 52.xxx
    lon: 16.xxx
    radius_m: 500

posts:
  2024-05-15-some-trip: "/path/to/raw/track.GPX"
  2024-06-01-another: ["/path/to/part1.GPX", "/path/to/part2.GPX"]
```

**Processing:**
1. Read raw GPX (from GPS device, full resolution)
2. Douglas-Peucker simplification (remove redundant points)
3. Remove noisy/weird points
4. Strip points within privacy zone radius
5. Output: `env/{env}/data/routes/{slug}.json` (simplified coords)
6. Output: simplified GPX file (optional)

**Details:** To be planned in a later phase.

## External Tools

### Crystal (current)

| Tool | Used For | Called By |
|------|----------|-----------|
| `exiv2 -pt` | Extract EXIF metadata from JPEG | ExifProcessor |
| `magick` (ImageMagick) | Resize JPEG images (4 sizes) | ImageResizer |
| `avifenc -q 53` | Convert JPEG → AVIF | ImageResizer (post-resize) |
| `tools/photo_analysis.py` | Perceptual hash + color analysis | PhotoAnalysisCache |

### Go (planned)

| Tool | Used For | Notes |
|------|----------|-------|
| Go EXIF library | Extract EXIF metadata | No external tool needed |
| `magick` or Go imaging lib | Resize JPEG images | Evaluate pure Go option |
| `avifenc` or Go AVIF lib | Convert JPEG → AVIF | May need external tool |

## Image Processing Details

**Source images:** `env/{env}/data/images/{year}/{post_slug}/{filename}.jpg`
- Organized by year, then post slug subdirectory
- Header image referenced by post YAML `image_filename`
- Original camera filenames preserved (e.g., `IMGP4714.JPG`)

**Resized output:** `env/{env}/public/{target}/images/processed/{year}/{month}/{post_slug}_{filename}_{size}.{format}`
- Example JPEG: `2012-04-15-orlowa_imgp4714_grid.jpg`
- Example AVIF: `2012-04-15-orlowa_imgp4714_grid.avif`

**Sizes:** article (1000×800), card (700×525), grid (560×420), thumbnail (150×112)
**Formats:** JPEG + AVIF for each size = 8 variants per photo

## Data Volume Summary

| Data Source | Dev | Full |
|-------------|-----|------|
| Posts | 6 | 726 |
| Config YAMLs | ~8 files | ~8 files |
| Area configs | 5 files, ~3,250 areas | same |
| EXIF caches | 6 files | 726 files |
| Polygon JSONs | 1,630 | 1,630 |
| Photos per post | ~20 avg | ~20 avg |
| Total photos | ~120 | ~14,500 |
| Image variants | ~960 | ~116,000 |
| HTML output | 394 | 7,818 |
| JSON output | ~8 | ~1,545 |
