# Phase 1: Data Pipeline & Dependency Graph

## Goal

Design and implement a unified dependency graph that replaces Crystal's
fragmented approach (5 separate commands + 7 build tasks + implicit caching).

In Crystal, preprocessing is scattered:
- `run_all.cr` — runs 4 commands manually, you have to know when to run it
- View registry tasks (priority 1-9) — run every build, no staleness checks
- EXIF caches — lazily created during rendering, saved to disk
- Image resizing — happens during post rendering, skips if file exists
- No connection between commands and the build — you just "know" to run them

In Go, everything will be a single dependency graph.
One command. Automatic staleness. Parallel execution.

## Primary Data (Never Generated)

These are the leaves of the dependency graph — hand-created, never derived.

| Data | Location | Changes When |
|------|----------|--------------|
| Blog posts | `env/{env}/data/posts/**/*.md` | Author writes/edits |
| Source photos | `env/{env}/data/images/**/*.jpg` | Author adds photos |
| Route coords | `env/{env}/data/json/*.json` | Author adds GPX data |
| GPX files | `env/{env}/data/ideas/raw/*.gpx` | Author plans trips |
| Polygon sources | `data/external/*.yaml` (~90MB) | Rarely (GIS data update) |
| Config YAMLs | `data/config/*.yml` | Author edits tags, settings |
| HTML templates | `data/layout/**/*.html` | Developer changes layout |
| CSS/JS assets | `data/assets/**/*` | Developer changes frontend |

## Derived Data (Generated from Primary)

Organized by how often they need regeneration.

### Tier 1: Once Ever (or when polygon sources change)

| Derived | Source | Generator | Output |
|---------|--------|-----------|--------|
| Area configs | `data/external/*.yaml` | `generate_areas` | `data/config/areas/*.yml` (5 files) |

**What it does:** Reads ~90MB of polygon YAML, extracts slug/name/code/bbox
(no polygon coords), writes 679KB of config files.

**Staleness:** `max(mtime of external/*.yaml) > mtime of areas/*.yml`

**Frequency:** Almost never — only when GIS polygon data is updated.

### Tier 2: When posts/photos change (manual pipeline)

These currently require running `commands/run_all.cr` manually.
In Go, they should run automatically when stale.

| Derived | Depends On | Generator | Output | Time |
|---------|-----------|-----------|--------|------|
| Areas-for-post | post routes + polygons | `match_routes` | `cache/areas_for_post/*.yml` | ~3 min |
| Polygon GeoJSON | areas-for-post + polygons | `simplify_polygons` | `config/polygons/**/*.json` | ~2 min |
| Photos-in-area | photo EXIF + polygons | `match_photos` | `cache/photos_in_area/**/*.yml` | ~2 min |
| Rectified GPX | raw GPX files | `rectify_gpx` | `data/ideas/*.gpx` | <1s |

**Critical insight:** All three polygon-dependent commands share one expensive
resource — the AreaMatcher (~90MB loaded into memory, ~10s startup).
Crystal's `run_all.cr` loads it once and shares across all three.
Go must do the same.

**Staleness per post:**
- areas_for_post: `mtime(post.md) > mtime(cache/areas_for_post/{slug}.yml)`
- Can be incremental — only process changed posts
- Currently uses manifest file (`already_assigned.txt`) for photos

**Dependency chain:**
```
polygons (external) ─┐
                     ├→ areas_for_post ──→ polygon_geojson
post routes ─────────┘

polygons (external) ─┐
                     ├→ photos_in_area
photo EXIF ──────────┘
```

`polygon_geojson` depends on `areas_for_post` (needs to know which areas
are visited). But `photos_in_area` is independent of `areas_for_post` —
these two can run in parallel after the AreaMatcher is loaded.

### Tier 3: Every build (automatic)

| Derived | Depends On | Generator | Output | Time |
|---------|-----------|-----------|--------|------|
| EXIF cache | source JPEGs | exif extractor | `cache/exifs/*.yml` | ~2-3s |
| Resized images | source JPEGs | image resizer | `public/images/**/*` | ~45s (full) |
| Nav stats | posts + configs | aggregation | `cache/nav_stats.yml` | <100ms |
| Coord quant | post routes | quantization | `cache/post_coord_quant.yml` | <100ms |
| Photo coord quant | photo GPS | quantization | `cache/photo_coord_quant.yml` | <100ms |
| Route colors | route_colors.yml | loader | in-memory | <10ms |
| Asset copy | data/assets/ | file copy | public/css,js,fonts | ~1-5s |

