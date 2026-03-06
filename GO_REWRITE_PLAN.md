# Go Rewrite Plan

A parallel-first Go rewrite of the Crystal blog engine.
Not a line-by-line port — a fundamentally better architecture.

## Design Principles

1. **Parallel by default** — every stage uses goroutines unless there's a reason not to
2. **Pipeline architecture** — data flows through stages connected by channels
3. **Immutable shared state** — build data once, share read-only across workers
4. **No inheritance** — interfaces + composition instead of Crystal's class hierarchy
5. **Embed everything** — templates, config, assets compiled into single binary
6. **Incremental builds** — track file mtimes, skip unchanged work
7. **Feature parity is not the goal** — build what matters, skip debug/diagnostic views

## Architecture: Pipeline with Fan-Out

```
┌─────────────────────────────────────────────────────────────┐
│  STAGE 1: LOAD (parallel)                          ~200ms  │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ Posts    │  │ YAML     │  │ EXIF     │  │ Templates │  │
│  │ 730 .md │  │ configs  │  │ caches   │  │ 82 .html  │  │
│  │ (8 work)│  │ (1 work) │  │ (4 work) │  │ (1 work)  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬─────┘  │
│       └──────────────┴──────────────┴──────────────┘        │
│                          │                                  │
│                    sync.WaitGroup                           │
│                          ▼                                  │
├─────────────────────────────────────────────────────────────┤
│  STAGE 2: INDEX (single-threaded)                  ~100ms  │
│                                                             │
│  Build read-only indexes from loaded data:                  │
│  • PostsByArea map[areaKey][]Post                           │
│  • AreasByType map[AreaType][]Area                          │
│  • PhotoIndex (spatial, by EXIF field)                      │
│  • TagIndex map[slug]Tag                                    │
│  • NavStats (computed once)                                 │
│                                                             │
│  Result: frozen SiteData struct (no mutation after this)    │
├─────────────────────────────────────────────────────────────┤
│  STAGE 3: RENDER (parallel fan-out)                ~2-4s   │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Areas    │ │ Tags     │ │ Feeds    │ │ Static   │      │
│  │ show,    │ │ post     │ │ RSS,JSON │ │ about,   │      │
│  │ lists,   │ │ lists,   │ │ sitemap  │ │ map, etc │      │
│  │ gallery  │ │ gallery  │ │          │ │          │      │
│  │ N worker │ │ N worker │ │ N worker │ │ 1 worker │      │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘      │
│       └──────────────┴──────────────┴──────────────┘        │
│                          │                                  │
│              chan OutputFile (buffered)                      │
│                          ▼                                  │
├─────────────────────────────────────────────────────────────┤
│  STAGE 4: WRITE (parallel writer pool)             ~200ms  │
│                                                             │
│  4 goroutines drain chan OutputFile                          │
│  Each: create dirs, write file, log                         │
│  No contention — each file is unique path                   │
└─────────────────────────────────────────────────────────────┘
```

## Core Data Model

Not Crystal structs with getters — Go structs with exported fields.
No lazy loading, no nilable getters. Load everything upfront.

```go
// SiteData is the frozen, read-only world state.
// Built once in Stage 2, shared across all render goroutines.
// No mutexes needed — it's immutable after construction.
type SiteData struct {
    Posts       []*Post
    Tags       []*Tag
    Areas      map[AreaType][]*Area
    PhotoIndex *PhotoIndex
    NavStats   *NavStats
    Config     *SiteConfig
    Router     *Router
    Templates  *TemplateCache
    Bundles    *BundleResolver
}

// Indexes for O(1) lookups instead of Crystal's filter-and-cache pattern
type SiteData struct {
    // ... fields above, plus:
    postsByArea   map[string][]*Post     // "town:pobiedziska" → posts
    postsByTag    map[string][]*Post     // "bicycle" → posts
    postsByYear   map[int][]*Post        // 2024 → posts
    areasBySlug   map[string]*Area       // "pobiedziska" → area
    tagBySlug     map[string]*Tag        // "bicycle" → tag
    photosByArea  map[string][]*Photo    // "town:pobiedziska" → photos
}

func (s *SiteData) PostsForArea(a *Area) []*Post {
    return s.postsByArea[a.Key()]  // O(1), no filtering
}

func (s *SiteData) PostsForTag(slug string) []*Post {
    return s.postsByTag[slug]
}
```

