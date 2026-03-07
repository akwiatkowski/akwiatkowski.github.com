# Phase 4: Post Rendering, Homepage & Tag Views

## Goal

Implement post article rendering (markdown → HTML with custom photo syntax),
homepage view, and tag views. This phase makes the blog actually readable —
posts with photos, navigation, and content discovery.

## Key Challenge: Custom Markdown Syntax

Posts use `{% ... %}` custom functions inside markdown. The most important
is `{% photo %}` which generates a full `<figure>` with responsive `<picture>`
element, EXIF data, photo tag links, and lightbox support.

**Crystal's approach:** Process `{% ... %}` during markdown rendering via regex.
Side effects happen during rendering (create PhotoEntity, fetch EXIF, etc.).
This interleaves data mutation with HTML generation — messy.

**Go's approach:** Two clean phases:
1. **Phase 2 (already done):** Parse all `{% photo %}` references, build PhotoEntity
   structs with EXIF data. All side effects happen here.
2. **Phase 4 (this phase):** goldmark renders markdown with custom AST nodes.
   Photo nodes just look up pre-built PhotoEntity and render HTML. Pure rendering,
   no side effects.

## Custom Functions in Posts

All `{% ... %}` syntax recognized in post markdown:

| Function | Syntax | Output | Frequency |
|----------|--------|--------|-----------|
| `photo` | `{% photo "file","caption" %}` | `<figure>` with `<picture>` + EXIF | Every post, ~20/post |
| `photo` (tagged) | `{% photo "file","caption","tag:good,tag:best" %}` | Same + photo tag links | Common |
| `photo_header` | `{% photo_header "caption","tags" %}` | Empty (metadata update) | ~1/post |
| `post_url` | `{% post_url 2021-06-03-slug %}` | Resolved URL string | Occasional |
| `geo` | `{% geo 52.45,16.93 %}` | Map links (OSM, Google) | 4 uses in 1 post |
| `pro_tip` | `{% pro_tip %}` | `<span class="pro-tip">Porada:</span>` | Rare |
| `current_year` | `{% current_year %}` | Year number (e.g., `2026`) | Rare |
| `todo` | `{% todo %}` | Empty string | Drafts only |

**Removed functions:**
- `vimeo_iframe` — used in 1 post only, remove from that post and drop support
- `strava_iframe` — **0 uses** in any post markdown. Strava embeds are handled
  via YAML front matter `strava:` field, not inline `{% %}` syntax. Drop support.

## Requirements

### R1: goldmark Custom AST Extension

Extend goldmark with custom block/inline parsers for `{% ... %}` syntax.

**AST node types:**

```go
// Block-level nodes (take a full line)
type PhotoNode struct {
    ast.BaseBlock
    Filename string
    Caption  string
    Tags     []string  // photo tag slugs: ["good", "best"]
}

type PhotoHeaderNode struct {
    ast.BaseBlock
    Caption string
    Tags    []string
}

// Inline nodes (within text)
type PostURLNode struct {
    ast.BaseInline
    Slug string  // "2021-06-03-slug"
}

type GeoNode struct {
    ast.BaseInline
    Lat float64
    Lon float64
}

type ProTipNode struct {
    ast.BaseInline
}

type CurrentYearNode struct {
    ast.BaseInline
}
```

**Parser extension:**

```go
// Block parser for {% photo ... %}, {% photo_header ... %}
type CustomBlockParser struct{}

func (p *CustomBlockParser) Trigger() []byte {
    return []byte{'{'}
}

func (p *CustomBlockParser) Open(parent ast.Node, reader text.Reader, pc parser.Context) (ast.Node, parser.State) {
    line, _ := reader.PeekLine()
    // Match: {% photo "file","caption" %}
    // Match: {% photo "file","caption","tags" %}
    // Match: {% photo_header "caption","tags" %}
    // Return appropriate AST node
}
```