**EXIF cache** is special — Crystal creates it lazily during rendering.
Go should extract it as a pipeline node that runs before rendering starts.
This way the EXIF data is available for all views upfront.

**Image resizing** is the biggest bottleneck (75% of build time).
Go should:
- Run as a pipeline node with N worker goroutines
- Check mtime per image (skip if output newer than source)
- Process JPEG and AVIF variants in parallel

### Tier 4: Every build (rendered output)

| Derived | Depends On | Output | Pages |
|---------|-----------|--------|-------|
| HTML pages | SiteData (all above) | `public/**/*.html` | 7,818 |
| JSON endpoints | SiteData | `public/jsons/*.json` | ~8 |
| XML feeds | SiteData | `public/feed*.xml` | 2 |
| Sitemap | SiteData | `public/sitemap.xml` | 1 |

This is Phase 3+ territory — just noting the full graph here.

## Unified Dependency Graph

```
                    PRIMARY DATA
                    ════════════
    ┌──────────┬──────────┬──────────┬──────────┐
    │ posts.md │ images/  │ external/│ config/  │
    │ json/    │ *.jpg    │ *.yaml   │ *.yml    │
    └────┬─────┴────┬─────┴────┬─────┴────┬─────┘
         │          │          │          │
         │          │     ┌────┴────┐     │
         │          │     │ TIER 1  │     │
         │          │     │ area    │     │
         │          │     │ configs │     │
         │          │     └────┬────┘     │
         │          │          │          │
    ┌────┴──────────┴──────────┴──────────┘
    │              TIER 2 (parallel branches)
    │    ┌─────────────────┐  ┌──────────────────┐
    │    │ areas_for_post  │  │ photos_in_area   │
    │    │ (routes×polys)  │  │ (exif×polys)     │
    │    └────────┬────────┘  └──────────────────┘
    │             │
    │    ┌────────┴────────┐
    │    │ polygon_geojson │
    │    │ (simplify)      │
    │    └────────┬────────┘
    │             │
    ├─────────────┴──────────────────────┐
    │              TIER 3 (parallel)     │
    │  ┌──────┐ ┌──────┐ ┌────────────┐ │
    │  │ EXIF │ │ nav  │ │ image      │ │
    │  │cache │ │stats │ │ resize     │ │
    │  └──┬───┘ └──┬───┘ └──────┬─────┘ │
    │     │        │             │       │
    │  ┌──┴───┐ ┌──┴───┐        │       │
    │  │coord │ │photo │        │       │
    │  │quant │ │quant │        │       │
    │  └──┬───┘ └──┬───┘        │       │
    │     │        │             │       │
    └─────┴────────┴─────────────┴───────┘
                   │
              ┌────┴────┐
              │SiteData │  (frozen, immutable)
              │ indexes │
              └────┬────┘
                   │
              TIER 4: RENDER
              (views, feeds, JSON)
```

## Pipeline Node Interface

```go
// Every node in the graph implements this
type Node interface {
    Name() string
    DependsOn() []string          // names of upstream nodes
    IsStale(ctx *PipelineContext) bool
    Run(ctx *PipelineContext) error
}

// PipelineContext carries shared state between nodes
type PipelineContext struct {
    Env        string              // "dev" or "full"
    Target     string              // "local" or "release"
    BasePath   string              // project root
    Force      bool                // --force flag (ignore staleness)
    Verbose    bool                // --verbose flag
    Workers    int                 // parallelism level

    // Shared expensive resources (loaded once, used by many nodes)
    areaMatcher *AreaMatcher       // ~90MB, loaded lazily on first use
    mu          sync.Mutex         // protects areaMatcher init

    // Results from completed nodes (populated during execution)
    results     map[string]any     // node name → output data
}

// Lazy AreaMatcher — loaded once, shared by 3 nodes
func (pc *PipelineContext) AreaMatcher() (*AreaMatcher, error) {
    pc.mu.Lock()
    defer pc.mu.Unlock()
    if pc.areaMatcher == nil {
        // Load ~90MB polygon data, build spatial index
        pc.areaMatcher = LoadAreaMatcher(pc.BasePath)
    }
    return pc.areaMatcher, nil
}
```

