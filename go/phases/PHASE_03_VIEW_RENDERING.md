# Phase 3: View Rendering & Template System

## Goal

Build the rendering engine that turns SiteData (from Phase 2) into HTML/JSON/XML
output files. This is the core of the blog engine — everything before this was
data preparation, everything after this is adding more view types.

## What Crystal Does (and what we improve)

**Crystal's problems:**
- Sequential priority loop: 49 entries run one-by-one
- BaseView → PageView → ConcreteView inheritance chain (4 levels deep)
- Templates loaded from disk on every call (regex `{{ var }}` replacement)
- HTML built by string concatenation — mixing string building with template files
- No reusable components — photo grid HTML duplicated across views
- No HTML formatting — output is unindented, hard to debug
- File always written (no change detection)

**Go's approach:**
- Parallel fan-out: views within a priority group render concurrently
- **templ components** — type-safe, compiled HTML (no templates on disk, no inheritance)
- **Reusable partials** — `PhotoCard`, `PostCard`, `PhotoGrid` used everywhere
- **HTML pretty-printing** — `golang.org/x/net/html` re-serializes with indentation before saving
- **Build manifest** — SHA256 per output file, enables future FTP sync of changed files only
- Render and write decoupled via channel (render goroutines → writer pool)

## Key Decision: templ Instead of Template Files

Crystal has `data/layout/*.html` files loaded at runtime with `{{ var }}` replacement.
Go eliminates this entirely. All HTML is written as **templ components** — `.templ` files
that compile to type-safe Go functions.

**No more `data/layout/` dependency.** The Go version has zero template files on disk.

**Build step:** `templ generate` compiles `.templ` → `_templ.go` (~150ms for all files).
Generated `_templ.go` files are committed to git, so `go build` works without templ installed.

**Workflow:**
```
1. Edit .templ file
2. templ generate          # ~150ms, or use watch mode
3. go build / go run       # normal Go build
```

## Key Decision: Page Titles in templ Components

Crystal stores page titles and background images in `config.yml`. Go moves
these to the templ components themselves — each view owns its metadata.

**Rationale:** For a single-language site, there's no reason to externalize
page-level strings to a YAML file. templ components are the natural owner
of "what this page is called."

Example:
```go
// internal/view/homepage.go
func HomepagePage(data *SiteData) Renderable {
    return &HTMLPage{
        url: "/index.html",
        page: PageData{
            Title:   "Odkrywając Polskę",  // hardcoded, not from config
            // ...
        },
        content: views.HomepageContent(data),
    }
}
```

## Key Decision: Static Pages as templ Components

Crystal renders `data/pages/about.md`, `en.md`, `todo_notes.md` as pages.
Go converts these to templ components — the content is stable Polish text that
doesn't change often enough to justify a markdown file.

```templ
// templates/views/about.templ
templ AboutContent() {
    <article class="about-page">
        <h1>O mnie</h1>
        <p>Aleksander Kwiatkowski — blog podróżniczy...</p>
        // ... stable content, rarely changes
    </article>
}
```

## Architecture Overview

```
SiteData (frozen, immutable, includes NavStats)
    │
    ▼
┌─────────────────────────────────────┐
│ ViewRegistry                        │
│                                     │
│ Groups (sorted by priority):        │
│  P10: Area show pages   (N views)   │
│  P11: Area post lists   (N views)   │
│  P12: Area galleries    (N views)   │
│  P13: Tag post lists    (N views)   │
│  P20: Homepage          (1 view)    │
│  P25: Post articles     (N views)   │
│  P50: Feeds (RSS, Atom) (N views)   │
│  P90: Static pages      (N views)   │
│  ...                                │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ RenderEngine                        │
│                                     │
│ For each priority group:            │
│   1. Generate []Renderable          │
│   2. Fan out to N render goroutines │
│   3. Each calls templ component     │
│   4. Pretty-print HTML              │
│   5. Send OutputFile to chan        │
│   6. Wait for group to complete     │
│                                     │
│ Writer pool (4 goroutines):         │
│   Drains chan OutputFile             │
│   Skip if SHA256 unchanged          │
│   Atomic write (tmp + rename)       │
│   Update build manifest             │
│                                     │
│ Output: env/{env}/public/go/        │
└─────────────────────────────────────┘
```

## Requirements

### R1: templ Component System

