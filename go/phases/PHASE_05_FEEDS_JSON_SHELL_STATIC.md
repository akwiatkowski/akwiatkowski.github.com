# Phase 5: Feeds, JSON Endpoints, Shell Pages & Static Content

## Status: COMPLETE

## Summary

Added ~21 new views bringing total from 154 to 175 views (~45ms render time).

## What Was Added

### XML Feeds (feed.go)
- **RSS** (`/feed.rss`) — RSS 2.0 with last 20 finished posts
- **Atom** (`/feed.atom`) — Atom 1.0 with author info
- **Sitemap** (`/sitemap.xml`) — all sitemappable URLs, generated last
- **Robots.txt** (`/robots.txt`) — User-agent, Allow, Sitemap URL

### JSON Endpoints (json.go)
- **Map JSON** (`/jsons/map.json`) — posts with GPS route segments
- **Photos JSON** (`/jsons/photos.json`) — all photos with EXIF metadata
- **Photos Map JSON** (`/jsons/photos_map.json`) — GPS-tagged photos only
- **Train Stations JSON** (`/jsons/train_stations.json`) — station locations + Poznań distance
- **Photo Grid JSON** (`/jsons/photo_grid.json`) — [lat, lon] coordinate pairs
- **Ideas JSON** (`/jsons/ideas.json`) — placeholder (ideas data not yet in Go pipeline)

### Shell Pages (shell.go)
Generic `ShellPage()` builder for JS-heavy pages with `<div id="root">`:
- **Route Map** (`/mapa_tras.html`) — Leaflet + map.js
- **Photo Map** (`/mapa_zdjec.html`) — Leaflet + photo_map.js
- **Timeline** (`/linia_czasu.html`) — timeline.js
- **EXIF Stats** (`/statystyki_exif.html`) — exif_stats.js
- **Photo Planner** (`/pomysly_dla_zdjec.html`) — Leaflet + photo_planner.js
- **Trip Ideas** (`/pomysly_tras.html`) — Leaflet + Preact + trip_ideas.js

### Static Pages (static.go)
- **About** (`/o-mnie.html`) — markdown rendered from `data/pages/about.md`
- **English** (`/en/index.html`) — markdown rendered from `data/pages/en.md`
- **More** (`/wiecej.html`) — links grid to all tool pages

### Index Pages
- **Towns Index** (`/gminy.html`) — Preact shell with embedded JSON (town data, voivodeships, unique photos)

### Portfolio
- **Portfolio** (`/portfolio.html`) — gallery of "best"-tagged photos

## New Files

```
internal/view/
├── feed.go          + feed_test.go         — RSS, Atom, sitemap, robots
├── shell.go         + shell_test.go        — shell page builder + 6 pages
├── static.go        + static_test.go       — about, english, more
├── json.go          (extended)             — 6 new JSON endpoints
├── towns_index.go   + towns_index_test.go  — towns index with embedded JSON
├── portfolio.go     + portfolio_test.go    — photo portfolio page
├── views.go         (updated)             — wires up all new views

internal/templates/views/
├── shell.templ                            — <div id="root"> content
├── static_about.templ                     — about page content
├── static_english.templ                   — english page content
├── static_more.templ                      — more page links grid
├── towns_index.templ                      — towns index with script tag

internal/router/router.go                  — 7 new URL methods
internal/pipeline/context.go               — PagesDir() method
cmd/odkrywajac/main.go                     — passes pagesDir to GenerateAllViews
```

## Architecture Decisions

1. **RawEndpoint for XML/text** — no need for separate XMLEndpoint/TextEndpoint types; the existing `RawEndpoint` with custom render function handles all non-HTML output
2. **Sitemap generated last** — receives all other Renderables to collect sitemappable URLs
3. **Shell pages are generic** — single `ShellPage()` function parameterized with bundles, page JS, and page CSS
4. **Static markdown** — simple goldmark render (no custom extensions) for about/english pages
5. **Towns index uses raw script injection** — same pattern as area show pages (templ.Raw for JSON in script tag)
6. **Ideas JSON is a placeholder** — ideas data model not yet in Go, outputs empty arrays

## Test Coverage

- 43 view tests total (up from ~20)
- feed_test.go: RSS XML, Atom XML, sitemap filtering, robots.txt, post limit
- json_test.go: map routes, photos EXIF, GPS filtering, train stations, photo grid, ideas
- shell_test.go: 6 URL tests, render test with div#root and JS refs
- static_test.go: about/english/more URLs, more page links content
- towns_index_test.go: URL, embedded JSON with town data
- portfolio_test.go: URL, best-tagged photo filtering