## Pipeline Runner

```go
func RunPipeline(nodes []Node, ctx *PipelineContext) error {
    // 1. Build dependency graph
    graph := buildDAG(nodes)

    // 2. Topological sort
    order := topoSort(graph)

    // 3. Execute in layers (parallel within layer)
    for _, layer := range order {
        staleNodes := filterStale(layer, ctx)
        if len(staleNodes) == 0 {
            log("Layer %d: all up-to-date, skipping", layerNum)
            continue
        }

        var wg sync.WaitGroup
        for _, node := range staleNodes {
            wg.Add(1)
            go func(n Node) {
                defer wg.Done()
                start := time.Now()
                err := n.Run(ctx)
                log("%s: %v (%s)", n.Name(), status(err), time.Since(start))
            }(node)
        }
        wg.Wait()
    }
    return nil
}
```

## Node Definitions

### Tier 1 Nodes

```
Node: "area_configs"
  DependsOn: []  (reads primary data/external/)
  Stale when: max(mtime data/external/*.yaml) > min(mtime data/config/areas/*.yml)
  Produces: data/config/areas/{towns,counties,voivodeships,meso_regions,macro_regions}.yml
  Expensive: ~10s (reads 90MB, extracts bbox)
  Incremental: No (all-or-nothing — external data changes rarely)
```

### Tier 2 Nodes

```
Node: "areas_for_post"
  DependsOn: ["area_configs"]
  Stale when: any post.md newer than its areas_for_post cache file
  Produces: env/{env}/cache/areas_for_post/{slug}.yml (per post)
  Expensive: ~3 min full, ~2s per post incremental
  Incremental: YES — per post, only process changed
  Shared resource: AreaMatcher (loaded once)

Node: "polygon_geojson"
  DependsOn: ["areas_for_post"]
  Stale when: areas_for_post changed → new areas visited
  Produces: data/config/polygons/{type}/{slug}.json
  Expensive: ~2 min full, <1s per new area
  Incremental: YES — skip existing polygons
  Shared resource: AreaMatcher

Node: "photos_in_area"
  DependsOn: ["area_configs"]  (NOT areas_for_post — independent!)
  Stale when: new photos added (manifest check)
  Produces: env/{env}/cache/photos_in_area/{type}/{slug}.yml
  Expensive: ~2 min full
  Incremental: YES — manifest-based
  Shared resource: AreaMatcher

Node: "gpx_rectify"
  DependsOn: []  (reads primary GPX files)
  Stale when: raw GPX newer than processed GPX
  Produces: env/{env}/data/ideas/*.gpx
  Cheap: <1s
  Incremental: YES — per file
```

### Tier 3 Nodes

```
Node: "exif_cache"
  DependsOn: []  (reads primary image files)
  Stale when: any image newer than its exif cache
  Produces: env/{env}/cache/exifs/{slug}.yml (per post)
  Time: ~2-3s full (read EXIF from JPEG headers)
  Incremental: YES — per post
  Parallel: YES — each post independent

Node: "image_resize"
  DependsOn: []  (reads primary image files)
  Stale when: source image newer than resized variant
  Produces: 8 variants per photo (4 sizes × 2 formats)
  Time: ~45s full, <1s incremental
  Incremental: YES — per image (mtime check)
  Parallel: YES — worker pool with NumCPU goroutines

Node: "nav_stats"
  DependsOn: ["posts_loaded", "configs_loaded"]
  Stale when: always (cheap to recompute)
  Produces: cache/nav_stats.yml + in-memory NavStats
  Time: <100ms

Node: "coord_quant"
  DependsOn: ["posts_loaded", "exif_cache"]
  Stale when: always (cheap to recompute)
  Produces: cache/post_coord_quant.yml + cache/photo_coord_quant.yml
  Time: <100ms

Node: "asset_copy"
  DependsOn: []
  Stale when: any asset file changed
  Produces: public/css/, public/js/, public/fonts/
  Time: ~1-5s (rsync-like copy)

Node: "route_colors"
  DependsOn: ["configs_loaded"]
  Stale when: route_colors.yml changed
  Produces: in-memory RouteColors
  Time: <10ms
```

