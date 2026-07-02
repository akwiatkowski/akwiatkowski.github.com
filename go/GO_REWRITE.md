# Go Rewrite Analysis

Research document for rewriting the Crystal static site generator in Go.
Goal: learning Go, exploring architectural improvements, not production urgency.

## Codebase Scope

| Component | Crystal LOC | Go Estimate | Notes |
|-----------|-------------|-------------|-------|
| Core (blog, renderer, contexts) | 1,800 | ~2,500 | Struct setup, error handling |
| Views (42 classes) | 7,300 | ~10,000 | Largest chunk, mostly mechanical |
| Services (router, validators, etc.) | 8,700 | ~12,000 | Medium complexity |
| Models/Entities (12 types) | 1,700 | ~2,400 | Struct + YAML/JSON tags |
| Tremolite (markdown, posts) | 1,700 | ~2,400 | Replace with goldmark |
| View Registry + coordinator | 1,800 | ~2,000 | Nearly 1:1 translation |
| Commands (pipeline, tools) | 1,100 | ~1,500 | CLI wrappers |
| Tests (64 spec files, 623 tests) | 7,200 | ~9,000 | Go testing is verbose |
| **Total** | **~25,300** | **~42,000** | ~1.6x expansion |

Go is ~1.4-1.7x more verbose than Crystal due to explicit error handling, no implicit
returns, no macros, and no blocks.

## Effort Estimate

| Phase | What | Effort | Weeks |
|-------|------|--------|-------|
| 1. Core models | Post, AreaEntity, PhotoEntity, TagEntity, etc. | 12h | 1 |
| 2. Data loaders | DataManager, YAML parsing, EXIF, caches | 20h | 1 |
| 3. Services | Router, Registry, HtmlProcessor, AssetBundleLoader | 18h | 1 |
| 4. View base + templates | BaseView, PageView, template loading | 16h | 1 |
| 5. View implementations | All 42 views | 40h | 2 |
| 6. Post rendering pipeline | Image resizing, EXIF, orchestration | 20h | 1 |
| 7. Registry setup | Wire all 49 entries | 10h | 0.5 |
| 8. Tests | Crystal specs → Go tests | 30h | 1 |
| 9. E2E + CLI | Playwright stays JS; Go entry points | 23h | 1 |
| **Total** | | **~190h** | **~9-10 weeks** |

This assumes part-time/free-time work. Some phases can be skipped or simplified
(see "Features to Drop" below).

## What Go Does Better

### 1. Concurrency (biggest win)

Crystal currently renders everything **sequentially** — zero use of spawn/fibers/channels.
Go makes parallelism trivial:

```go
var wg sync.WaitGroup
for _, entry := range registry.EntriesForPriority(priority) {
    wg.Add(1)
    go func(e Entry) {
        defer wg.Done()
        e.Block(ctx)
    }(entry)
}
wg.Wait()
```

**Parallelizable work:**
- All 42 views within the same priority group (independent outputs)
- Image resizing (per-post, embarrassingly parallel)
- JSON generators (homepage, photos, trains, etc.)
- HTML validation (per-file)

Potential speedup: **3-6x** on multi-core machines for the render phase.

### 2. Compilation Speed

Crystal compile time is slow (~15-30s for type checking alone, minutes for release build).
Go compiles the entire project in **1-2 seconds**. This makes the dev loop much tighter,
especially for a project you're iterating on frequently.

### 3. Single Binary Distribution

Both Crystal and Go produce static binaries, but Go's are:
- Truly static with `CGO_ENABLED=0` (no libc dependency)
- Cross-compilable (`GOOS=linux GOARCH=arm64 go build`)
- Embeddable assets via `embed.FS` (templates, config, CSS can live inside the binary)

```go
//go:embed data/layout/**/*.html
var templates embed.FS

//go:embed data/config/asset_bundles.yml
var assetBundlesYML []byte
```

### 4. Ecosystem & Tooling