```go
// Inline parser for {% post_url ... %}, {% geo ... %}, {% pro_tip %}, {% current_year %}
type CustomInlineParser struct{}

func (p *CustomInlineParser) Trigger() []byte {
    return []byte{'{'}
}

func (p *CustomInlineParser) Parse(parent ast.Node, block text.Reader, pc parser.Context) ast.Node {
    // Match {% post_url slug %} → PostURLNode
    // Match {% geo lat,lon %} → GeoNode
    // Match {% pro_tip %} → ProTipNode
    // Match {% current_year %} → CurrentYearNode
}
```

**Requirements:**
- Block parser: PhotoNode, PhotoHeaderNode
- Inline parser: PostURLNode, GeoNode, ProTipNode, CurrentYearNode
- All nodes carry parsed data (filename, caption, tags, etc.)
- PhotoHeaderNode does NOT produce HTML output (metadata-only, handled in Phase 2)
- Unknown `{% ... %}` syntax logged as warning, rendered as-is

### R2: goldmark Custom Renderer

Render custom AST nodes to HTML. Photo nodes call templ components.

**PhotoNode renderer — the most complex:**

```go
type CustomRenderer struct {
    data   *SiteData
    post   *model.Post
}

func (r *CustomRenderer) renderPhoto(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
    if !entering {
        return ast.WalkContinue, nil
    }
    n := node.(*PhotoNode)

    // Look up pre-built PhotoEntity (from Phase 2 parsing)
    photo := r.post.PhotoByFilename(n.Filename)
    if photo == nil {
        log.Warn("Photo not found", "file", n.Filename, "post", r.post.Slug)
        return ast.WalkContinue, nil
    }

    // Render templ component directly to goldmark's writer
    comp := components.ArticlePhoto(photo, r.data.Router)
    comp.Render(context.Background(), w)

    return ast.WalkContinue, nil
}
```

**PostURLNode renderer:**

```go
func (r *CustomRenderer) renderPostURL(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
    if !entering {
        return ast.WalkContinue, nil
    }
    n := node.(*PostURLNode)

    // Resolve slug to URL
    post := r.data.PostBySlug(n.Slug)
    if post != nil {
        w.WriteString(r.data.Router.PostURL(post))
    } else {
        log.Warn("Cross-referenced post not found", "slug", n.Slug)
        w.WriteString("#post-not-found")
    }

    return ast.WalkContinue, nil
}
```

**Requirements:**
- PhotoNode → calls `components.ArticlePhoto` templ component
- PhotoHeaderNode → no output (already processed in Phase 2)
- PostURLNode → resolves to URL string via Router
- GeoNode → calls `components.GeoLinks` templ component
- ProTipNode → renders `<span class="pro-tip">Porada:</span>`
- CurrentYearNode → renders current year number
- Renderer receives `*SiteData` and `*Post` for lookups

### R3: Article Photo templ Component

The core photo partial — generates responsive `<figure>` with AVIF/JPEG.

```templ
// templates/components/article_photo.templ
package components

templ ArticlePhoto(photo *model.Photo, router *router.Router) {
    <figure class="figure post-article-photo">
        <a href={ templ.SafeURL(photo.FullSizeURL()) } target="_blank">
            <picture>
                <source type="image/avif"
                    srcset={ photo.ResponsiveSrcsetAVIF("grid", "article") }
                    sizes="(max-width: 576px) 100vw, 100vw"/>
                <img src={ photo.ArticleSrc() }
                    srcset={ photo.ResponsiveSrcsetJPEG("grid", "article") }
                    sizes="(max-width: 576px) 100vw, 100vw"
                    class="img-fluid"
                    title={ photo.Caption }
                    alt={ photo.AltText() }
                    data-is-gallery={ boolStr(photo.IsGallery) }
                    data-is-timeline={ boolStr(photo.IsTimeline) }
                    if photo.HasGPS() {
                        data-lat={ fmtFloat(photo.Lat) }
                        data-lon={ fmtFloat(photo.Lon) }
                        data-altitude={ fmtFloat(photo.Altitude) }
                    }
                    if photo.HasTime() {
                        data-time={ photo.Time.Format(time.RFC3339) }
                    }
                />
            </picture>
            if photo.ExifString() != "" {
                <span class="photo-exif">{ photo.ExifString() }</span>
            }
        </a>
        <figcaption class="figure-caption">
            <span class="photo-caption-title">
                @PhotoTagLinks(photo)
                { photo.Caption }
            </span>
            if photo.CoordGalleryURL != "" {
                { " " }
                <a href={ templ.SafeURL(photo.CoordGalleryURL) } target="_blank">okolica</a>
            }
        </figcaption>
    </figure>
}

templ PhotoTagLinks(photo *model.Photo) {
    for _, tagLink := range photo.TagGalleryLinks {
        <a href={ templ.SafeURL(tagLink.URL) }>
            @BootstrapIcon(tagLink.Icon, 16)
        </a>
        { " " }
    }
}
```