All HTML generation via templ components. No template files on disk.

**Directory structure:**
```
go-rewrite/
├── internal/
│   └── templates/                    # ← all .templ files live here
│       ├── layout/
│       │   ├── page.templ            — full HTML page shell (doctype, head, body)
│       │   ├── head.templ            — <head> with meta, assets, OG tags
│       │   ├── nav.templ             — navbar with stats (NavStats from SiteData)
│       │   └── footer.templ          — site footer
│       ├── components/
│       │   ├── photo_card.templ      — <picture> with AVIF/JPEG, used everywhere
│       │   ├── post_card.templ       — post preview card (photo + title + stats)
│       │   ├── photo_grid.templ      — grid of photo cards (gallery pages)
│       │   ├── post_stats.templ      — distance/elevation/time badges
│       │   └── redirect.templ        — 301/302 redirect pages
│       └── views/
│           ├── area_show.templ       — area detail page (JSON injection + mount point)
│           ├── area_post_list.templ  — post collection with filter config
│           ├── area_gallery.templ    — photo gallery for area
│           ├── post_article.templ    — blog post (rendered markdown + photos)
│           ├── post_gallery.templ    — post photo gallery
│           ├── homepage.templ        — homepage content
│           ├── about.templ           — about page (converted from markdown)
│           └── ...
```

**Example templ components:**

```templ
// templates/components/photo_card.templ
package components

import "odkrywajac/internal/model"

templ PhotoCard(photo *model.Photo, size string) {
    <picture class="photo-card">
        <source srcset={ photo.AVIFSrc(size) } type="image/avif"/>
        <img
            src={ photo.JPEGSrc(size) }
            alt={ photo.Caption }
            width={ photo.WidthForSize(size) }
            height={ photo.HeightForSize(size) }
            loading="lazy"
        />
    </picture>
}

templ PostCard(post *model.Post, imageSize string, postURL string) {
    <a href={ templ.SafeURL(postURL) } class="post-card">
        if post.HeaderPhoto != nil {
            @PhotoCard(post.HeaderPhoto, imageSize)
        }
        <div class="post-card-body">
            <h3>{ post.Title }</h3>
            if post.Subtitle != "" {
                <p class="subtitle">{ post.Subtitle }</p>
            }
            @PostStats(post)
        </div>
    </a>
}

templ PhotoGrid(photos []*model.Photo, cols int) {
    <div class={ "photo-grid", templ.KV(fmt.Sprintf("cols-%d", cols), true) }>
        for _, photo := range photos {
            @PhotoCard(photo, "grid")
        }
    </div>
}
```

```templ
// templates/layout/page.templ
package layout

templ Page(p PageData) {
    <!DOCTYPE html>
    <html lang="pl">
        @Head(p)
        <body>
            @Nav(p.NavStats, p.CurrentURL)
            { children... }
            @Footer()
        </body>
    </html>
}

templ Head(p PageData) {
    <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>{ p.FullTitle() }</title>
        <link rel="canonical" href={ p.CanonicalURL() }/>
        @HeadOG(p)
        @HeadAssets(p.CSSFiles, p.JSFiles)
    </head>
}

templ HeadAssets(cssFiles []AssetFile, jsFiles []AssetFile) {
    for _, css := range cssFiles {
        <link rel="stylesheet" href={ css.URLWithVersion() }
              if css.Integrity != "" {
                  integrity={ css.Integrity }
              }
        />
    }
    for _, js := range jsFiles {
        <script src={ js.URLWithVersion() }
                if js.Integrity != "" {
                    integrity={ js.Integrity }
                }
        ></script>
    }
}
```

```templ
// templates/views/area_show.templ
package views

templ AreaShowContent(jsonData string) {
    <script id="area-data" type="application/json">
        @templ.Raw(jsonData)
    </script>
    <div id="root"></div>
}

templ AreaPostListContent(filterBy string, filterValue string) {
    <div class="post-collection-container">
        <div id="posts-container">
            <div class="loading-state">Wczytywanie wpisów</div>
        </div>
    </div>
    <script id="post-collection-config" type="application/json">
        @templ.Raw(fmt.Sprintf(`{"filterBy":"%s","filterValue":"%s"}`, filterBy, filterValue))
    </script>
}
```

