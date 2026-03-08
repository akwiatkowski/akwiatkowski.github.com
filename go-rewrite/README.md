# Go Rewrite — Static Site Generator

Go rewrite of the Crystal static site generator for odkrywajacpolske.pl, a Polish travel/photography blog.

## Build

```bash
mise exec -- go run ./cmd/odkrywajac build --env dev --base ..
mise exec -- go run ./cmd/odkrywajac build --env full --base ..
```

## Test

```bash
mise exec -- go test ./...
```

## Architecture

```
cmd/odkrywajac/          CLI entry point
internal/
├── bundle/              Asset bundle resolution (CSS/JS)
├── exif/                EXIF metadata reader
├── index/               SiteData builder (frozen indexes)
├── loader/              YAML/markdown data loaders
├── markdown/            Goldmark extensions (photos, stats, links)
├── model/               Domain types (Post, Photo, Area, Tag, Route)
├── pipeline/            Build pipeline orchestration + image processing
├── render/              File writer with manifest diffing
├── router/              Centralized URL generation
├── svg/                 SVG photo map renderer (projection, spatial index)
├── templates/
│   ├── components/      Reusable templ components
│   ├── layout/          Page wrapper (head, nav, footer)
│   └── views/           Per-page templ templates + shared types
└── view/                View builders (data → Renderable)
```

## URL Catalog

### Posts

| Path | View | Content |
|------|------|---------|
| `/<year>/<month>/<day>-<slug>.html` | `PostArticlePage` | Blog post article with photos, stats, navigation |
| `/galeria/<year>/<month>/<day>-<slug>.html` | `PostGalleryPage` | Full photo gallery for a post |

### Areas (x5 types: gmina, powiat, wojewodztwo, mezoregion, makroregion)

| Path | View | Content |
|------|------|---------|
| `/<type>/<slug>.html` | `AreaShowPage` | Area detail — hero photo, map with polygon, post list, related areas |
| `/wpisy-dla/<type_gen>/<slug>.html` | `AreaPostListPage` | Filtered post list for area |
| `/galeria/<type_gen>/<slug>.html` | `AreaGalleryPage` | Photo gallery for area |

### Tags

| Path | View | Content |
|------|------|---------|
| `/wpisy-dla/tagu/<slug_pl>.html` | `TagPostListPage` | Posts filtered by tag |
| `/galeria/tagu/<slug_pl>.html` | `TagGalleryPage` | Photo gallery filtered by photo tag |
| `/tag/<slug_pl>.html` | `NewRedirectPage` | 302 redirect to tag post list |

### Homepage & Navigation

| Path | View | Content |
|------|------|---------|
| `/index.html` | `HomepagePage` | Homepage with hero, post grid, category chips |
| `/gminy.html` | `TownsIndexPage` | Searchable town index with photo cards, voivodeship groups |
| `/portfolio.html` | `PortfolioPage` | Best-tagged photos gallery |
| `/wiecej.html` | `MorePage` | Links grid to all tool/stats pages |
| `/o-mnie.html` | `AboutPage` | About page (markdown rendered) |
| `/en/index.html` | `EnglishPage` | English about page (markdown rendered) |

### Year Reports & Stats

| Path | View | Content |
|------|------|---------|
| `/rok-<year>.html` | `YearReportPage` | Annual stats: sparklines, photo of year, records, route map |
| `/debug/burnout.html` | `BurnoutPage` | Monthly activity table with year-over-year deltas |
| `/gminy/historia.html` | `TownsHistoryPage` | Towns grouped by voivodeship, first visit dates |
| `/gminy/chronologicznie.html` | `TownsTimelinePage` | Chronological town discovery timeline |

### Photo Galleries

| Path | View | Content |
|------|------|---------|
| `/galeria.html` | `GalleryIndexPage` | Master index linking to all gallery categories |
| `/galeria/obiektyw/<sanitized>.html` | `LensGalleryPage` | Photos shot with specific lens |
| `/galeria/aparat/<sanitized>.html` | `CameraGalleryPage` | Photos shot with specific camera |
| `/galeria/ogniskowa/<from>-<to>.html` | `FocalLengthGalleryPage` | Photos in focal length range |
| `/galeria/czulosc/<from>-<to>.html` | `ISOGalleryPage` | Photos in ISO range |
| `/galeria/ekspozycja/<from>-<to>.html` | `ExposureGalleryPage` | Photos in shutter speed range |

### SVG Photo Maps

| Path | View | Content |
|------|------|---------|
| `/mapa_zdjec/<variant>.svg` | `GlobalMapSVGs` | Full-country photo map (6 variants: overall, coarse, small, detailed, small_detailed, dots) |
| `/mapa_zdjec/wojewodztwo/<slug>_big.svg` | `VoivodeshipMapSVGs` | Large voivodeship photo map |
| `/mapa_zdjec/wojewodztwo/<slug>_small.svg` | `VoivodeshipMapSVGs` | Small voivodeship photo map |
| `/mapa_zdjec/wpis/<slug>_big.svg` | `PostMapSVGs` | Post photo map with route overlay |
| `/mapa_zdjec/wpis/<slug>.svg` | `PostMapSVGs` | Post route map (dots + route) |
| `/mapa_zdjec/tagu/<tag>.svg` | `TagMapSVGs` | Photos filtered by tag on map |

### Shell Pages (JS-heavy, `<div id="root">`)

| Path | View | Content |
|------|------|---------|
| `/mapa_tras.html` | `RouteMapPage` | Interactive Leaflet route map |
| `/mapa_zdjec.html` | `PhotoMapPage` | Interactive photo map (Panoramio-style) |
| `/linia_czasu.html` | `TimelinePage` | Photo timeline visualization |
| `/statystyki_exif.html` | `ExifStatsPage` | EXIF metadata charts and heatmaps |
| `/pomysly_dla_zdjec.html` | `PhotoPlannerPage` | Photo coverage route planner |
| `/pomysly_tras.html` | `TripIdeasPage` | Trip idea browser with maps |
| `/pois.html` | `POIsPage` | Points of interest map with side panel |

### JSON Endpoints

| Path | View | Content |
|------|------|---------|
| `/jsons/e2e.json` | `E2EJSON` | All post metadata for E2E tests |
| `/jsons/homepage.json` | `HomepageJSON` | Optimized homepage data (~6KB) |
| `/jsons/map.json` | `MapJSON` | Posts with GPS route segments |
| `/jsons/photos.json` | `PhotosJSON` | All photos with EXIF metadata |
| `/jsons/photos_map.json` | `PhotosMapJSON` | GPS-tagged photos for map markers |
| `/jsons/train_stations.json` | `TrainStationsJSON` | Station locations + distances |
| `/jsons/photo_grid.json` | `PhotoGridJSON` | Photo coordinate pairs |
| `/jsons/ideas.json` | `IdeasJSON` | Trip ideas data |

### Feeds & Meta

| Path | View | Content |
|------|------|---------|
| `/feed.rss` | `RSSFeed` | RSS 2.0 feed (last 20 posts) |
| `/feed.atom` | `AtomFeed` | Atom 1.0 feed (last 20 posts) |
| `/sitemap.xml` | `Sitemap` | XML sitemap of all sitemappable URLs |
| `/robots.txt` | `RobotsTxt` | Robots directives + sitemap URL |

### Debug (dev only)

| Path | View | Content |
|------|------|---------|
| `/debug/tagged_photos.html` | `TagStatsPage` | Photo tagging statistics per post |
| `/debug/burnout.html` | `BurnoutPage` | Monthly activity table |