## Execution Modes

### Full Build
```
$ odkrywajac build --env=dev --target=local

Pipeline: checking 12 nodes...
  area_configs:     up-to-date (skipping)
  areas_for_post:   up-to-date (skipping)
  polygon_geojson:  up-to-date (skipping)
  photos_in_area:   up-to-date (skipping)
  gpx_rectify:      up-to-date (skipping)
  exif_cache:       STALE (2 posts changed) → running... 450ms
  image_resize:     STALE (12 images) → running... 1.2s (8 workers)
  nav_stats:        recomputing... 45ms
  coord_quant:      recomputing... 23ms
  asset_copy:       3 files changed → copying... 120ms
  route_colors:     up-to-date
  site_data:        building indexes... 89ms

Pipeline complete: 6 stale, 6 up-to-date (1.9s total)
Rendering 394 pages... (8 workers)
Done in 4.2s
```

### Force Rebuild
```
$ odkrywajac build --env=dev --target=local --force

Pipeline: forcing all 12 nodes...
  area_configs:     regenerating... 8.2s
  areas_for_post:   processing 6 posts... 1.4s
  polygon_geojson:  simplifying 42 polygons... 3.1s
  ...
```

### Pipeline Only (no rendering)
```
$ odkrywajac pipeline --env=dev

Pipeline: checking 8 data nodes...
  (same as above, without rendering step)
```

### Dry Run
```
$ odkrywajac build --env=dev --dry-run

Pipeline: would execute:
  exif_cache:    2 posts changed
  image_resize:  12 images to process
  nav_stats:     always recomputed
  coord_quant:   always recomputed
  asset_copy:    3 files changed
Rendering: 394 pages would be generated
```

## AreaMatcher Strategy

The AreaMatcher is the most expensive shared resource (~90MB, ~10s load).

**Crystal approach:** Load in `run_all.cr`, pass to 3 commands.

**Go approach:** Lazy singleton in PipelineContext.
- First node that needs it triggers the load
- Subsequent nodes get the cached instance
- If no polygon-dependent nodes are stale, it's never loaded
- Protected by mutex for thread safety

**Long term:** Consider a Go-native geo library instead of GEOS (CGo).
Options:
- `github.com/paulmach/orb` — pure Go geometry (point-in-polygon, simplification)
- `github.com/tidwall/geodesic` — geodesic calculations
- Avoids CGo complexity and GEOS dependency

## Testing Strategy

### Unit Tests (TDD — write test first)
- Each node's `IsStale()` logic tested with mock filesystem
- Each node's `Run()` tested with fixture data
- Graph builder and topo sort tested with mock nodes
- AreaMatcher tested with small polygon fixtures

### Integration Tests
- Load dev environment (6 posts), verify pipeline produces expected caches
- Compare output counts with Crystal's output
- Verify staleness detection: change a post, verify only affected nodes run

### E2E Tests (Rod — Go-native browser testing)
- Smoke tests: built pages load in browser
- Content validation: titles, links, images present
- Keep existing Playwright suite as gold standard

## Files to Create

```
go-rewrite/
├── internal/
│   └── pipeline/
│       ├── node.go           — Node interface, FileSource, DerivedData, ComputedIndex
│       ├── graph.go          — DAG builder, topological sort
│       ├── runner.go         — Parallel executor with layer-based scheduling
│       ├── staleness.go      — Mtime checking, hash comparison
│       ├── context.go        — PipelineContext with lazy AreaMatcher
│       ├── nodes/
│       │   ├── area_configs.go
│       │   ├── areas_for_post.go
│       │   ├── polygon_geojson.go
│       │   ├── photos_in_area.go
│       │   ├── exif_cache.go
│       │   ├── image_resize.go
│       │   ├── nav_stats.go
│       │   ├── coord_quant.go
│       │   ├── asset_copy.go
│       │   └── gpx_rectify.go
│       └── nodes_test.go     — Tests for all nodes
```

## What This Phase Does NOT Cover

- Post markdown parsing (Phase 2)
- View rendering (Phase 3+)
- Template system (Phase 3+)
- Router / URL generation (Phase 3+)

This phase establishes the foundation: "given primary data, produce all
derived data correctly and incrementally." Everything after this reads
from the pipeline's output.