**Key difference from Crystal**: No memoized caches that build lazily.
Everything is pre-computed in Stage 2. This eliminates thread-safety
concerns — `SiteData` is fully immutable when rendering starts.

## View System: Interfaces, Not Inheritance

Crystal uses a 4-level class hierarchy (AbstractView → BaseView → PageView → ConcreteView).
Go uses flat composition with interfaces.

```go
// Renderable is anything that produces output
type Renderable interface {
    URL() string
    Render(w io.Writer) error
}

// PageRenderer wraps content in HTML page shell
type PageRenderer struct {
    data      *SiteData
    title     string
    url       string
    bundles   []string
    pageCSS   []string
    pageJS    string
    content   func(w io.Writer) error  // injection, not inheritance
}

func (p *PageRenderer) Render(w io.Writer) error {
    // Write doctype, head (bundles → CSS/JS tags), body open, nav
    p.data.Templates.Execute(w, "head", p.headData())
    // Write content
    if err := p.content(w); err != nil {
        return err
    }
    // Write footer, close
    p.data.Templates.Execute(w, "footer", p.footerData())
    return nil
}
```

**Concrete views** are just functions or thin structs:

```go
// No class — just a function that returns a Renderable
func AreaShowPage(data *SiteData, area *Area) Renderable {
    posts := data.PostsForArea(area)
    photos := data.PhotoIndex.ForArea(area)
    polygon := data.Polygons[area.Key()]

    return &PageRenderer{
        data:    data,
        title:   area.Name,
        url:     data.Router.AreaShowURL(area),
        bundles: []string{"core", "leaflet", "preact"},
        content: func(w io.Writer) error {
            // Inline JSON blob — same pattern as Crystal but simpler
            jsonData := buildAreaJSON(area, posts, photos, polygon)
            return data.Templates.Execute(w, "area/show", map[string]any{
                "area_data": jsonData,
            })
        },
    }
}
```

**Benefits over Crystal approach:**
- No 4-level inheritance chain to understand
- `content` is a closure — captures exactly what it needs
- No `@instance_variables` scattered across superclasses
- Easy to test — just call the function, check the output

## Parallel Render Engine

The heart of the rewrite. Instead of Crystal's sequential priority loop,
Go runs independent render groups concurrently.

```go
type RenderGroup struct {
    Name     string
    Priority int
    Generate func(data *SiteData) []Renderable
}

func RenderAll(data *SiteData, groups []RenderGroup, workers int) error {
    // Sort groups by priority
    sort.Slice(groups, func(i, j int) bool {
        return groups[i].Priority < groups[j].Priority
    })

    // Output channel — writer pool drains this
    outputs := make(chan OutputFile, workers*4)
    var writeWg sync.WaitGroup

    // Start writer pool
    for i := 0; i < workers; i++ {
        writeWg.Add(1)
        go func() {
            defer writeWg.Done()
            for out := range outputs {
                writeFile(out)
            }
        }()
    }

    // Render groups — parallelize WITHIN each priority level
    for _, group := range groups {
        views := group.Generate(data)
        var renderWg sync.WaitGroup
        for _, view := range views {
            renderWg.Add(1)
            go func(v Renderable) {
                defer renderWg.Done()
                var buf bytes.Buffer
                if err := v.Render(&buf); err != nil {
                    log.Printf("ERROR rendering %s: %v", v.URL(), err)
                    return
                }
                outputs <- OutputFile{Path: v.URL(), Content: buf.Bytes()}
            }(view)
        }
        renderWg.Wait() // All views in this group done before next group
    }

    close(outputs)
    writeWg.Wait()
    return nil
}
```

**Difference from Crystal**: Crystal runs 49 entries one-by-one. Go runs all
views within a priority group simultaneously, only synchronizing between groups.