**How views use templ components (in Go code):**
```go
// internal/view/area.go
func AreaShowPage(data *SiteData, area *Area) Renderable {
    jsonBlob := buildAreaJSON(data, area)

    return &HTMLPage{
        url: data.Router.AreaShowURL(area),
        page: PageData{
            Title:   area.Name,           // from data, not config.yml
            Bundles: []string{"core", "leaflet", "preact"},
            PageJS:  "/js/self/area_show.js",
            // ...
        },
        content: views.AreaShowContent(jsonBlob),  // templ.Component
    }
}
```

**Requirements:**
- All `.templ` files in `internal/templates/` subdirectory
- Generated `_templ.go` committed to git
- `go generate` or Makefile target runs `templ generate`
- No `data/layout/` dependency — Go version is fully self-contained
- Reusable components: PhotoCard, PostCard, PhotoGrid, PostStats
- Page shell: Page → Head + Nav + content + Footer
- Raw HTML/JSON injection via `templ.Raw()` for inlined data

### R2: Asset Bundle Resolver

Parse `data/config/asset_bundles.yml` and resolve bundle names to CSS/JS file lists.

**Simplified role with templ:**
With templ components, asset bundles are less critical than in Crystal:
- Each templ view directly declares which CSS/JS files it needs
- Composite bundle resolution is optional (can just list files directly)
- Bundle resolver primarily useful as a lookup table + integrity hash source
- Still shared with Crystal during transition — don't change the YAML file

**Config structure (shared with Crystal):**
```yaml
bundles:
  bootstrap-css:
    css:
      - /css/libs/bootstrap.min.css
  leaflet-js:
    js:
      - /js/libs/leaflet.js
    integrity:
      /js/libs/leaflet.js: "sha256-20nQCchB9..."

composites:
  core:
    includes: [bootstrap-css, fontawesome, blog-css, bootstrap-js, avif-detect, nav-js]
  leaflet:
    includes: [leaflet-css, leaflet-js, route-colors-js]

page-assets:
  gallery:
    css:
      - /css/self/gallery.css
```

**Output type:**
```go
type AssetFile struct {
    Path      string // "/css/libs/bootstrap.min.css"
    Integrity string // "sha256-..." or ""
    Mtime     int64  // unix timestamp for cache busting
}

func (a AssetFile) URLWithVersion() string {
    return fmt.Sprintf("%s?v=%d", a.Path, a.Mtime)
}
```

**Requirements:**
- Parse YAML config once at startup
- Resolve composite bundles recursively
- Deduplicate (same file from multiple bundles → include once)
- Preserve order (CSS before JS, bundles in declaration order)
- Cache resolved result per unique bundle combination
- Return `[]AssetFile` (not HTML strings — templ renders the tags)

### R3: Router

Centralized URL generation for all page types.

**URL patterns:**

| Entity | Pattern | Example |
|--------|---------|---------|
| Post article | `/{year}/{month:02d}/{slug}.html` | `/2021/07/pagorki.html` |
| Post gallery | `/{year}/{month:02d}/{slug}/galeria.html` | `/2021/07/pagorki/galeria.html` |
| Post gallery stats | `/{year}/{month:02d}/{slug}/galeria-statystyki.html` | `/2021/07/pagorki/galeria-statystyki.html` |
| Area show | `/{nominative}/{slug}.html` | `/gmina/pobiedziska.html` |
| Area post list | `/wpisy-dla/{genitive}/{slug}.html` | `/wpisy-dla/gminy/pobiedziska.html` |
| Area gallery | `/galeria/{genitive}/{slug}.html` | `/galeria/gminy/pobiedziska.html` |
| Tag post list | `/wpisy-dla/tagu/{slug_pl}.html` | `/wpisy-dla/tagu/rowerem.html` |
| Tag gallery | `/galeria/tag/{slug_pl}.html` | `/galeria/tag/rowerem.html` |
| Tag redirect | `/tag/{slug_pl}.html` | `/tag/rowerem.html` → 302 |
| Year report | `/rok-{year}.html` | `/rok-2024.html` |
| Towns index | `/gminy.html` | |
| Homepage | `/index.html` | |
| About | `/o-mnie.html` | |
| Route map | `/mapa_tras.html` | |
| Photo map | `/mapa_zdjec.html` | |
| More | `/wiecej.html` | |

**Image URL patterns:**

