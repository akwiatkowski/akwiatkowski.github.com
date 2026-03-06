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

## Directory Structure

Go uses its own cache directories, separate from Crystal:

```
# Generated from external data (project-level, env-independent)
go-rewrite/cache/
├── areas/                      # area configs (bbox only, 5 files)
└── polygons/                   # GeoJSON polygon files (1,630 files)

# Per-environment caches
env/{env}/cache-go/
├── exif/{slug}.yml             # EXIF metadata per post
├── route_coverage/{slug}.yml   # distance/time per area per post
├── area_photos/{type}/{slug}.yml  # photos per area
├── route_grid.yml              # route → grid cells + related posts
├── photo_grid.yml              # photo → grid cells + nearest town
├── photo_hashes/{slug}.yml     # perceptual hashes (optional)
└── build_manifest.json         # SHA256 per output file

# Output
env/{env}/public/go/            # Go's rendered output
```

Crystal continues using `data/config/areas/`, `data/config/polygons/`,
`env/{env}/cache/`, and `env/{env}/public/local/` — no changes needed.

## Primary Data (Never Generated)

These are the leaves of the dependency graph — hand-created, never derived.

| Data | Location | Changes When |
|------|----------|--------------|
| Blog posts | `env/{env}/data/posts/**/*.md` | Author writes/edits |
| Source photos | `env/{env}/data/images/**/*.jpg` | Author adds photos |
| Route coords | `env/{env}/data/routes/*.json` | GPX rectifier output |
| Polygon sources | `data/external/*.yaml` (~90MB) | Rarely (GIS data update) |
| Config YAMLs | `data/config/*.yml` | Author edits tags, settings |
| CSS/JS assets | `data/assets/**/*` | Developer changes frontend |

Note: No HTML templates — Go uses templ components (compiled Go code, see Phase 3).

## Derived Data (Generated from Primary)

Organized by how often they need regeneration.

### Tier 1: Once Ever (or when polygon sources change)

| Derived | Source | Generator | Output |
|---------|--------|-----------|--------|
| Area configs | `data/external/*.yaml` | `generate_areas` | `go-rewrite/cache/areas/*.yml` (5 files) |
| Polygon GeoJSON | `data/external/*.yaml` | `simplify_polygons` | `go-rewrite/cache/polygons/**/*.json` |

**What it does:** Reads ~90MB of polygon YAML, extracts slug/name/code/bbox
(no polygon coords), writes config files. Separately, simplifies polygons to
GeoJSON for frontend display.

**Staleness:** `max(mtime of external/*.yaml) > mtime of areas/*.yml`

**Frequency:** Almost never — only when GIS polygon data is updated.

### Tier 2: When posts/photos change (manual pipeline in Crystal, automatic in Go)

These currently require running `commands/run_all.cr` manually.
In Go, they should run automatically when stale.

| Derived | Depends On | Generator | Output | Time |
|---------|-----------|-----------|--------|------|
| Route coverage | post routes + polygons | `match_routes` | `cache-go/route_coverage/*.yml` | ~3 min |
| Polygon GeoJSON | route_coverage + polygons | `simplify_polygons` | `go-rewrite/cache/polygons/**/*.json` | ~2 min |
| Area photos | photo EXIF + polygons | `match_photos` | `cache-go/area_photos/**/*.yml` | ~2 min |

**Critical insight:** All three polygon-dependent commands share one expensive
resource — the AreaMatcher (~90MB loaded into memory, ~10s startup).
Crystal's `run_all.cr` loads it once and shares across all three.
Go must do the same.

**Staleness per post:**
- route_coverage: `mtime(post.md) > mtime(cache-go/route_coverage/{slug}.yml)`
- Can be incremental — only process changed posts
- Currently uses manifest file (`already_assigned.txt`) for photos

**Dependency chain:**
```
polygons (external) ─┐
                     ├→ route_coverage ──→ polygon_geojson
post routes ─────────┘

polygons (external) ─┐
                     ├→ area_photos
photo EXIF ──────────┘
```

`polygon_geojson` depends on `route_coverage` (needs to know which areas
are visited). But `area_photos` is independent of `route_coverage` —
these two can run in parallel after the AreaMatcher is loaded.