## Render Groups (What to Build)

### Essential (Phase 1-3)

| Group | Priority | Views | Pages | Parallel? |
|-------|----------|-------|-------|-----------|
| Area show | 10 | 1 func × 5 types | ~120 | Yes — per area |
| Area post lists | 11 | 1 func × 5 types | ~120 | Yes — per area |
| Area galleries | 12 | 1 func × 5 types | ~120 | Yes — per area |
| Tag post lists | 13 | 1 func | ~51 | Yes — per tag |
| Tag galleries | 14 | 1 func | ~51 | Yes — per tag |
| Homepage | 20 | 1 func | 1 | No |
| Post articles | 25 | 1 func | ~730 | Yes — per post |
| Post galleries | 26 | 1 func | ~730 | Yes — per post |
| RSS + Atom | 50 | 2 funcs | 2 | Yes |
| Sitemap | 51 | 1 func | 1 | No |
| JSON endpoints | 52 | 6 funcs | 6 | Yes — per file |

### Nice to Have (Phase 4-5)

| Group | Priority | Views | Pages | Parallel? |
|-------|----------|-------|-------|-----------|
| EXIF galleries | 30 | camera, lens, iso, etc. | ~200 | Yes — per value |
| Year stats | 40 | 1 func × years | ~12 | Yes — per year |
| Towns index | 60 | 1 func | 1 | No |
| Route map | 90 | 1 func | 1 | No |
| Photo map | 91 | 1 func | 1 | No |
| POIs | 92 | 1 func | 1 | No |
| Static pages | 95 | about, more, etc. | ~5 | Yes |

### Skip Entirely

| Crystal Feature | Why Skip |
|-----------------|----------|
| Debug views (priority 100+) | Diagnostic only, use pprof instead |
| Photo analysis (pHash, color) | Experimental, not user-facing |
| Output history comparator | Nice-to-have, not needed for correctness |
| Spellcheck command | Keep as standalone Crystal tool |
| GPS geotagging | Keep as standalone Crystal tool |
| SVG map rendering (server-side) | Client-side Leaflet is better |
| Custom profiling (@[Profile]) | pprof is superior |
| ModWatcher (file change tracking) | Replace with mtime-based incremental |

## Template System: `text/template` + Cache

Crystal reads and scans templates on every call. Go compiles them once.

```go
type TemplateCache struct {
    templates *template.Template
}

func NewTemplateCache(layoutDir string) (*TemplateCache, error) {
    tmpl := template.New("").Funcs(template.FuncMap{
        "raw": func(s string) template.HTML { return template.HTML(s) },
    })

    // Parse ALL templates at startup
    err := filepath.Walk(layoutDir, func(path string, info os.FileInfo, err error) error {
        if err != nil || info.IsDir() || !strings.HasSuffix(path, ".html") {
            return err
        }
        name, _ := filepath.Rel(layoutDir, path)
        name = strings.TrimSuffix(name, ".html")
        content, _ := os.ReadFile(path)
        // Convert {{ var }} to {{ .var }} for Go templates
        converted := convertPlaceholders(string(content))
        template.Must(tmpl.New(name).Parse(converted))
        return nil
    })
    return &TemplateCache{templates: tmpl}, err
}

func (tc *TemplateCache) Execute(w io.Writer, name string, data any) error {
    return tc.templates.ExecuteTemplate(w, name, data)
}
```

**Or with embed.FS** (compile templates into binary):

```go
//go:embed data/layout/**/*.html
var layoutFS embed.FS

func NewTemplateCacheFromEmbed() (*TemplateCache, error) {
    tmpl := template.New("")
    fs.WalkDir(layoutFS, "data/layout", func(path string, d fs.DirEntry, err error) error {
        // same as above but reads from embedded FS
    })
    return &TemplateCache{templates: tmpl}, nil
}
```

## Image Pipeline: Worker Pool

The biggest performance bottleneck (75% of Crystal build time).
Go can process images in parallel with a bounded worker pool.

