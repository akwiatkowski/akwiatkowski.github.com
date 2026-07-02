# Phase 6: Complex Views — Year Reports, Galleries, SVG Maps, POIs, Debug

## Status: COMPLETE

## Summary

Added ~31 new views bringing total from 175 to 206 views in dev (~46ms build time).
Full environment generates 4377 views with 778 SVG maps.

## What Was Added

### Year Reports (year_report.go)
Per-year statistics pages (`/rok-YYYY.html`) with:
- Sparkline activity charts (distance/elevation per month)
- Tag breakdown (percentage of posts per tag)
- Records section (longest ride, highest elevation, etc.)
- Route map SVG rendered inline
- Photo of the year selection

### Burnout Stats (burnout.go)
- **Burnout page** (`/debug/burnout.html`) — month-over-month activity deltas, streak tracking

### Towns History & Timeline (towns_history.go, towns_timeline.go)
- **Towns History** (`/gminy/historia.html`) — towns grouped by voivodeship with discovery dates
- **Towns Timeline** (`/gminy/chronologicznie.html`) — chronological town discovery order

### Gallery Infrastructure (gallery.go)
Gallery pages with fill algorithm for responsive grid layout:
- **Gallery Index** (`/galeria.html`) — all galleries overview
- **Tag Galleries** (`/galeria/tag/<slug_pl>.html`) — per-tag photo galleries
- **Area Galleries** (`/galeria/<genitive>/<slug>.html`) — per-area photo galleries
- **Post Galleries** (`/<year>/<month>/<slug>/galeria.html`) — per-post photo galleries
- **Post Gallery Stats** — per-post EXIF statistics pages
- **EXIF Galleries** — camera, lens, focal length, ISO, exposure galleries

### SVG Photo Maps (svg/ package)
New `internal/svg/` package with Mercator projection and spatial indexing:
- **renderer.go** — SVG generation with configurable dimensions, voivodeship borders
- **projection.go** — Mercator lat/lon → SVG coordinate mapping
- **spatial.go** — Grid-based spatial index for photo clustering

Map renderers in `photo_map.go`:
- **Global photo map** — all GPS-tagged photos on Poland outline
- **Voivodeship maps** — per-voivodeship photo density
- **Post maps** — route overlay with photo locations
- **Tag maps** — tag-filtered photo distribution

### POIs Page (pois.go)
- **POIs** (`/pois.html`) — auto-clustered points of interest from best geotagged photos

### Debug Views (debug.go)
- **Tag Stats** (`/debug/tagged_photos.html`) — photo counts per tag, quality distribution

## New Files

```
internal/svg/
├── projection.go       + projection_test.go  — Mercator coordinate mapping
├── renderer.go                               — SVG path/circle generation
└── spatial.go          + spatial_test.go     — grid spatial index

internal/view/
├── year_report.go      + year_report_test.go  — year statistics pages
├── burnout.go          + burnout_test.go      — activity burnout analysis
├── towns_history.go    + towns_history_test.go — voivodeship-grouped history
├── towns_timeline.go   + towns_timeline_test.go — chronological discovery
├── gallery.go          + gallery_test.go      — all gallery page types
├── photo_map.go        + photo_map_test.go    — SVG map renderers
├── pois.go             + pois_test.go         — POIs page
├── debug.go            + debug_test.go        — tag stats debug view

internal/templates/views/
├── year_report.templ                          — year report with sparklines
├── burnout.templ                              — burnout stats template
├── towns_history.templ                        — voivodeship-grouped towns
├── towns_timeline.templ                       — chronological timeline
├── gallery_index.templ                        — gallery overview
├── pois.templ                                 — POIs shell page
├── debug_tag_stats.templ                      — tag statistics table
└── types.go                                   — shared template data types

internal/model/post.go                         — Year(), activity helpers
internal/router/router.go                      — YearReportURL, BurnoutURL, etc.
go-rewrite/README.md                           — full URL catalog
```

## Architecture Decisions

1. **SVG package separate from views** — projection, spatial indexing, and rendering are reusable primitives
2. **Spatial index for photo clustering** — grid-based O(1) lookup avoids O(n²) comparisons
3. **Gallery fill algorithm** — calculates row heights to fill container width evenly
4. **Year reports are data-heavy** — compute all stats in Go, pass pre-computed data to templ
5. **Post gallery URLs** — `/<year>/<month>/<slug>/galeria.html` (differs from Crystal's `/galeria/<year>/<month>/<day>-<slug>.html`)
6. **EXIF galleries** — lens, camera, focal length, ISO, exposure each get their own gallery pages

## Test Coverage

- ~65 view tests total (up from 43)
- year_report_test.go: sparkline computation, records extraction, tag breakdown
- burnout_test.go: streak detection, month deltas
- gallery_test.go: fill algorithm, tag/area/post gallery rendering
- photo_map_test.go: SVG generation, spatial clustering
- towns_history_test.go: voivodeship grouping, date formatting
- towns_timeline_test.go: chronological ordering
- pois_test.go: photo clustering, POI selection
- debug_test.go: tag stats aggregation
- svg/projection_test.go: Mercator accuracy
- svg/spatial_test.go: grid index queries

## Stats

- Dev: 206 views, ~46ms
- Full: 4377 views (includes 778 SVG maps)