**Photo model methods needed:**

```go
// ResponsiveSrcsetAVIF returns "grid.avif 560w, article.avif 1000w"
func (p *Photo) ResponsiveSrcsetAVIF(sizes ...string) string

// ResponsiveSrcsetJPEG returns "grid.jpg 560w, article.jpg 1000w"
func (p *Photo) ResponsiveSrcsetJPEG(sizes ...string) string

// ExifString returns "50mm f/4 1/100s ISO400"
func (p *Photo) ExifString() string

// AltText returns "Caption (123 kB)"
func (p *Photo) AltText() string
```

**Requirements:**
- Exact same HTML structure as Crystal's `post_image_partial.html`
- Responsive srcset with 560w (grid) + 1000w (article)
- AVIF `<source>` + JPEG `<img>` fallback
- GPS data attributes (conditional — only if photo has GPS)
- Photo tag gallery links with Bootstrap icons
- Coord gallery link (conditional — only if enough nearby photos)
- Shared with other views that render article-size photos

### R4: Post Article View

Full blog post page with rendered markdown, photos, metadata, navigation.

**URL:** `/{year}/{month}/{day}-{slug}.html`

**Page structure:**
```
layout.Page
└── views.PostArticleContent
    ├── Tag links (links to /wpisy-dla/tagu/...)
    ├── Area links (towns, voivodeships, meso regions)
    ├── POIs section (if post has pois)
    ├── Route map SVG (if post has route)
    ├── Rendered markdown (with inline photos from goldmark)
    ├── Related posts grid
    ├── Finished-at notice
    └── Prev/next post pager
```

**Data needed:**
- Post struct with all metadata
- Rendered markdown HTML (goldmark output with photo nodes resolved)
- Tag entities (for link generation)
- Area entities (for town/voivodeship links)
- Previous/next posts (chronological)
- Related posts (by shared areas/tags)
- Route map SVG (if post has coords)

**templ component:**

```templ
// templates/views/post_article.templ
templ PostArticleContent(post *model.Post, ctx *PostArticleContext) {
    <article>
        <div class="container">
            <div class="row">
                <div class="col-lg-8 offset-lg-2 col-md-10 offset-md-1">
                    @PostTagLinks(post, ctx.Tags)
                    @PostAreaLinks(post, ctx.Areas)
                    if len(post.POIs) > 0 {
                        @PostPOIs(post.POIs)
                    }
                    if post.HasRoute() {
                        @PostRouteMap(post, ctx.RouteColors)
                    }
                    <div class="post-content">
                        @templ.Raw(ctx.RenderedMarkdown)
                    </div>
                    if len(ctx.RelatedPosts) > 0 {
                        @RelatedPosts(ctx.RelatedPosts)
                    }
                    @PostFinishedAt(post)
                    <hr/>
                    @PostPager(ctx.PrevPost, ctx.NextPost, post)
                </div>
            </div>
        </div>
    </article>
}
```

**Rendered markdown integration:**
The key insight — goldmark produces HTML string (with embedded photo `<figure>`
elements from the custom renderer). This HTML is injected via `templ.Raw()`.
The rest of the article (tags, areas, pager, etc.) is rendered by templ components.

**Requirements:**
- goldmark renders post body with custom extensions
- Rendered HTML injected into article templ component via `templ.Raw()`
- Tag links use Polish `slug_pl` for URLs
- Area links grouped by type (towns, counties, voivodeships, meso regions)
- Prev/next pager with thumbnail photos (150×112)
- Related posts with grid photos (560×420)
- Route map SVG with activity badge (optional, depends on post having coords)
- Social meta tags (og:image, og:title, twitter:card)
- Bundles: core
- Page JS: lightbox (for inline photo clicks)