```go
type ImageJob struct {
    SrcPath  string
    DstPath  string
    Width    int
    Height   int
    Quality  int
    Format   string // "jpeg" or "avif"
}

func ProcessImages(jobs []ImageJob, workers int) error {
    ch := make(chan ImageJob, workers*2)
    var wg sync.WaitGroup
    var errOnce sync.Once
    var firstErr error

    // Start worker pool
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range ch {
                if err := resizeImage(job); err != nil {
                    errOnce.Do(func() { firstErr = err })
                }
            }
        }()
    }

    // Feed jobs
    for _, job := range jobs {
        ch <- job
    }
    close(ch)
    wg.Wait()
    return firstErr
}
```

**Pure Go option**: `github.com/disintegration/imaging` — no ImageMagick dependency.
AVIF via `github.com/nicholasgasior/goavif` or shell out to `cavif`.

**Estimated speedup**: 45s → 5-8s on 8 cores (image processing is CPU-bound,
scales linearly with cores).

## Incremental Builds

Crystal rebuilds everything every time. Go can track what changed.

```go
type BuildCache struct {
    FileHashes map[string]string `json:"file_hashes"` // path → sha256
    LastBuild  time.Time         `json:"last_build"`
}

func (bc *BuildCache) Changed(path string) bool {
    current := hashFile(path)
    previous, exists := bc.FileHashes[path]
    if !exists || current != previous {
        bc.FileHashes[path] = current
        return true
    }
    return false
}

// In main pipeline:
func determineChanges(cache *BuildCache, postDir, configDir string) ChangeSet {
    var cs ChangeSet
    // Check posts
    filepath.Walk(postDir, func(path string, info os.FileInfo, _ error) error {
        if cache.Changed(path) {
            cs.Posts = true
            cs.ChangedPosts = append(cs.ChangedPosts, path)
        }
        return nil
    })
    // Check configs
    filepath.Walk(configDir, func(path string, info os.FileInfo, _ error) error {
        if cache.Changed(path) {
            cs.Yamls = true
        }
        return nil
    })
    return cs
}
```

**Impact**: For editing a single post, only re-render that post + affected
area pages + feeds. Skip everything else. Build time: 60s → <1s.

## Router: Same Logic, Simpler Code

```go
type AreaLinkTarget int

const (
    LinkToShow AreaLinkTarget = iota
    LinkToPostList
    LinkToGallery
)

type Router struct {
    LinkTarget AreaLinkTarget
}

// Polish grammatical cases built into AreaType
type AreaType struct {
    Slug       string // "town"
    Nominative string // "gmina"
    Genitive   string // "gminy"
}

var (
    Town       = AreaType{"town", "gmina", "gminy"}
    County     = AreaType{"county", "powiat", "powiatu"}
    Voivodeship = AreaType{"voivodeship", "wojewodztwo", "wojewodztwa"}
    MesoRegion = AreaType{"meso_region", "mezoregion", "regionu"}
    MacroRegion = AreaType{"macro_region", "makroregion", "obszaru"}
)

func (r *Router) AreaShowURL(a *Area) string {
    return fmt.Sprintf("/%s/%s.html", a.Type.Nominative, a.Slug)
}

func (r *Router) AreaPostListURL(a *Area) string {
    return fmt.Sprintf("/wpisy-dla/%s/%s.html", a.Type.Genitive, a.Slug)
}

func (r *Router) AreaLinkURL(a *Area) string {
    switch r.LinkTarget {
    case LinkToPostList:
        return r.AreaPostListURL(a)
    case LinkToGallery:
        return r.AreaGalleryURL(a)
    default:
        return r.AreaShowURL(a)
    }
}
```

## Photo Index: Spatial + EXIF Lookups

Replace Crystal's `AreaPhotoSelector` (mutable, tracks used photos)
with an immutable spatial index.