### Tier 3: Every build (automatic)

| Derived | Depends On | Generator | Output | Time |
|---------|-----------|-----------|--------|------|
| EXIF cache | source JPEGs | exif extractor | `cache-go/exif/*.yml` | ~2-3s |
| Resized images | source JPEGs | image resizer | `public/go/images/**/*` | ~45s (full) |
| Route grid | post routes + exif | quantization | `cache-go/route_grid.yml` | Cached |
| Photo grid | photo GPS | quantization | `cache-go/photo_grid.yml` | Cached |
| Asset copy | data/assets/ | file copy | public/go/css,js,fonts | ~1-5s |

**EXIF cache** is special — Crystal creates it lazily during rendering.
Go should extract it as a pipeline node that runs before rendering starts.
This way the EXIF data is available for all views upfront.

**Image resizing** is the biggest bottleneck (75% of build time).
Go should:
- Run as a pipeline node with N worker goroutines
- Check mtime per image (skip if output newer than source)
- Process JPEG and AVIF variants in parallel

**Nav stats** — computed in memory from loaded posts every build, no cache file
needed. Not a pipeline node — just part of SiteData construction.

**Route colors** — primary config loaded from `data/config/route_colors.yml`.
Not a pipeline node — just a config loader.

### Tier 4: Every build (rendered output)

| Derived | Depends On | Output | Pages |
|---------|-----------|--------|-------|
| HTML pages | SiteData (all above) | `public/go/**/*.html` | 7,818 |
| JSON endpoints | SiteData | `public/go/jsons/*.json` | ~8 |
| XML feeds | SiteData | `public/go/feed*.xml` | 2 |
| Sitemap | SiteData | `public/go/sitemap.xml` | 1 |

This is Phase 3+ territory — just noting the full graph here.

## Unified Dependency Graph

```
                    PRIMARY DATA
                    ════════════
    ┌──────────┬──────────┬──────────┬──────────┐
    │ posts.md │ images/  │ external/│ config/  │
    │ routes/  │ *.jpg    │ *.yaml   │ *.yml    │
    └────┬─────┴────┬─────┴────┬─────┴────┬─────┘
         │          │          │          │
         │          │     ┌────┴────┐     │
         │          │     │ TIER 1  │     │
         │          │     │ area    │     │
         │          │     │ configs │     │
         │          │     │+polygons│     │
         │          │     └────┬────┘     │
         │          │          │          │
    ┌────┴──────────┴──────────┴──────────┘
    │              TIER 2 (parallel branches)
    │    ┌─────────────────┐  ┌──────────────────┐
    │    │ route_coverage  │  │ area_photos      │
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
    │  ┌──────┐ ┌──────────┐ ┌────────┐ │
    │  │ EXIF │ │ route    │ │ image  │ │
    │  │cache │ │ grid     │ │ resize │ │
    │  └──┬───┘ └──┬───────┘ └──┬─────┘ │
    │     │        │             │       │
    │     │   ┌────┴────┐        │       │
    │     │   │ photo   │        │       │
    │     │   │ grid    │        │       │
    │     │   └────┬────┘        │       │
    │     │        │             │       │
    └─────┴────────┴─────────────┴───────┘
                   │
              ┌────┴────┐
              │SiteData │  (frozen, immutable)
              │+indexes │  (nav_stats computed here)
              │+navstats│
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
    Target     string              // "go" (separate from Crystal's "local"/"release")
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
  Stale when: max(mtime data/external/*.yaml) > min(mtime go-rewrite/cache/areas/*.yml)
  Produces: go-rewrite/cache/areas/{towns,counties,voivodeships,meso_regions,macro_regions}.yml
  Expensive: ~10s (reads 90MB, extracts bbox)
  Incremental: No (all-or-nothing — external data changes rarely)

Node: "polygon_geojson_tier1"
  DependsOn: ["area_configs"]
  Stale when: area_configs changed
  Produces: go-rewrite/cache/polygons/{type}/{slug}.json (1,630 files)
  Expensive: ~2 min (Douglas-Peucker simplification)
  Incremental: YES — skip existing polygons
  Shared resource: AreaMatcher
```

### Tier 2 Nodes

