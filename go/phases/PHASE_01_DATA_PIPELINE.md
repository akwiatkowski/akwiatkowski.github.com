# Phase 1: Data Pipeline & Dependency Graph

**Status: COMPLETE**

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

## Key Decisions Made

- **Node interface**: Minimal 4-method interface (`Name`, `Deps`, `IsStale`, `Run`)
  plus `SimpleNode` struct for quick creation via function fields.
- **Kahn's algorithm** for topological sort — detects cycles and produces
  layers for parallel execution.
- **Fail-fast**: First node error stops the entire pipeline immediately.
- **Worker pool**: Bounded parallelism via buffered channel semaphore,
  respects `ctx.Workers` limit.
- **Separate caches**: `env/{env}/cache-go/` keeps Go output separate from Crystal.
- **Method naming**: `Deps()` not `DependsOn()`, `Context` not `PipelineContext` — shorter.

## What Was Implemented

### Step 1: Node Interface (`internal/pipeline/node.go`)

```go
type Node interface {
    Name() string
    Deps() []string
    IsStale(ctx *Context) bool
    Run(ctx *Context) error
}
```

- `SimpleNode` struct with function fields (`NameStr`, `DepsList`, `StaleFn`, `RunFn`)
- Default `IsStale()` returns `true` if `StaleFn` is nil (always stale)
- Users can implement `Node` interface directly or use `SimpleNode` for convenience

### Step 2: DAG Builder & Topological Sort (`internal/pipeline/graph.go`)

- `NewGraph(nodes []Node)` — validates and builds DAG:
  - No duplicate node names
  - All dependencies exist
  - No cycles (Kahn's algorithm with in-degree tracking)
- `Layers()` — returns nodes grouped by execution layers (parallel within layer)
- `Node(name)` — lookup by name

### Step 3: Parallel Runner (`internal/pipeline/runner.go`)

- `RunStatus` enum: `StatusRan`, `StatusSkipped`, `StatusError`, `StatusDryRun`
- `RunResult` struct: `NodeName`, `Status`, `Duration`, `Err`
- `Run(g *Graph, ctx *Context)` — executes layers sequentially, nodes within layer in parallel
- Semaphore-based worker pool bounded by `ctx.Workers`
- Staleness checking: skips fresh nodes unless `ctx.Force` is true
- Dry-run mode: reports what would run without executing
- Fail-fast error propagation

### Step 4: Pipeline Context (`internal/pipeline/context.go`)

- `Context` struct with configuration:
  - `Env`, `Target`, `BasePath` (paths)
  - `Force`, `DryRun`, `Verbose`, `Workers` (flags)
  - `results map[string]any` (thread-safe via mutex)
- Path helper methods:
  - `PostsDir()` → `{BasePath}/env/{Env}/data/posts`
  - `ImagesDir()`, `RoutesDir()`, `ConfigDir()`, `ExternalDir()`
  - `CacheDir()` → `{BasePath}/env/{Env}/cache-go`
  - `OutputDir()` → `{BasePath}/env/{Env}/public/{Target}`
  - `GeneratedCacheDir()` → `{BasePath}/go-rewrite/cache`
- Result storage: `StoreResult(name, value)`, `Result(name) any`

### Step 5: Staleness Utilities (`internal/pipeline/staleness.go`)

- `MaxMtime(paths ...string)` — most recent mtime, skips non-existent files
- `FileNewerThan(source, target)` — true if source newer or target missing
- `AnyNewerThan(sources, target)` — true if any source file newer
- `GlobNewerThan(pattern, target)` — glob-based staleness check

### Step 6: CLI Entry Point (`cmd/odkrywajac/main.go`)

- Two subcommands: `build` and `pipeline`
- Shared flags: `-env`, `-target`, `-base`, `-force`, `-dry-run`, `-verbose`, `-workers`
- `runBuild()` — placeholder (wired up with loaders in Phase 2)
- `runPipeline()` — placeholder (concrete nodes registered in later phases)

## Directory Structure (Go vs Crystal)

Go uses its own cache directories, separate from Crystal:

```
# Per-environment caches
env/{env}/cache-go/
├── exif/{slug}.yml             # EXIF metadata per post
├── route_coverage/{slug}.yml   # distance/time per area per post
├── area_photos/{type}/{slug}.yml  # photos per area
└── build_manifest.json         # SHA256 per output file

# Output
env/{env}/public/go/            # Go's rendered output
```

Crystal continues using `data/config/areas/`, `env/{env}/cache/`,
and `env/{env}/public/local/` — no changes needed.

## Files Created

```
go-rewrite/
├── cmd/odkrywajac/
│   └── main.go              — CLI with build/pipeline subcommands
├── internal/pipeline/
│   ├── node.go              — Node interface + SimpleNode
│   ├── graph.go             — DAG builder, topological sort (Kahn's)
│   ├── runner.go            — Parallel executor with worker pool
│   ├── context.go           — Shared context, path helpers, result storage
│   ├── staleness.go         — File mtime staleness utilities
│   ├── graph_test.go        — 11 tests
│   ├── runner_test.go       — 11 tests
│   ├── context_test.go      — 6 tests
│   └── staleness_test.go    — 5 tests
├── go.mod                   — module odkrywajac, go 1.26
└── makefile                 — go-init, go-test, go-build targets
```

## Dependencies Added

- Standard library only (no external deps in Phase 1)

## Test Results

```
ok  odkrywajac/internal/pipeline  — 33 tests

graph_test.go (11):     empty graph, single node, linear chain, parallel nodes,
                        diamond dependency, cycle detection (2-node, self, 3-node),
                        missing dependency, duplicate node, node lookup
runner_test.go (11):    simple run, dependency order, skip fresh, force mode,
                        dry-run, error propagation, parallel execution, worker bounds,
                        duration tracking, staleness errors, empty graph
context_test.go (6):    path helpers (all directories), env variants (dev/full),
                        result storage and retrieval, overwrite
staleness_test.go (5):  MaxMtime, FileNewerThan (newer/older/missing),
                        AnyNewerThan, GlobNewerThan
```

## What's Deferred

- **Concrete pipeline nodes**: No actual nodes registered yet — the framework is
  ready but `area_configs`, `route_coverage`, `exif_cache`, `image_resize`, etc.
  are implemented as standalone loaders in Phase 2, not as pipeline nodes.
- **AreaMatcher singleton**: Lazy-loading shared ~90MB polygon resource planned
  but not yet needed — implement when polygon-dependent nodes are built.
- **Node registration system**: Nodes are manually created and passed to `Run()`.
  No global registry yet.
- **Image resizing**: Pipeline node for parallel image processing (JPEG + AVIF).
- **Route/photo grid computation**: Spatial grid nodes for map views.
- **Asset copy node**: File copy from `data/assets/` to output.

## Full Dependency Graph (Reference)

This shows the complete planned graph. Phase 1 built the framework;
later phases add concrete nodes.

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
