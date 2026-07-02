# odkrywajac_polske

Crystal static site generator for a Polish travel/photography blog. Custom-built on [tremolite](https://github.com/akwiatkowski/tremolite) framework.

**Live site:** [odkrywajacpolske.pl](http://odkrywajacpolske.pl)

## Quick Start

```bash
# Render site (dev environment, local target)
make dev-render-local

# Serve locally
make dev-serve-local  # http://localhost:5001

# Run Crystal tests
crystal spec

# Run E2E tests (requires: cd tests/e2e && npm i && npx playwright install chromium)
make test-e2e
```

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| Crystal | [crystal-lang.org](https://crystal-lang.org/install/) | Build & run |
| ImageMagick 7+ | `brew install imagemagick` | Image resizing (`magick` command) |
| libavif | `brew install libavif` | AVIF encoding (`avifenc` command) |
| Node.js | `brew install node` | JSX transpilation, E2E tests |

## Project Structure

```
env/
├── dev/                    # Dev environment (subset of posts)
│   ├── src/               # Entry points (render_local.cr, render_release.cr)
│   ├── public/local/      # Output for local dev
│   └── public/release/    # Output for production
└── full/                   # Full environment (all posts)

data/
├── src/                    # Core application code
│   ├── blog.cr            # Main orchestrator
│   ├── view_registry/     # View registration system
│   ├── views/             # All view classes
│   ├── models/            # Entity models (Post, AreaEntity, Tag, etc.)
│   └── services/          # Business logic (asset loading, validation, etc.)
├── assets/                 # Static assets (CSS, JS, images)
├── layout/                 # HTML templates
├── posts/                  # Markdown blog posts
├── routes/                 # GPX route files
└── config/                 # YAML configurations

commands/                   # Standalone scripts
tests/e2e/                  # Playwright E2E tests
spec/                       # Crystal unit tests
```

## Commands

| Command | Description |
|---------|-------------|
| `make dev-render-local` | Compile & render dev site |
| `make dev-serve-local` | Serve dev site on :5001 |
| `make render-local` | Render full site |
| `make test-e2e` | Run Playwright tests |
| `make test-e2e-headed` | Run E2E with visible browser |
| `crystal spec` | Run Crystal unit tests |
| `npm run build:js` | Build JSX → JS (esbuild) |
| `crystal run commands/spellcheck.cr` | Polish spellcheck via LanguageTool |
| `crystal run commands/run_all.cr` | Run full data pipeline |

## Features (Compact)

### Content System
- **Posts**: Markdown with YAML frontmatter, multi-route support, photo galleries
- **Areas**: Unified entity system (towns, counties, voivodeships, meso/macro regions) with polygon matching
- **Tags**: Hierarchical with Polish slugs, auto-generated galleries
- **Routes**: GPX parsing, distance calculation, area intersection detection

### Rendering
- **View Registry**: Priority-based rendering (tasks 1-9, views 10+), dependency tracking
- **Asset Bundles**: Declarative CSS/JS bundles with integrity hashes, cache busting
- **Templates**: ECR + HTML templates with placeholder substitution
- **Output**: HTML, RSS, Atom, JSON payload, sitemap, photos.json

### Frontend
- **Maps**: Leaflet for routes, Preact interactive components
- **Galleries**: Lazy-loaded images, ambilight lightbox, EXIF display
- **Interactive**: Timeline, photo planner, area statistics, POIs map

### Infrastructure
- **Environments**: dev (fast iteration) / full (complete render)
- **Caching**: Area calculations, nav stats, EXIF data
- **Validation**: HTML validators (accessibility, links, duplicates), asset verification
- **History**: Output change tracking per env/target

### Data Pipeline
- **Area Matching**: Route → polygon intersection via AreaMatcher service
- **Polygon Generation**: Douglas-Peucker simplification, GeoJSON output
- **EXIF Processing**: Photo metadata extraction, statistics generation

## Tech Stack

| Layer | Tech |
|-------|------|
| Language | Crystal |
| Framework | tremolite (custom fork) |
| Frontend | Bootstrap 5, Leaflet, Preact |
| Build | Make, esbuild (JSX) |
| Tests | Crystal spec, Playwright |

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | AI assistant context, full project reference |
| `PLAN.md` | Current work, phase tracking |
| `VIEWS.md` | View registry documentation |
| `data/config/asset_bundles.yml` | CSS/JS bundle definitions |

## Tests

**Crystal**: 589 unit tests covering views, services, models, commands
```bash
crystal spec
crystal spec spec/views/  # Views only
```

**E2E**: ~137 Playwright tests across 15 spec files (smoke, posts, maps, galleries, areas, POIs, social meta)
```bash
cd tests/e2e && npm install && npx playwright install chromium
make test-e2e
```

## License

GPLv3

## Author

[Aleksander Kwiatkowski](https://github.com/akwiatkowski)