### R5: Post Gallery View

Photo gallery page for a single post.

**URL:** `/galeria/{year}/{month}/{day}-{slug}.html`

**Structure:**
- All photos from the post in a grid
- Preact gallery component with lightbox
- Prev/next post gallery pager

```templ
templ PostGalleryContent(post *model.Post, photosJSON string) {
    <script id="gallery-config" type="application/json">
        @templ.Raw(photosJSON)
    </script>
    <div id="root"></div>
}
```

**Requirements:**
- JSON config with photo data (URLs, captions, EXIF)
- Preact gallery component (`gallery_dynamic.js`)
- Lightbox support (`photo_lightbox.js`)
- Bundles: core, gallery, preact
- Prev/next gallery pager

### R6: Post Gallery Stats View

EXIF statistics page for a post's photos.

**URL:** `/galeria/statystyki/{year}/{month}/{day}-{slug}.html`

**Content:**
- Camera usage breakdown
- Lens distribution
- ISO histogram
- Focal length distribution
- Exposure breakdown
- Published vs all photos

**Requirements:**
- Server-rendered statistics (no JS needed)
- templ components for stat tables/charts
- Not in sitemap
- Bundles: core

### R7: Homepage View

Modern homepage with hero, posts grid, category chips.

**URL:** `/index.html`

**Structure:**
- Server-rendered stats (bicycle distance, hike distance, time spent)
- Placeholder HTML for hero, posts grid, category chips
- JavaScript populates from `/jsons/homepage.json`
- Fuzzy logic hero selection (seasonal, best tag, recency)

**templ component:**

```templ
templ HomepageContent(stats *NavStats) {
    <section class="hero-section">
        <div id="hero-container"></div>
    </section>
    <section class="stats-section">
        @HomepageStats(stats)
    </section>
    <section class="posts-section">
        <div id="posts-grid"></div>
    </section>
    <section class="categories-section">
        <div id="category-chips"></div>
    </section>
}

templ HomepageStats(stats *NavStats) {
    <div class="stats-row">
        <span class="stat">
            @BootstrapIcon("bicycle", 16)
            { fmt.Sprintf("%dkm", stats.BicycleDistance) }
        </span>
        <span class="stat">
            @BootstrapIcon("signpost", 16)
            { fmt.Sprintf("%dkm", stats.HikeDistance) }
        </span>
        <span class="stat">
            @BootstrapIcon("clock", 16)
            { fmt.Sprintf("%dh", stats.TotalTime) }
        </span>
    </div>
}
```

**Requirements:**
- NavStats computed from SiteData (in memory, no cache file)
- Homepage JSON generator (separate JSON endpoint view)
- Title hardcoded in templ: "Odkrywając Polskę"
- Custom CSS: `/css/self/new-home.css`
- Page JS: `/js/self/homepage.js`
- Bundles: core
- Dark mode CSS support

### R8: Homepage JSON Generator

Optimized JSON endpoint for homepage JavaScript.

**URL:** `/jsons/homepage.json`

**Contents:**
```json
{
  "posts": [
    {
      "url": "/2021/07/18-pagorki.html",
      "title": "Pagórki przed żniwami",
      "subtitle": "...",
      "date": "2021-07-18",
      "distance": 69,
      "time_spent": 8,
      "card_image_url": "/images/processed/.../card.jpg",
      "card_image_url_avif": "/images/processed/.../card.avif",
      "tags": ["bicycle", "best"],
      "top_photos": [
        {"url": "/images/processed/.../card.jpg", "avif": "...avif", "points": 5},
        ...
      ],
      "towns": ["pobiedziska", "swarzedz"],
      "counties": ["poznanski"],
      "voivodeships": ["wielkopolskie"],
      "meso_regions": ["pojezierze_gnieznienskie"]
    }
  ],
  "tags": { "bicycle": {"url": "/wpisy-dla/tagu/rowerem.html", "name": "Rowerem"} },
  "areas": {
    "towns": { "pobiedziska": {"url": "/gmina/pobiedziska.html", "name": "Pobiedziska"} },
    "meso_regions": { ... }
  }
}
```