```go
type PhotoIndex struct {
    all      []*Photo
    spatial  *SpatialGrid          // lat/lon → photos
    byArea   map[string][]*Photo   // area key → photos
    byCamera map[string][]*Photo   // camera model → photos
    byLens   map[string][]*Photo   // lens model → photos
    byISO    map[int][]*Photo      // ISO value → photos
    byYear   map[int][]*Photo      // year → photos
}

// Build once from all posts — O(n) where n = total photos
func BuildPhotoIndex(posts []*Post) *PhotoIndex {
    idx := &PhotoIndex{
        byArea:   make(map[string][]*Photo),
        byCamera: make(map[string][]*Photo),
        // ...
    }
    for _, post := range posts {
        for _, photo := range post.Photos {
            idx.all = append(idx.all, photo)
            if photo.Lat != 0 {
                idx.spatial.Insert(photo)
            }
            for _, areaKey := range photo.AreaKeys {
                idx.byArea[areaKey] = append(idx.byArea[areaKey], photo)
            }
            if photo.Camera != "" {
                idx.byCamera[photo.Camera] = append(idx.byCamera[photo.Camera], photo)
            }
            // ... same for lens, ISO, etc.
        }
    }
    return idx
}

// Best photo for area — deterministic, no mutable state
func (idx *PhotoIndex) BestForArea(area *Area, exclude map[string]bool) *Photo {
    photos := idx.byArea[area.Key()]
    sort.Slice(photos, func(i, j int) bool {
        return photos[i].Points > photos[j].Points
    })
    for _, p := range photos {
        if !exclude[p.ID()] {
            return p
        }
    }
    return nil
}
```

**Key difference**: Crystal's `AreaPhotoSelector` mutates internal state
(`@used_photos`), making it unsafe for parallel use. Go's `PhotoIndex`
is immutable — the `exclude` set is passed in per-call, owned by the caller.

## CLI: cobra + Built-in Dev Server

```go
func main() {
    root := &cobra.Command{Use: "odkrywajac"}

    root.AddCommand(
        &cobra.Command{
            Use:   "build",
            Short: "Build the site",
            RunE:  buildCmd,
        },
        &cobra.Command{
            Use:   "serve",
            Short: "Build and serve with live reload",
            RunE:  serveCmd,
        },
        &cobra.Command{
            Use:   "watch",
            Short: "Watch for changes and rebuild",
            RunE:  watchCmd,
        },
    )

    root.Execute()
}

func serveCmd(cmd *cobra.Command, args []string) error {
    // Build first
    if err := buildSite(); err != nil {
        return err
    }
    // Serve
    fs := http.FileServer(http.Dir("env/dev/public"))
    log.Println("Serving on http://localhost:5001")
    return http.ListenAndServe(":5001", fs)
}

func watchCmd(cmd *cobra.Command, args []string) error {
    watcher, _ := fsnotify.NewWatcher()
    watcher.Add("env/dev/posts/")
    watcher.Add("data/config/")

    for event := range watcher.Events {
        if event.Op&fsnotify.Write == fsnotify.Write {
            log.Printf("Changed: %s, rebuilding...", event.Name)
            buildSite()
        }
    }
    return nil
}
```

**No more**: `python3 -m http.server` + manual `make dev-render-local`.
One command: `odkrywajac serve` — builds, serves, watches.

## Project Structure