| Type | Pattern | Example |
|------|---------|---------|
| Full size | `/images/{year}/{slug}/{filename}` | `/images/2021/pagorki/header.jpg` |
| Processed | `/images/processed/{year}/{month:02d}/{slug}_{filename}_{size}.{fmt}` | `..._grid.avif` |

**JSON endpoint URLs:**

| Endpoint | Path |
|----------|------|
| Homepage | `/jsons/homepage.json` |
| E2E test | `/jsons/e2e.json` |
| Map | `/jsons/map.json` |
| Photos map | `/jsons/photos_map.json` |
| Photo grid | `/jsons/photo_grid.json` |
| Train stations | `/jsons/train_stations.json` |
| RSS | `/feed.rss` |
| Atom | `/feed.atom` |
| Sitemap | `/sitemap.xml` |
| Robots | `/robots.txt` |

**Area type inflections:**

| Type | Nominative | Genitive | Config file |
|------|-----------|----------|-------------|
| Town | `gmina` | `gminy` | `towns.yml` |
| County | `powiat` | `powiatu` | `counties.yml` |
| Voivodeship | `wojewodztwo` | `wojewodztwa` | `voivodeships.yml` |
| MesoRegion | `region` | `regionu` | `meso_regions.yml` |
| MacroRegion | `obszar` | `obszaru` | `macro_regions.yml` |

**Semantic aliases:**
- `AreaLinkURL(area)` → configurable destination (show/post_list/gallery)
- `TagLinkURL(tag)` → configurable destination

**Requirements:**
- All URL generation in one place (no string building in views)
- AreaType struct with Nominative/Genitive fields
- Post slug: strip date prefix from filename (`2021-07-18-pagorki` → `pagorki`)
- Month always zero-padded (01-12)
- Tag URLs always use `slug_pl` (Polish), never English `slug`
- Semantic link methods with configurable target

### R4: Renderable Interface & Page Types

Every output implements Renderable. Four concrete page types.

```go
type Renderable interface {
    URL() string                    // output path: "/gmina/pobiedziska.html"
    Render(w io.Writer) error       // write content to writer
    AddToSitemap() bool             // include in sitemap.xml?
}
```

**Page type 1: HTMLPage** — full HTML page with shell

The page shell is a templ component (`layout.Page`) that wraps view-specific content.
Views pass their content as a `templ.Component` — no inheritance needed.

```go
type HTMLPage struct {
    url     string
    page    PageData          // title, bundles, meta, etc.
    content templ.Component   // view-specific templ component
    sitemap bool
}

func (h *HTMLPage) Render(w io.Writer) error {
    // layout.Page wraps content with head, nav, footer
    return layout.Page(h.page, h.content).Render(ctx, w)
}
```

**Page type 2: JSONEndpoint** — raw JSON, no HTML shell

```go
type JSONEndpoint struct {
    url    string
    data   any     // serialized with json.Encoder
}
```

**Page type 3: XMLEndpoint** — RSS, Atom, sitemap

```go
type XMLEndpoint struct {
    url     string
    render  func(w io.Writer) error
}
```

**Page type 4: RedirectPage** — minimal HTML with JS redirect

```go
type RedirectPage struct {
    url    string   // source URL: /tag/rowerem.html
    target string   // destination: /wpisy-dla/tagu/rowerem.html
    status int      // 301 or 302
}
```

Uses a small templ component (`components.Redirect`) that renders a `<script>window.location.replace(...)</script>`.

### R5: Render Engine (Parallel Fan-Out)

Processes view groups by priority, parallelizes within each group.

**View Group:**
```go
type ViewGroup struct {
    Name     string
    Priority int
    Generate func(data *SiteData) []Renderable
}
```

**Registration example:**
```go
groups := []ViewGroup{
    {
        Name:     "Area: show pages",
        Priority: 10,
        Generate: func(data *SiteData) []Renderable {
            var views []Renderable
            for _, areaType := range AllAreaTypes {
                for _, area := range data.AreasWithPosts(areaType) {
                    views = append(views, AreaShowPage(data, area))
                }
            }
            return views
        },
    },
}
```

**Execution flow:**
1. Sort groups by priority
2. For each group:
   a. Call `Generate(data)` → `[]Renderable`
   b. Fan out: each Renderable renders in its own goroutine (bounded semaphore)
   c. Each goroutine: render to `bytes.Buffer`, pretty-print HTML, send to channel
   d. `sync.WaitGroup.Wait()` — all views in group finish before next group