**Requirements:**
- Compact (target ~6KB for dev, ~50KB for full)
- Top 4 photos per post (sorted by points) for hero selection
- Tag lookup with URLs (using Router)
- Area lookups with URLs (using Router)
- Area slugs per post for client-side filtering

### R9: Tag Post List View

Post collection filtered by tag.

**URL:** `/wpisy-dla/tagu/{slug_pl}.html`

**Same pattern as area post list** (Phase 3):
- `views.AreaPostListContent(filterBy, filterValue)` reused
- `filterBy: "tag"`, `filterValue: tag.Slug` (English slug for matching)
- JS loads from homepage JSON and filters client-side
- Title: tag name (hardcoded pattern, e.g., "Wpisy: Rowerem")

**Requirements:**
- Reuse `CollectionContent` templ component from area post list
- English slug for JS filtering, Polish slug_pl in URL
- Bundles: core, post-collection-js

### R10: Tag Gallery View

Photo gallery filtered by photo tag.

**URL:** `/galeria/tag/{slug_pl}.html`

**Same pattern as area gallery** (Phase 3):
- Server-rendered photo grid using `components.PhotoGrid`
- Photos filtered by photo tag (from photo_tags.yml)
- Preact gallery with lightbox

**Requirements:**
- Filter photos by tag slug
- Sort by date (newest first)
- Bundles: core, gallery, preact

### R11: Tag Legacy Redirects

302 redirects from old `/tag/` URLs to new `/wpisy-dla/tagu/` URLs.

**Source:** `/tag/{slug_pl}.html`
**Target:** `/wpisy-dla/tagu/{slug_pl}.html`

**Requirements:**
- One redirect page per tag
- Uses `components.Redirect` templ component (from Phase 3)
- 302 (temporary) redirect
- Not in sitemap

### R12: Additional Custom Function templ Components

Small templ components for the remaining custom functions.

```templ
// Geo map links (OSM, Google Maps)
// Used in 1 post (4 occurrences). UMP link dropped (service defunct).
templ GeoLinks(lat float64, lon float64) {
    <span class="geo-links">
        <a href={ templ.SafeURL(fmt.Sprintf("https://www.openstreetmap.org/?mlat=%f&mlon=%f#map=14/%f/%f", lat, lon, lat, lon)) }
           target="_blank">
            <img src="/img/osm.ico" alt="openstreetmap" class="map-icon"/>
        </a>
        { " " }
        <a href={ templ.SafeURL(fmt.Sprintf("https://www.google.com/maps/place/%f,%f", lat, lon)) }
           target="_blank">
            <img src="/img/google_maps.ico" alt="google maps" class="map-icon"/>
        </a>
    </span>
}
```

**Dropped functions:**
- `strava_iframe` — 0 uses in post markdown. Strava data comes from YAML `strava:` field.
- `vimeo_iframe` — 1 use in 1 post. Remove the embed from that post, drop support.
  The post is `2018-03-11-rozpoczecie-sezonu-rowerowego-w-2018.md`.

## goldmark Integration Architecture

```
Post.Body (raw markdown with {% ... %} tags)
    │
    ▼
┌──────────────────────────────────────┐
│ goldmark parser                      │
│                                      │
│ Standard parsers:                    │
│   paragraph, heading, list, link...  │
│                                      │
│ Custom parsers (this phase):         │
│   CustomBlockParser → PhotoNode,     │
│     PhotoHeaderNode                  │
│   CustomInlineParser → PostURLNode,  │
│     GeoNode, ProTipNode,            │
│     CurrentYearNode                  │
└───────────────┬──────────────────────┘
                │
                ▼
        AST (with custom nodes)
                │
                ▼
┌──────────────────────────────────────┐
│ goldmark renderer                    │
│                                      │
│ Standard renderers:                  │
│   HTML for p, h1-h6, ul, a, img...  │
│                                      │
│ Custom renderer (this phase):        │
│   PhotoNode → components.ArticlePhoto│
│   PhotoHeaderNode → (no output)      │
│   PostURLNode → resolved URL string  │
│   GeoNode → components.GeoLinks     │
│   ProTipNode → <span> literal       │
│   CurrentYearNode → year number     │
│                                      │
│ Context: *SiteData, *Post            │
│ (for photo lookups, URL resolution)  │
└───────────────┬──────────────────────┘
                │
                ▼
        HTML string (complete, with photos)
                │
                ▼
        templ.Raw(html) inside PostArticleContent
```