```
odkrywajac-go/
├── cmd/
│   └── odkrywajac/
│       └── main.go              # CLI entry point
├── internal/
│   ├── model/
│   │   ├── post.go              # Post struct + YAML parsing
│   │   ├── area.go              # Area struct + types
│   │   ├── photo.go             # Photo struct + EXIF
│   │   ├── tag.go               # Tag struct
│   │   └── config.go            # Site config
│   ├── loader/
│   │   ├── posts.go             # Parallel post loader
│   │   ├── areas.go             # Area YAML loader
│   │   ├── tags.go              # Tag loader
│   │   ├── exif.go              # EXIF cache loader
│   │   └── templates.go         # Template compiler
│   ├── index/
│   │   ├── site_data.go         # SiteData (frozen state)
│   │   ├── photo_index.go       # Spatial + EXIF photo index
│   │   └── nav_stats.go         # Computed site statistics
│   ├── render/
│   │   ├── engine.go            # Parallel render engine
│   │   ├── page.go              # PageRenderer (HTML shell)
│   │   ├── writer.go            # File writer pool
│   │   └── bundles.go           # Asset bundle resolver
│   ├── view/
│   │   ├── area.go              # Area show/list/gallery
│   │   ├── tag.go               # Tag list/gallery
│   │   ├── home.go              # Homepage
│   │   ├── post.go              # Post article + gallery
│   │   ├── feed.go              # RSS, Atom, sitemap
│   │   ├── json.go              # JSON endpoints
│   │   ├── stats.go             # Year reports
│   │   ├── gallery.go           # EXIF-based galleries
│   │   └── static.go            # About, map, etc.
│   ├── image/
│   │   ├── resizer.go           # Image resize worker pool
│   │   └── sizes.go             # Size definitions
│   ├── router/
│   │   └── router.go            # URL generation
│   └── cache/
│       └── build_cache.go       # Incremental build cache
├── layout/                      # HTML templates (copied from Crystal)
├── config/                      # YAML configs (shared with Crystal)
├── go.mod
├── go.sum
└── Makefile
```

**Key point**: `config/` and `layout/` are symlinked to the Crystal project's
`data/config/` and `data/layout/`. Both engines read the same data, produce
the same output. This allows side-by-side comparison.

## Implementation Phases

### Phase 1: Skeleton + Data Loading (Week 1-2)

**Goal**: Load all data, build SiteData, print stats.

```
[ ] Go module init, project structure
[ ] Post struct + YAML front matter parser
[ ] Parallel post loader (730 files, 8 workers)
[ ] Area struct + YAML loader (5 types, 5000+ areas)
[ ] Tag struct + loader
[ ] EXIF struct + cache loader
[ ] SiteData builder (indexes, lookups)
[ ] PhotoIndex (spatial + EXIF grouping)
[ ] CLI with `build` command (prints stats only)
[ ] Unit tests for all loaders
```

**Validation**: Run loader, compare entity counts with Crystal output.

### Phase 2: Render Engine + First Views (Week 3-4)

**Goal**: Render real HTML pages. Start with area pages (highest volume).

```
[ ] Template cache (parse all layout/*.html)
[ ] Asset bundle resolver (parse asset_bundles.yml)
[ ] PageRenderer (HTML shell: head, nav, footer)
[ ] Router (all URL generation)
[ ] Parallel render engine (fan-out + writer pool)
[ ] AreaShowView — area detail pages
[ ] AreaPostListView — post list per area
[ ] AreaGalleryView — photo gallery per area
[ ] HTML validator (basic: title exists, no empty hrefs)
[ ] Compare output with Crystal (diff HTML files)
```

**Validation**: `diff -r go-output/ crystal-output/` for area pages.

### Phase 3: Posts + Core Views (Week 5-6)

**Goal**: Render post articles, homepage, feeds — enough for a working site.

```
[ ] Post article renderer (markdown → HTML)
[ ] Post gallery renderer
[ ] Tag post list + gallery views
[ ] Homepage view
[ ] RSS feed generator
[ ] Atom feed generator
[ ] Sitemap generator
[ ] JSON endpoints (homepage, map, photos, etc.)
[ ] robots.txt
[ ] Incremental build cache
```

**Validation**: Full site builds, serve with `odkrywajac serve`, compare with Crystal.

### Phase 4: Image Pipeline (Week 7)

**Goal**: Parallel image processing — the biggest speedup opportunity.

```
[ ] Image resizer (pure Go or ImageMagick wrapper)
[ ] Worker pool (NumCPU workers)
[ ] 4 sizes: article, card, grid, thumbnail
[ ] AVIF generation (shell out to cavif or pure Go)
[ ] Skip unchanged images (mtime check)
[ ] Progress reporting
```

**Validation**: Compare image output quality with Crystal's ImageMagick output.

### Phase 5: Extended Views + Polish (Week 8-9)

**Goal**: Feature completeness for non-debug views.