3. Writer pool runs concurrently, draining the channel
4. After all groups: close channel, wait for writers

**Output directory:** `env/{env}/public/go/`

**Requirements:**
- Bounded parallelism (configurable, default: NumCPU)
- Per-group synchronization
- Writer pool separate from render goroutines
- Error collection (collect all, report at end, don't stop on first)
- Progress: `"Rendering Area show: 120 pages (8 workers)..."`
- Timing per group and total

### R6: HTML Pretty-Printing

Format rendered HTML with proper indentation before saving.

**Pipeline:**
```
templ component renders → raw HTML bytes (no formatting)
    ↓
golang.org/x/net/html Parse → node tree
    ↓
custom walker → re-serialize with indentation (2 spaces)
    ↓
formatted HTML bytes → writer
```

**Rules:**
- Indent block elements by 2 spaces (div, section, article, nav, etc.)
- Inline elements (span, a, strong, em) stay on same line as parent
- `<pre>`, `<code>`, `<script>`, `<style>` content preserved verbatim (no indent changes)
- Self-closing tags: `<img/>`, `<br/>`, `<meta/>`, `<link/>`
- Empty lines between major sections (head/body, nav/content, content/footer)

**When to apply:**
- HTML pages: always pretty-print
- JSON endpoints: use `json.MarshalIndent` (2-space indent)
- XML feeds: indent with xml.Encoder.Indent

**Requirements:**
- Parse + re-serialize using `golang.org/x/net/html`
- Configurable indent (default: 2 spaces)
- Preserve `<pre>` and `<script>` content exactly
- Performance: < 5ms per page (formatting is not the bottleneck)
- Optional: skip in production mode for smaller files

### R7: File Writer with Build Manifest

Writes output to disk. Tracks content hashes for incremental builds and future FTP sync.

**Build manifest** (`env/{env}/cache-go/build_manifest.json`):
```json
{
  "built_at": "2026-03-06T15:30:00Z",
  "env": "dev",
  "target": "go",
  "files": {
    "/gmina/pobiedziska.html": {
      "sha256": "a1b2c3...",
      "size": 14523,
      "built_at": "2026-03-06T15:30:00Z"
    },
    "/jsons/e2e.json": {
      "sha256": "d4e5f6...",
      "size": 8932,
      "built_at": "2026-03-06T15:30:00Z"
    }
  }
}
```

**Write logic:**
1. Receive `OutputFile{URL, Content}` from channel
2. Compute SHA256 of new content
3. Check manifest: if hash matches → skip write
4. Write to `path.tmp`, then `os.Rename` to `path` (atomic)
5. Update manifest entry
6. Save manifest at end of build

**Future FTP sync (not Phase 3, but manifest enables it):**
```
Local manifest:  { "/gmina/pobiedziska.html": "a1b2c3..." }
Server manifest: { "/gmina/pobiedziska.html": "x9y8z7..." }
    ↓
Diff: pobiedziska.html changed → upload
      other files unchanged → skip
```

**URL to path mapping:**
```
URL:  /gmina/pobiedziska.html
Path: env/{env}/public/go/gmina/pobiedziska.html
```

**Requirements:**
- Pool of N writer goroutines (default: 4)
- SHA256 change detection (skip unchanged files)
- Atomic writes (write to `.tmp`, rename)
- Build manifest persisted as JSON in `env/{env}/cache-go/build_manifest.json`
- Manifest includes per-file hash, size, timestamp
- Report: written/skipped/total counts
- Directory creation cached (don't mkdir for every file)

### R8: First Views (Proof of Concept)

Implement 3-4 view types to prove the full pipeline works end-to-end.

**Area Show Page** (templ + JSON injection):
- Builds JSON blob with area config, posts, photos, polygon
- `views.AreaShowContent(jsonBlob)` templ component
- Wrapped in `layout.Page` with bundles: core, leaflet, preact
- Page JS: `/js/self/area_show.js`
- Title: `area.Name` (from data, not config.yml)
- URL: `/{nominative}/{slug}.html`

**Area Post List** (dynamic collection):
- `views.AreaPostListContent(filterBy, filterValue)` templ component
- Wrapped in `layout.Page` with bundles: core
- JS fetches e2e.json and filters client-side
- Title: `"Wpisy dla " + area.Name` (hardcoded pattern)
- URL: `/wpisy-dla/{genitive}/{slug}.html`

**Area Gallery** (server-rendered photo grid):
- Uses `components.PhotoGrid(photos, 3)` templ component
- Wrapped in `layout.Page` with bundles: core, gallery
- Title: `"Galeria " + area.Name` (hardcoded pattern)
- URL: `/galeria/{genitive}/{slug}.html`

**JSON Endpoint — e2e.json:**
- Pure JSON output (no page shell)
- All posts with basic metadata
- URL: `/jsons/e2e.json`

**Requirements:**
- All 4 views produce output comparable to Crystal
- `diff` comparison shows only expected differences (formatting, ordering)
- Views receive only `*SiteData` — no mutable context

### R9: HTML Validation

Validate rendered HTML before writing.

**Phase 3 minimum:**
- `<title>` exists and is not empty
- No unreplaced `{{ ... }}` placeholders (shouldn't be possible with templ, but safety check)
- No empty `href=""` or `src=""` attributes
- All `id` attributes unique within page

**Future extensions (later phases):**
- Link validation (all internal hrefs point to files that exist)
- Accessibility checks (alt text on images, lang attribute)
- Heading hierarchy (no h3 without h2)

**Requirements:**
- Run on rendered HTML string (after pretty-printing)
- Report errors with page URL context
- Don't block rendering — collect and report at end
- Extensible validator interface

## templ Component Hierarchy

```
layout.Page (doctype, html, head, body wrapper)
├── layout.Head (meta, canonical, OG tags, assets)
│   ├── layout.HeadOG (og:title, og:image, twitter:card)
│   └── layout.HeadAssets (CSS links, JS scripts)
├── layout.Nav (navbar, NavStats from SiteData, active page)
├── [content — one of:]
│   ├── views.AreaShowContent (JSON blob + mount point)
│   ├── views.AreaPostListContent (filter config + mount point)
│   ├── views.AreaGalleryContent
│   │   └── components.PhotoGrid
│   │       └── components.PhotoCard (picture + img)
│   ├── views.PostArticleContent (rendered markdown + photos)
│   │   ├── components.PhotoCard (inline photos)
│   │   └── components.PostStats (distance, time, elevation)
│   ├── views.HomepageContent
│   │   └── components.PostCard
│   │       ├── components.PhotoCard
│   │       └── components.PostStats
│   ├── views.AboutContent (converted from data/pages/about.md)
│   └── components.Redirect (301/302 JS redirect)
└── layout.Footer
```

## File Structure

```
go-rewrite/
├── internal/
│   ├── templates/                    # templ components (HTML generation)
│   │   ├── layout/
│   │   │   ├── page.templ            — Page shell (doctype, head, body)
│   │   │   ├── page_templ.go         — generated (committed to git)
│   │   │   ├── head.templ            — <head> section
│   │   │   ├── head_templ.go         — generated
│   │   │   ├── nav.templ             — navbar (uses NavStats from SiteData)
│   │   │   ├── nav_templ.go          — generated
│   │   │   ├── footer.templ          — footer
│   │   │   ├── footer_templ.go       — generated
│   │   │   └── types.go             — PageData, AssetFile structs
│   │   ├── components/
│   │   │   ├── photo_card.templ      — <picture> with AVIF/JPEG
│   │   │   ├── photo_card_templ.go   — generated
│   │   │   ├── post_card.templ       — post preview card
│   │   │   ├── post_card_templ.go    — generated
│   │   │   ├── photo_grid.templ      — grid of photos
│   │   │   ├── photo_grid_templ.go   — generated
│   │   │   ├── post_stats.templ      — stats badges
│   │   │   ├── post_stats_templ.go   — generated
│   │   │   └── redirect.templ        — redirect pages
│   │   └── views/
│   │       ├── area_show.templ       — area show content
│   │       ├── area_show_templ.go    — generated
│   │       ├── area_post_list.templ
│   │       ├── area_gallery.templ
│   │       ├── about.templ           — about page (from data/pages/about.md)
│   │       └── ...
│   ├── render/
│   │   ├── engine.go                — parallel fan-out executor
│   │   ├── engine_test.go
│   │   ├── writer.go                — file writer with manifest
│   │   ├── writer_test.go
│   │   ├── manifest.go              — build manifest (SHA256 tracking)
│   │   ├── manifest_test.go
│   │   ├── pretty.go                — HTML pretty-printer
│   │   ├── pretty_test.go
│   │   ├── validate.go              — HTML validators
│   │   └── validate_test.go
│   ├── router/
│   │   ├── router.go                — all URL generation
│   │   └── router_test.go
│   ├── bundle/
│   │   ├── resolver.go              — asset bundle resolution (simplified)
│   │   └── resolver_test.go
│   └── view/
│       ├── registry.go              — ViewGroup registration
│       ├── page.go                  — HTMLPage, JSONEndpoint, etc.
│       ├── area.go                  — area view builders (titles hardcoded)
│       ├── area_test.go
│       ├── json.go                  — JSON endpoint builders
│       └── json_test.go
├── Makefile                         — includes `templ generate` target
```

## Testing Strategy

### Unit Tests

- **templ components**: render component, check output HTML contains expected elements
- **BundleResolver**: resolve composites, dedup, integrity attributes
- **Router**: all URL patterns, edge cases
- **HTMLPage**: full render produces valid HTML with head/nav/content/footer
- **RenderEngine**: mock views, verify parallel execution, error collection
- **FileWriter**: write/skip logic, manifest update, atomic writes
- **PrettyPrinter**: indentation, `<pre>` preservation, self-closing tags
- **Validators**: title exists, no empty hrefs, unique IDs

### Integration Tests

- Load dev SiteData (from Phase 2)
- Render all area pages
- Verify HTML is well-formatted (pretty-printed)
- Verify manifest tracks all output files
- Compare content with Crystal output (structural, not byte-identical)

### E2E Tests (Rod)

- Build site with Go engine
- Load area show page — verify title, content, map
- Load post list — verify JS hydration works
- JSON endpoints return valid JSON

## Acceptance Criteria

```
templ:        15 components compiled (layout: 4, components: 5, views: 6+)
Bundles:      12 bundles, 3 composites resolved
Router:       all URL patterns verified (unit tests)
Views:        4 types implemented (area show/list/gallery, e2e.json)

Rendering dev environment:
  Area show:      42 pages (8 workers, 120ms)
  Area post list: 42 pages (8 workers, 80ms)
  Area gallery:   42 pages (8 workers, 95ms)
  JSON endpoints: 1 file (10ms)
  Total:          127 pages rendered in 310ms

Writer:
  Written:   127 files (first run)
  Skipped:   0
  Manifest:  127 entries saved to env/dev/cache-go/build_manifest.json

Output dir:  env/dev/public/go/
Pretty-print: all HTML files indented (2 spaces)
Validation:   0 errors across 127 pages
```

## What This Phase Does NOT Cover

- Post article rendering / markdown parsing (Phase 4)
- Homepage view (Phase 4)
- Tag views (Phase 4 — same pattern as area views)
- Feed views — RSS, Atom, sitemap (Phase 5)
- Stats views — year reports (Phase 5)
- Static pages beyond about — map, more (Phase 5)
- Image resizing (Phase 1 pipeline)
- Live reload / dev server (Phase 6)
- FTP sync (future — manifest enables it)
- GPX rectifier tool (future phase)

## Open Questions (Resolved)

- [x] Should views receive `*SiteData` directly or through an interface?
  **Decision:** Direct `*SiteData` pointer. Views also receive `*Router` and
  `*bundle.Resolver` separately.

- [x] HTML pretty-printing: always on or only in dev?
  **Decision:** Always on. Applied to all .html files.

## Implementation Notes

**Completed 2026-03-07.**

Key decisions during implementation:
- `PhotoEntity` renamed to `Photo` (10 references updated)
- `Sluggable` interface added on Tag, PhotoTag, Area, Post
- templ `<script>` tags treat content as literal text — JSON injection uses
  `templ.Raw()` with pre-built `<script>` tag HTML strings
- Pretty printer writes `<script>` child text nodes directly (not via
  `html.Render`) to avoid HTML-escaping JSON content
- Writer uses `os.MkdirAll` unconditionally (idempotent, no caching needed)
- No priority groups — flat parallel rendering in single worker pool

Stats:
- 141 total tests (87 from Phase 1-2, 54 new in Phase 3)
- 83 views generated (dev env): 82 HTML + 1 JSON
- Build time: ~42ms (14 workers)
- Second run: 0 written, 83 skipped (SHA256 change detection)