**Key design principle:** goldmark rendering is **pure** — no side effects.
All PhotoEntity structs are pre-built in Phase 2. The renderer just looks them up
and calls templ components. This makes rendering parallelizable and testable.

## File Structure

```
go-rewrite/
├── internal/
│   ├── markdown/
│   │   ├── extension.go          — goldmark Extension registration
│   │   ├── parser.go             — CustomBlockParser, CustomInlineParser
│   │   ├── ast.go                — PhotoNode, PostURLNode, etc.
│   │   ├── renderer.go           — Custom node renderers
│   │   ├── renderer_test.go
│   │   └── markdown.go           — RenderPost(post, data) → HTML string
│   ├── templates/
│   │   ├── components/
│   │   │   ├── article_photo.templ    — <figure> with <picture> (NEW)
│   │   │   ├── geo_links.templ        — Map links (NEW)
│   │   │   ├── post_tag_links.templ   — Tag links in article (NEW)
│   │   │   ├── post_area_links.templ  — Area links in article (NEW)
│   │   │   ├── post_pager.templ       — Prev/next post navigation (NEW)
│   │   │   ├── related_posts.templ    — Related posts grid (NEW)
│   │   │   ├── route_map.templ        — Post route SVG map (NEW)
│   │   │   ├── photo_card.templ       — (from Phase 3)
│   │   │   ├── post_card.templ        — (from Phase 3)
│   │   │   ├── photo_grid.templ       — (from Phase 3)
│   │   │   ├── post_stats.templ       — (from Phase 3)
│   │   │   └── redirect.templ         — (from Phase 3)
│   │   └── views/
│   │       ├── post_article.templ     — Blog post page (NEW)
│   │       ├── post_gallery.templ     — Post photo gallery (NEW)
│   │       ├── post_gallery_stats.templ — Gallery EXIF stats (NEW)
│   │       ├── homepage.templ         — Homepage (NEW)
│   │       ├── area_show.templ        — (from Phase 3)
│   │       ├── area_post_list.templ   — (from Phase 3)
│   │       └── area_gallery.templ     — (from Phase 3)
│   └── view/
│       ├── post.go                    — Post article/gallery builders (NEW)
│       ├── post_test.go
│       ├── homepage.go                — Homepage + JSON builder (NEW)
│       ├── homepage_test.go
│       ├── tag.go                     — Tag views builder (NEW)
│       ├── tag_test.go
│       ├── area.go                    — (from Phase 3)
│       └── json.go                    — (from Phase 3, + homepage JSON)
```

## Testing Strategy

### Unit Tests

- **goldmark parser:** Parse `{% photo "file","caption","tags" %}` → PhotoNode with correct fields
- **goldmark parser:** Parse `{% post_url slug %}` → PostURLNode
- **goldmark renderer:** PhotoNode renders correct `<figure>` HTML
- **goldmark renderer:** PostURLNode resolves to correct URL
- **goldmark renderer:** Unknown `{% ... %}` logged as warning
- **ArticlePhoto templ:** Renders `<picture>` with AVIF/JPEG sources
- **PostArticle templ:** Full page has all sections (tags, areas, content, pager)
- **Homepage JSON:** Contains correct post/tag/area data
- **Tag views:** Correct URLs with Polish slug_pl

### Integration Tests

- Render a real post from dev environment, compare HTML structure with Crystal
- Verify all `{% photo %}` tags in dev posts produce valid `<figure>` elements
- Verify `{% post_url %}` cross-references resolve to valid URLs
- Homepage JSON matches Crystal's output structure

### goldmark-Specific Tests

```go
func TestPhotoNodeParsing(t *testing.T) {
    md := `Some text

{% photo "2021_07_18__16_52__7180460.jpg","Pagórki","tag:good,tag:best" %}