- `go fmt` — enforced formatting (no style debates)
- `go vet` + `golangci-lint` — catches bugs Crystal's compiler misses
- `go test -race` — race condition detector (invaluable when adding concurrency)
- `pprof` — built-in CPU/memory profiling (replaces custom `@[Profile]` macro)
- `go generate` — code generation for repetitive patterns
- Massive library ecosystem (Hugo's codebase as reference for SSG patterns)

### 5. Error Handling Explicitness

Crystal's `.not_nil!` pattern (used extensively) panics at runtime with unhelpful errors.
Go forces explicit error handling:

```go
// Crystal: @photo.not_nil!.grid_src  (runtime panic if nil)
// Go:
photo, err := post.HeadPhoto()
if err != nil {
    return fmt.Errorf("post %s has no photo: %w", post.Slug, err)
}
gridSrc := photo.GridSrc()
```

More verbose, but crashes become impossible (or at least well-described).

### 6. Built-in HTTP Server

For the dev workflow, Go's `net/http` is production-grade:

```go
http.Handle("/", http.FileServer(http.Dir("env/dev/public")))
log.Fatal(http.ListenAndServe(":5001", nil))
```

No need for `python3 -m http.server`. Could even add live-reload with
`fsnotify` watching output files.

### 7. Testing

Go's `testing` package + `testify` is more ergonomic for table-driven tests:

```go
func TestRouter_AreaShowURL(t *testing.T) {
    tests := []struct{
        areaType string; slug string; want string
    }{
        {"town", "pobiedziska", "/gmina/pobiedziska.html"},
        {"county", "poznanski", "/powiat/poznanski.html"},
    }
    for _, tt := range tests {
        got := router.AreaShowURL(tt.areaType, tt.slug)
        assert.Equal(t, tt.want, got)
    }
}
```

## What Go Does Worse

### 1. Verbosity (biggest pain)

Every Crystal one-liner becomes 3-5 lines in Go:

```crystal
# Crystal
posts.select(&.published?).sort_by(&.date).reverse.first(10)
```

```go
// Go
var published []*Post
for _, p := range posts {
    if p.Published {
        published = append(published, p)
    }
}
sort.Slice(published, func(i, j int) bool {
    return published[i].Date.After(published[j].Date)
})
if len(published) > 10 {
    published = published[:10]
}
```

With Go 1.21+ generics this improves slightly (`slices.SortFunc`, `slices.Filter` etc.)
but it's still more code.

### 2. No Macros / Metaprogramming

Crystal patterns that have no Go equivalent:
- `@[Profile(category: "posts")]` — auto-wrapping methods with timing
- `include YAML::Serializable` — auto-generating marshal/unmarshal
- `getter!` — nilable field with non-nil getter
- `macro finished` — compile-time code generation

**Workarounds:**
- Profiling: use `pprof` (better tool anyway) or manual wrapper functions
- Serialization: struct tags (`json:"field"` / `yaml:"field"`) — less magic but works
- Getters: just write the methods (or use code generation)

### 3. No Union Types

Crystal's `String | Int32 | Nil` has no Go equivalent. Options:
- `interface{}` / `any` — loses type safety
- Separate fields — verbose but safe
- Option pattern — custom `Optional[T]` generic type

### 4. Template System is Clunkier

Crystal's string interpolation is elegant for HTML:

```crystal
String.build do |s|
  s << "<h1>#{@title}</h1>"
  s << "<ul>"
  @posts.each { |p| s << "<li>#{p.title}</li>" }
  s << "</ul>"
end
```

Go's `html/template` is safe but rigid:

```go
const tmpl = `<h1>{{.Title}}</h1>
<ul>
{{range .Posts}}<li>{{.Title}}</li>{{end}}
</ul>`
```

The existing `load_html` template system (94 uses of `{{ var }}` placeholders) translates
almost directly to Go's `text/template` though.

### 5. No Method Chaining

Crystal's fluent API style doesn't work in Go due to error returns:

```crystal
# Crystal
context.areas_with_posts.select(&.town?).sort_by(&.name)
```

```go
// Go — must handle errors at each step
areas, err := ctx.AreasWithPosts()
if err != nil { return err }
var towns []*Area
for _, a := range areas {
    if a.IsTown() {
        towns = append(towns, a)
    }
}
sort.Slice(towns, func(i, j int) bool {
    return towns[i].Name < towns[j].Name
})
```

### 6. No Default Parameter Values

Crystal methods with defaults need Go alternatives:

```crystal
# Crystal
def render(format = "html", validate = true)
```

```go
// Go — functional options or separate methods
type RenderOpts struct {
    Format   string // default "html"
    Validate bool   // default true
}

func (r *Renderer) Render(opts RenderOpts) error {
    if opts.Format == "" { opts.Format = "html" }
    // ...
}
```

## Translation Patterns

### Crystal → Go Cheat Sheet

| Crystal | Go |
|---------|-----|
| `class Foo; end` | `type Foo struct{}` |
| `getter name : String` | `Name string` (exported field) |
| `getter! db : ExifDb?` | `DB *ExifDb` + nil check |
| `include Module` | Embed struct or implement interface |
| `@cache \|\|= compute()` | `sync.Once` or lazy init with mutex |
| `String.build { \|s\| ... }` | `strings.Builder{}` |
| `JSON.build { \|j\| ... }` | `json.Marshal(struct{}{})` |
| `load_html("tpl", data)` | `template.ExecuteTemplate(w, "tpl", data)` |
| `Array(T).new` | `make([]T, 0)` |
| `Hash(K,V).new` | `make(map[K]V)` |
| `foo.try(&.bar)` | `if foo != nil { foo.Bar() }` |
| `foo.not_nil!` | `if foo == nil { panic(...) }` |
| `.select { \|x\| ... }` | `for` loop with `append` |
| `.map { \|x\| ... }` | `for` loop with `append` |
| `.sort_by(&.field)` | `sort.Slice(s, func(i,j int) bool{...})` |
| `spawn { ... }` | `go func() { ... }()` |
| `Channel(T).new` | `make(chan T)` |
| `File.read(path)` | `os.ReadFile(path)` |
| `Dir.glob(pattern)` | `filepath.Glob(pattern)` |
| `YAML.parse(str)` | `yaml.Unmarshal([]byte(str), &out)` |

### View Base Class

```go
// BaseView provides common rendering infrastructure
type BaseView struct {
    ctx    *RenderContext
    url    string
    title  string
}

func (v *BaseView) AssetBundles() []string {
    return []string{"core"}
}

// PageView adds HTML page wrapper (header, footer, nav)
type PageView struct {
    BaseView
}

func (v *PageView) Render(w io.Writer) error {
    // Write top + head + content + footer
    if err := v.writeHead(w); err != nil { return err }
    if err := v.writeContent(w); err != nil { return err }
    return v.writeFooter(w)
}

// Concrete view
type AreaShowView struct {
    PageView
    area  *AreaEntity
    posts []*Post
}

func (v *AreaShowView) AdditionalBundles() []string {
    return []string{"leaflet", "react-runtime"}
}
```

### View Registry

```go
type ViewRegistry struct {
    entries []Entry
}

type Entry struct {
    Name      string
    DependsOn []string
    Priority  int
    IsTask    bool
    Run       func(ctx *BuildContext) error
}

func (r *ViewRegistry) Register(name string, deps []string, prio int, fn func(*BuildContext) error) {
    r.entries = append(r.entries, Entry{
        Name: name, DependsOn: deps, Priority: prio, Run: fn,
    })
}

func (r *ViewRegistry) Task(name string, deps []string, prio int, fn func(*BuildContext) error) {
    r.entries = append(r.entries, Entry{
        Name: name, DependsOn: deps, Priority: prio, IsTask: true, Run: fn,
    })
}
```

### Router

```go
type Router struct {
    areaLinkTarget AreaLinkTarget
}

func (r *Router) AreaShowURL(area *AreaEntity) string {
    return fmt.Sprintf("/%s/%s.html", area.Type.Nominative(), area.Slug)
}

func (r *Router) AreaPostListURL(area *AreaEntity) string {
    return fmt.Sprintf("/wpisy-dla/%s/%s.html", area.Type.Genitive(), area.Slug)
}

func (r *Router) AreaGalleryURL(area *AreaEntity) string {
    return fmt.Sprintf("/galeria/%s/%s.html", area.Type.Genitive(), area.Slug)
}

func (r *Router) AreaLinkURL(area *AreaEntity) string {
    switch r.areaLinkTarget {
    case AreaLinkTargetPostList:
        return r.AreaPostListURL(area)
    case AreaLinkTargetGallery:
        return r.AreaGalleryURL(area)
    default:
        return r.AreaShowURL(area)
    }
}
```

## Features to Drop or Simplify

For a research/learning rewrite, consider cutting scope:

| Feature | Crystal LOC | Recommendation |
|---------|-------------|----------------|
| Photo analysis (pHash, color similarity) | ~800 | **Drop** — debug feature, not user-facing |
| Debug views (10+ diagnostic pages) | ~600 | **Drop** — rebuild only if needed |
| Output history comparator | ~300 | **Drop** — nice-to-have, not essential |
| Spellcheck command | ~200 | **Drop** — standalone tool, keep as Crystal |
| GPS geotagging script | ~400 | **Drop** — standalone, keep as Crystal |
| SVG map rendering (server-side) | ~1,500 | **Simplify** — consider client-side only |
| Custom profiling macro | ~100 | **Replace** with `pprof` |
| 302 redirect views | ~50 | **Simplify** — nginx config instead |

Dropping these saves ~4,000 LOC of Crystal (~6,500 Go lines), reducing effort by ~30%.

## Dependency Mapping

| Crystal Shard / Stdlib | Go Equivalent | Maturity |
|------------------------|---------------|----------|
| `tremolite` (custom markdown) | `github.com/yuin/goldmark` | Excellent |
| `crystal_gpx` | `github.com/tkrajina/gpxgo` | Good |
| `YAML::Serializable` | `gopkg.in/yaml.v3` + struct tags | Excellent |
| `JSON::Serializable` | `encoding/json` + struct tags | Excellent |
| `String.build` | `strings.Builder` | Stdlib |
| `File`, `Dir` | `os`, `path/filepath` | Stdlib |
| `Time` | `time` | Stdlib |
| `Regex` | `regexp` | Stdlib (RE2, no backrefs) |
| `HTTP::Server` | `net/http` | Stdlib |
| `Set` | `map[string]bool` | Manual |
| EXIF reading | `github.com/rwcarlsen/goexif` | Good |
| Image resizing | `github.com/disintegration/imaging` | Good (pure Go) |
| CLI framework | `github.com/spf13/cobra` | Excellent |
| Testing assertions | `github.com/stretchr/testify` | Excellent |

**Bonus:** Go's `imaging` library could replace shelling out to ImageMagick,
making the binary fully self-contained.

## Recommended Build Order

Start with a vertical slice — one view rendered end-to-end — before porting everything.

```
Week 1: Vertical slice
  ├── Post struct + YAML loading (1 post)
  ├── BaseView + PageView
  ├── Template loader (load_html equivalent)
  ├── One simple view (e.g., AboutView)
  └── CLI entry point that renders 1 HTML file

Week 2: Core models
  ├── AreaEntity, AreaType (with Polish inflections)
  ├── TagEntity, PhotoEntity, ExifEntity
  ├── PostCollection (load all posts)
  └── DataManager (entity loading, config)

Week 3: Services
  ├── Router (URL generation)
  ├── AssetBundleLoader (YAML config → CSS/JS lists)
  ├── ViewRegistry + RenderCoordinator
  └── HtmlProcessor + validators

Week 4-5: Views (batch by priority group)
  ├── Area views (show, post list, gallery)
  ├── Home + map views
  ├── Gallery views
  ├── Stats views
  ├── Feed views (RSS, Atom, JSON, sitemap)
  └── Index + static views

Week 6: Pipeline
  ├── PostRenderer (resize, EXIF, render)
  ├── Blog orchestration
  └── Build commands

Week 7: Concurrency
  ├── Parallel view rendering (goroutines per priority group)
  ├── Parallel image resizing
  ├── Race condition testing (go test -race)
  └── Benchmark: Crystal vs Go render times

Week 8: Tests + polish
  ├── Port Crystal specs → Go tests
  ├── Verify E2E tests pass (same Playwright suite)
  └── Makefile, CI, documentation
```

## Architecture Improvements to Consider

Things that would be natural to improve during a rewrite:

1. **Incremental builds** — track file mtimes, only re-render changed posts/views.
   Go's `os.Stat` + in-memory cache makes this straightforward.

2. **Watch mode** — `fsnotify` + auto-rebuild on file changes.
   Combined with built-in HTTP server, this replaces the Python server + manual rebuild.

3. **`embed.FS` for templates** — compile templates into the binary.
   Single binary deploys, no need to ship data/layout/ separately.

4. **Structured logging** — `slog` (Go 1.21+) replaces `puts`-style logging.
   Filter by level, output JSON for parsing, measure timing natively.

5. **Config validation at startup** — Go's strict typing catches YAML mismatches
   immediately. Crystal's more permissive parsing delays errors to render time.

6. **Plugin system** — Go's `plugin` package or interface-based registration
   could allow adding views without modifying core code.

## Open Questions

- [ ] Keep JSX/Preact frontend as-is, or switch to Go templates + htmx?
- [ ] Use Hugo as a library/reference, or build from scratch?
- [ ] Port the GEOS-based area matching (requires CGo) or use pure Go geo library?
- [ ] Keep Makefile or switch to `go:generate` + `go build`?
- [ ] Monorepo (Go + JS + CSS) or separate frontend?

## Summary

| Aspect | Crystal (current) | Go (rewrite) |
|--------|-------------------|--------------|
| Lines of code | ~25K | ~35-42K |
| Compile time | 15-30s (check), minutes (release) | 1-2s |
| Render concurrency | Sequential | Parallel (goroutines) |
| Binary portability | libc dependent | Fully static |
| String manipulation | Excellent | Adequate |
| Error handling | `.not_nil!` panics | Explicit, verbose |
| Metaprogramming | Macros, annotations | Code generation |
| Ecosystem size | Small | Massive |
| Learning value | Already known | New language |

**Bottom line:** The rewrite is feasible in ~8-10 weeks. The main tangible benefits
are parallel rendering (3-6x speedup), instant compilation, and learning Go.
The main cost is verbosity — expect 60% more code for the same functionality.
Start with a vertical slice (1 view, end-to-end) to validate the approach.
