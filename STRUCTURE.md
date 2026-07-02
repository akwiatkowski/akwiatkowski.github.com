<!-- Generated and maintained by Claude -->
# Repository Structure

This project builds one static site with **two interchangeable engines** (a
mature Crystal engine and a Go rewrite) from **one shared set of inputs**, driven
by **one build grammar**. The engines mirror each other's internal structure so
you can navigate between them by muscle memory.

## Top level

```
odkrywajacpolske/
├── data/                 # SHARED INPUTS (single source of truth for both engines)
│   ├── config/           #   site config + asset_bundles.yml
│   ├── assets/           #   js / css / fonts (the only asset source)
│   ├── layout/           #   Crystal HTML templates
│   ├── external/         #   source polygon data (towns, counties, regions…)
│   └── pages/            #   static page markdown
├── crystal/              # Crystal engine  (was data/src/)
│   └── src/
├── go/                   # Go engine       (was go-rewrite/)
│   ├── cmd/odkrywajac/   #   entry point (subcommands)
│   └── internal/
├── env/
│   └── {dev,full}/
│       ├── data/         #   posts, images, routes for this env
│       ├── cache/        #   Crystal caches
│       ├── cache-go/     #   Go caches (per-engine, per-target manifests)
│       └── public/
│           └── {local,release}/   # OUTPUT — engine-agnostic; both write here.
│                                   # Contains tiles/ (symlink) + images/.
├── spec/                 # Crystal specs (run from repo root)
├── tests/e2e/            # Playwright e2e (engine-agnostic; hits the output)
├── commands/             # Crystal CLI wrappers
├── makefile              # unified build (ENV × TARGET × ENGINE)
└── STRUCTURE.md          # this file
```

Map tiles (~23 GB) live outside the repo at `~/projects/llm/input/tiles/ump` and
are symlinked into every `env/*/public/*/tiles`. Never `rm -rf` a `public/` dir.

## Build grammar — three orthogonal axes

| Axis | Values | Controls |
|---|---|---|
| `ENV` | `dev` \| `full` | how much input content (subset vs all posts) |
| `TARGET` | `local` \| `release` | draft visibility (release hides not-ready posts) |
| `ENGINE` | `go` \| `crystal` | which renderer produces the bytes |

Output is engine-agnostic: `env/<ENV>/public/<TARGET>`. Both engines write there;
a `.engine` marker forces a full rebuild when the other engine last wrote the dir.
Caches are per-engine (`cache/` vs `cache-go/`). URL scheme and asset versioning
are target-independent; the only behavioural TARGET difference is draft hiding.

```
make render                                    # go + dev + local (defaults)
make render ENGINE=crystal                     # Crystal instead of Go
make render ENV=full TARGET=release ENGINE=go  # full release build
make serve ENV=dev TARGET=local                # serve output (engine-agnostic)
make test [ENGINE=crystal]                     # unit tests
make purge                                     # delete generated html/xml/json/svg
                                               #   (never images or tiles)
```
Generated aliases: `render-<env>-<target>-<engine>`, `serve-<env>-<target>`.

## Shared vocabulary — concept → engine location

| Concept | `go/internal/` | `crystal/src/` |
|---|---|---|
| orchestration | `cmd/odkrywajac` (build) | `blog.cr` |
| render/build context | (passed structs) | `context/` |
| load inputs → indexes | `catalog` | `catalog/` (DataManager) |
| posts + markdown | `content` | `content/` (post*) |
| domain models | `model` | `model/` |
| router | `service/router` | `service/router.cr` |
| spatial matching (GEOS) | `service/spatial` | `service/area_matcher/` |
| map / SVG rendering | `service/svg` | `service/map/` |
| EXIF | `service/exif` | `service/exif_stat/` |
| asset bundles | `service/bundle` | `service/asset_bundle_loader.cr` |
| image resize | `service/image` | `service/image.cr` |
| html validation | `render/validate.go` | `service/html_validators/`, `render/validator.cr` |
| render engine / registry | `render` | `render/` (registry + coordinator + validator) |
| view builders / classes | `view` | `view/` |
| templates | `view/template/` (templ) | `data/layout/*.html` |
| data pipeline | `pipeline/` (+ `nodes/`) | `commands/pipeline/` |
| CLI tools | `cmd` subcommands | `commands/` (+ `commands/tools/`) |
| draft-from-Strava | `draft/` (+ strava, gpx, weather) | (skill + commands) |
| polygon/area config gen | `geodata/` | `commands/pipeline/` |
| vendored framework | — | `framework/` (Tremolite) |

## Why the two trees aren't identical

The engines converge on a shared *vocabulary*, not byte-identical trees — a few
places where a literal mapping would fight a language's idiom were adapted
deliberately:

- **`service/svg` vs `service/map`** — `map` is a Go keyword; Go uses `svg`,
  Crystal uses `map`.
- **HTML validation placement** — Go keeps it inside `render` (called inline;
  `ValidationError` is part of `render.Result`, and a `html` package would clash
  with `x/net/html`). Crystal keeps richer validators under `service/`.
- **Service leaf names** — Crystal keeps `area_matcher`/`exif_stat`; Go uses the
  shorter `spatial`/`exif`. The `service/` umbrella is the shared anchor.
- **Templates** — Crystal renders `data/layout/*.html`; Go uses compiled `templ`
  under `view/template/`. Different templating tech, can't unify.
- **`catalog`** — Go merged its `loader`+`index`; Crystal keeps `DataManager`.
  Both live under `catalog/`.

See `~/projects/claude/plans/odkrywajacpolske.md` for the full convergence history.