More text`

    doc := parser.Parse(text.NewReader([]byte(md)))
    // Walk AST, find PhotoNode
    // Assert: Filename == "2021_07_18__16_52__7180460.jpg"
    // Assert: Caption == "Pagórki"
    // Assert: Tags == ["good", "best"]
}

func TestPostURLResolution(t *testing.T) {
    md := `See ({% post_url 2021-06-03-test-post %})`

    html := renderWithData(md, testSiteData)
    assert.Contains(t, html, "/2021/06/03-test-post.html")
}
```

## Acceptance Criteria

```
goldmark:     6 custom AST nodes, 2 parsers (block + inline)
templ:        +8 new components (article_photo, geo, post sections)
Views:        post article, post gallery, gallery stats, homepage, tag list,
              tag gallery, tag redirect, homepage JSON = 8 new view types

Rendering dev environment (6 posts):
  Post articles:    6 pages
  Post galleries:   6 pages
  Gallery stats:    6 pages
  Homepage:         1 page
  Homepage JSON:    1 endpoint
  Tag post lists:   ~51 pages (one per tag)
  Tag galleries:    ~15 pages (one per photo tag)
  Tag redirects:    ~51 pages
  Total new:        ~137 pages

goldmark rendering:
  Average post:     ~20 photo nodes resolved, 45ms
  All 6 dev posts:  270ms total

Photo partial:
  <figure> output matches Crystal byte-for-byte (minus whitespace)
  AVIF srcset, EXIF data attrs, photo tag links all present
```

## What This Phase Does NOT Cover

- Feed views — RSS, Atom, sitemap (Phase 5)
- Stats views — year reports, summary (Phase 5)
- Static pages — about, route map, photo map, more (Phase 5)
- Photo gallery index pages (Phase 5)
- Camera/lens/ISO gallery pages (Phase 5)
- Live reload / dev server (Phase 6)

## Open Questions

- [ ] Should goldmark rendering happen per-post (parallel) or sequentially?
  **Recommendation:** Per-post in parallel. Each post's rendering is independent
  once SiteData is frozen. Use same goroutine pool as other views.

- [ ] Should `{% photo_header %}` be handled in goldmark or pre-processed in Phase 2?
  **Recommendation:** Phase 2 extracts it during post parsing. goldmark sees it
  but the renderer produces no output (empty string). This keeps the parser simple.

- [ ] Route map SVG — render in Go or reuse Crystal's?
  **Recommendation:** Reuse Crystal's approach initially (SVG generation from
  route coords). Can be improved later with Go SVG library.

- [ ] UMP map link in `{% geo %}` — UMP (ump.waw.pl) seems defunct.
  **Recommendation:** Drop UMP, keep OSM + Google Maps only.

## Implementation Notes

**Implemented 2026-03-07:**

All requirements R1-R12 implemented (except R6 gallery stats — deferred to Phase 5):

- **AST Nodes:** GeoNode, ProTipNode, CurrentYearNode, TodoNode added to extension.go
- **Inline parser:** Unified `directiveInlineParser` handles all inline directives
- **Custom renderer:** `renderer.go` with `RenderPost()` function, renders all node types
- **ArticlePhoto templ:** `<figure>` with responsive `<picture>`, EXIF, GPS data attrs, tag links
- **GeoLinks templ:** OSM + Google Maps links (UMP dropped)
- **Post article view:** Full page with tag links, area links, prev/next pager, related posts
- **Post gallery view:** JSON config with gallery photos
- **Homepage view:** Stats section, placeholder sections for JS
- **Homepage JSON:** Posts with top photos, tags, areas
- **Tag post list:** Reuses AreaPostListContent pattern with tag filter
- **Tag gallery:** Photo cards filtered by photo tag slug
- **Tag redirects:** Already done in Phase 3

Not implemented (deferred):
- R6: Post gallery stats view — EXIF statistics page (low priority)
- Route map SVG in post articles — needs SVG generation library
- Photo tag icons in article photos — icon files not available yet

**Stats:**
- 170 tests passing (29 new)
- Dev build: 154 views in ~45ms
- 70 new files written (84 unchanged from Phase 3)