```
[ ] Year stats report views
[ ] EXIF gallery views (camera, lens, ISO, etc.)
[ ] Towns index page (Preact — reuse existing JS)
[ ] Route map page (Leaflet — reuse existing JS)
[ ] Photo map page
[ ] POIs page
[ ] Static pages (about, more, ideas)
[ ] Tag redirect views (302)
[ ] Watch mode (fsnotify)
[ ] Dev server with live reload
```

### Phase 6: Benchmarking + Optimization (Week 10)

**Goal**: Measure, optimize, document.

```
[ ] Benchmark: Crystal vs Go (full build, incremental, image processing)
[ ] pprof profiling (CPU, memory, goroutine)
[ ] Optimize hot paths (template rendering, JSON generation)
[ ] Race condition testing (go test -race ./...)
[ ] E2E tests (same Playwright suite, point at Go output)
[ ] Document architecture and usage
```

## Expected Performance

| Metric | Crystal (current) | Go (expected) | Speedup |
|--------|-------------------|---------------|---------|
| Compilation | 15-30s | 1-2s | 15x |
| Post loading (730 files) | ~2s sequential | ~0.3s parallel | 7x |
| YAML loading | ~0.5s | ~0.3s | 2x |
| View rendering (600+ pages) | ~8s sequential | ~2s parallel | 4x |
| Image processing (117K ops) | ~45s sequential | ~6s parallel | 8x |
| File writing (412 files) | ~1s sequential | ~0.2s parallel | 5x |
| **Full build** | **~60s** | **~9s** | **7x** |
| **Incremental (1 post)** | **~60s** (full rebuild) | **<1s** | **60x+** |

The incremental build is the real killer feature — Crystal rebuilds everything,
Go only touches changed files.

## Shared Resources with Crystal

Both engines coexist in the same repo. Go reads the same input data:

```
data/config/          → shared YAML configs (areas, tags, etc.)
data/layout/          → shared HTML templates
data/assets/          → shared CSS, JS, images
data/external/        → shared polygon data
env/dev/posts/        → shared markdown posts
env/dev/cache/        → shared EXIF caches
```

Go writes to a **separate output directory**:

```
env/dev/public/local/    → Crystal output (existing)
env/dev/public/go/       → Go output (new)
```

This allows `diff -r` comparison between the two engines at any point.

## What's Fundamentally Better

| Aspect | Crystal Approach | Go Approach |
|--------|-----------------|-------------|
| **Parallelism** | Sequential loop over 49 entries | Fan-out per priority group, channel-based writer pool |
| **State management** | Mutable caches on RenderContext, lazy init, `.not_nil!` panics | Immutable SiteData built once, no nil surprises |
| **Template loading** | Read + regex scan on every call | Compile once at startup, execute from memory |
| **Photo selection** | Mutable `@used_photos` tracker (not thread-safe) | Immutable index, caller owns exclude set |
| **Incremental builds** | None — full rebuild every time | File hash tracking, skip unchanged work |
| **Dev workflow** | `make dev-render-local` + `python3 -m http.server` | `odkrywajac serve` — build, watch, serve |
| **Error handling** | `.not_nil!` panics at runtime | Explicit errors at compile time |
| **View architecture** | 4-level inheritance, scattered @ivars | Flat functions + PageRenderer composition |
| **Binary** | Needs libc, separate template/config files | Single static binary with embedded assets |
| **Profiling** | Custom `@[Profile]` macro, manual timing | Built-in pprof (CPU, memory, goroutine, trace) |

## Open Decisions

These don't need answering now — decide when you get there:

- [ ] Pure Go image resizing (`imaging`) vs shell out to ImageMagick?
- [ ] `goldmark` for markdown or simpler custom parser (posts use custom `{% photo %}` syntax)?
- [ ] Embed templates in binary (`embed.FS`) or keep as external files for easier editing?
- [ ] How to handle `{% photo %}` custom syntax — preprocessor or custom markdown extension?
- [ ] Keep `preact` JSX components as-is (just copy JS files) or rewrite to Go templates + htmx?