```
Node: "route_coverage"
  DependsOn: ["area_configs"]
  Stale when: any post.md newer than its route_coverage cache file
  Produces: env/{env}/cache-go/route_coverage/{slug}.yml (per post)
  Expensive: ~3 min full, ~2s per post incremental
  Incremental: YES — per post, only process changed
  Shared resource: AreaMatcher (loaded once)

Node: "polygon_geojson_tier2"
  DependsOn: ["route_coverage"]
  Stale when: route_coverage changed → new areas visited
  Produces: go-rewrite/cache/polygons/{type}/{slug}.json (only new areas)
  Expensive: <1s per new area
  Incremental: YES — skip existing polygons
  Shared resource: AreaMatcher

Node: "area_photos"
  DependsOn: ["area_configs"]  (NOT route_coverage — independent!)
  Stale when: new photos added (manifest check)
  Produces: env/{env}/cache-go/area_photos/{type}/{slug}.yml
  Expensive: ~2 min full
  Incremental: YES — manifest-based
  Shared resource: AreaMatcher
```

### Tier 3 Nodes

```
Node: "exif_cache"
  DependsOn: []  (reads primary image files)
  Stale when: any image newer than its exif cache
  Produces: env/{env}/cache-go/exif/{slug}.yml (per post)
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

Node: "route_grid"
  DependsOn: ["posts_loaded", "exif_cache"]
  Stale when: posts or exif changed
  Produces: env/{env}/cache-go/route_grid.yml
  Time: Cached (not cheap)

Node: "photo_grid"
  DependsOn: ["posts_loaded", "exif_cache"]
  Stale when: posts or exif changed
  Produces: env/{env}/cache-go/photo_grid.yml
  Time: Cached (not cheap)

Node: "asset_copy"
  DependsOn: []
  Stale when: any asset file changed
  Produces: public/go/css/, public/go/js/, public/go/fonts/
  Time: ~1-5s (rsync-like copy)
```

**Not pipeline nodes** (computed during SiteData construction):
- **Nav stats** — aggregated from posts in memory, no file
- **Route colors** — primary config loaded from `route_colors.yml`

## Execution Modes

### Full Build
```
$ odkrywajac build --env=dev --target=go

Pipeline: checking 10 nodes...
  area_configs:        up-to-date (skipping)
  polygon_geojson_t1:  up-to-date (skipping)
  route_coverage:      up-to-date (skipping)
  polygon_geojson_t2:  up-to-date (skipping)
  area_photos:         up-to-date (skipping)
  exif_cache:          STALE (2 posts changed) → running... 450ms
  image_resize:        STALE (12 images) → running... 1.2s (8 workers)
  route_grid:          recomputing... 45ms
  photo_grid:          recomputing... 23ms
  asset_copy:          3 files changed → copying... 120ms
  site_data:           building indexes + nav_stats... 89ms

Pipeline complete: 5 stale, 5 up-to-date (1.9s total)
Rendering 394 pages... (8 workers)
Done in 4.2s
```

### Force Rebuild
```
$ odkrywajac build --env=dev --target=go --force

Pipeline: forcing all 10 nodes...
  area_configs:     regenerating... 8.2s
  route_coverage:   processing 6 posts... 1.4s
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
  route_grid:    recomputing
  photo_grid:    recomputing
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

## GPX Rectifier

Not a pipeline node — planned as a separate tool command.
See DATA_SOURCES.md for the planned design (local gitignored config,
privacy zones, Douglas-Peucker simplification).

Will be implemented in a later phase.

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
│       │   ├── route_coverage.go
│       │   ├── polygon_geojson.go
│       │   ├── area_photos.go
│       │   ├── exif_cache.go
│       │   ├── image_resize.go
│       │   ├── route_grid.go
│       │   ├── photo_grid.go
│       │   └── asset_copy.go
│       └── nodes_test.go     — Tests for all nodes
```

## What This Phase Does NOT Cover

- Post markdown parsing (Phase 2)
- View rendering (Phase 3+)
- Template system (Phase 3+ — templ components)
- Router / URL generation (Phase 3+)
- GPX rectifier tool (later phase)

This phase establishes the foundation: "given primary data, produce all
derived data correctly and incrementally." Everything after this reads
from the pipeline's output.
