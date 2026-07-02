# Phase 7: Input-Hash Caching, SVG Refactor, Foreign Areas

## Status: COMPLETE

## Summary

Added input-hash caching system that skips rendering when inputs haven't changed.
Full build dropped from ~678ms to ~395ms by caching 778 SVG maps and skipping 3313
SHA256-unchanged files. Also refactored SVG map params, added foreign area support,
and fixed 5 posts with duplicate YAML keys.

## What Was Changed

### InputHasher Caching (render/engine.go, view/page.go)
- **InputHasher interface** — views optionally implement `InputHash() string` to declare
  their input fingerprint (based on post slugs, photo counts, config, etc.)
- **Engine checks** `env/{env}/cache-go/input_hashes/{url_hash}` before rendering; if the
  stored hash matches, the view is skipped entirely
- **Build summary** reports input-cached count alongside SHA256-skipped and written counts
- **778 SVG maps** cached on second full build (biggest win — SVGs are expensive to render)

### SvgMapParams Refactor (svg/renderer.go, view/photo_map.go)
- Unified `MapConfig` + `PhotoMapData` into single `SvgMapParams` struct
- `SvgMapView` wraps params as `Renderable` + `InputHasher`
- Cleaner separation: params struct defines data, view defines URL and rendering

### ForeignSlugs + AreaTypeExternal (model/post.go, model/area.go, index/site_data.go)
- **Post.ForeignSlugs** — new field for foreign country references in front matter
- **AreaTypeExternal** — new area type with Polish slugs `zagranica`/`zagranica`
- **Auto-creation** — external areas created on the fly from post references
- Integrates with existing area index (PostsForArea, AreasWithPosts)

### YAML Duplicate Key Fixes
Fixed 5 post markdown files with duplicate YAML front matter keys:
- `2014-03-29-petla-wokol-murowanej-gosliny.md` — duplicate `distance`
- `2018-01-04-podsumowanie-roku-2017.md` — duplicate `header_nogallery`
- `2018-04-02-recenzja-fotoksiazki-saal.md` — duplicate key
- `2018-12-31-podsumowanie-roku-2018.md` — duplicate key
- `2023-04-21-testujac-rower-i-drona.md` — duplicate `distance`

## Modified Files

```
internal/render/
├── engine.go                — InputHasher check before render, cache read/write
├── manifest.go              — input_hashes/ cache directory support
├── writer.go                — report input-cached count in summary

internal/svg/
└── renderer.go              — SvgMapParams, SvgMapView (Renderable + InputHasher)

internal/view/
├── page.go                  — InputHasher interface definition
├── photo_map.go             — refactored to use SvgMapParams + SvgMapView
├── photo_map_test.go        — updated for new SvgMapView API
├── views.go                 — register SVG views via SvgMapView

internal/model/
├── post.go                  — ForeignSlugs field
├── area.go                  — AreaTypeExternal constant + slug methods

internal/index/
└── site_data.go             — auto-create external areas, ForeignSlugs indexing

internal/loader/
└── posts.go                 — parse foreign field from front matter

cmd/odkrywajac/main.go       — pass cache dir to engine

data/posts/...                — 5 files with duplicate YAML keys fixed
```

## Architecture Decisions

1. **InputHasher is opt-in** — only views that benefit from caching implement it; most HTML views are cheap enough to always render
2. **Hash storage is file-based** — one file per URL in `cache-go/input_hashes/`, content is the hash string; simple, no serialization
3. **SHA256 skip is orthogonal** — InputHasher prevents rendering, SHA256 skip prevents file I/O; both can apply to different views
4. **SvgMapView as Renderable** — SVG maps are now proper views in the registry, not ad-hoc render calls
5. **External areas auto-created** — no config file needed; area entity created from first post reference

## Performance Impact

| Metric | Before | After |
|--------|--------|-------|
| Full build (first run) | ~678ms | ~678ms (no cache yet) |
| Full build (cached) | ~678ms | ~395ms |
| SVGs rendered (cached) | 778 | 0 (all input-cached) |
| SHA256-skipped files | ~3313 | ~3313 |

## Test Coverage

- photo_map_test.go updated for SvgMapView API
- InputHasher behavior tested via integration (build twice, verify skip count)
- 255 total test cases across all packages
