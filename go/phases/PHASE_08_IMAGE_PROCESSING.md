# Phase 8: Image Processing Pipeline

## Status: COMPLETE

## Summary

Replaced Crystal image symlink with Go-native image processing. Raw images are
copied to output and resized to 4 sizes × 2 formats (JPEG + AVIF) using
`disintegration/imaging` and `gen2brain/avif`. Worker pool parallelism with
mtime-based caching.

Dev env: 398 source images → 398 raw copies + 3,184 processed files (8 per source).

## What Was Changed

### ProcessImagesNode (pipeline/nodes/process_images.go)
- **Step A — Raw copy**: walks `env/{env}/data/images/{year}/{date-slug}/` for
  each post, copies `.jpg`/`.jpeg`/`.png` to `output/images/{year}/{date-slug}/`
- **Step B — Resize & encode**: for each source image, generates 4 JPEG + 4 AVIF
  variants in `output/images/processed/{year}/{month}/{date-slug}_{filename}_{size}.{format}`
- **Caching**: skips files where output exists and source mtime ≤ output mtime
- **Parallelism**: worker pool with `ctx.Workers` goroutines, one job per source image

### Image Sizes

| Size | Width | Height | JPEG Quality | AVIF Quality |
|------|-------|--------|-------------|-------------|
| article | 1000 | 800 | 85 | 53 |
| card | 700 | 525 | 82 | 53 |
| grid | 560 | 420 | 80 | 53 |
| thumbnail | 150 | 112 | 72 | 53 |

### Symlink Removal (pipeline/nodes/copy_assets.go)
- Removed `symlinkImages()` method and its call from `CopyAssetsNode.Run()`
- Removed 2 symlink-related tests from `copy_assets_test.go`

### Build Integration (cmd/odkrywajac/main.go)
- `ProcessImagesNode` runs after `CopyAssetsNode`, before `PrecomputeVersions`

## Modified Files

```
internal/pipeline/nodes/
├── process_images.go       — NEW: ProcessImagesNode with copy + resize
├── process_images_test.go  — NEW: 3 unit tests (basic, caching, missing dir)
├── copy_assets.go          — removed symlinkImages()
├── copy_assets_test.go     — removed 2 symlink tests

e2e/
└── images_test.go          — NEW: 3 E2E tests (processed exists, formats, raw)

cmd/odkrywajac/main.go      — wire ProcessImagesNode after CopyAssetsNode
go.mod / go.sum             — added imaging, avif, wazero, purego, x/image
```

## Dependencies Added

- `github.com/disintegration/imaging` v1.6.2 — image resize with Lanczos filter
- `github.com/gen2brain/avif` v0.4.4 — AVIF encoding via WASM (no CGO)

## Performance

- First run (dev, 398 images): ~48s (dominated by AVIF encoding)
- Cached run: <1s (all skipped via mtime check)

## Test Coverage

- 3 unit tests: basic processing, mtime caching, missing source dir
- 3 E2E tests: processed image HTTP 200, JPEG+AVIF formats, raw directory
- 261 total test cases across all packages
