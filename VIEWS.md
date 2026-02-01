# Views Documentation

This document describes all active views in the project, when they render, and what data they need.

## Render Flow Overview

The rendering is orchestrated by `Blog#render` method in `data/src/blog.cr`. It calls various renderer methods based on what changed:

```
Blog#make_it_so
  └── Blog#render
       ├── If exifs_changed:
       │    ├── renderer.render_all_photo_related
       │    └── renderer.render_all_photo_maps
       ├── If posts_changed:
       │    └── renderer.render_fast_only_post_related
       ├── If posts_changed || yamls_changed:
       │    └── renderer.render_fast_post_and_yaml_related
       └── Always:
            └── renderer.render_fast_static_renders
```

For full renders (`force_full_render=true`), all conditions are true.

---

## Views by Category

### PostListView (Entity Collection Pages)

These views render pages that list posts filtered by entity (town, tag, voivodeship, land).

| View Class | URL Pattern | Trigger | Renderer Method |
|------------|-------------|---------|-----------------|
| `CollectionDynamicView` | `/` | posts_changed | `render_home_new` |
| `NewPostsDynamicView` | `/nowosci.html` | posts_changed | `render_last_updated_posts` |
| `TownDynamicView` | `/gminy/{slug}.html` | posts+yamls_changed | `render_town_page` |
| `TagDynamicView` | `/tagi/{slug}.html` | posts+yamls_changed | `render_tag_page` |
| `VoivodeshipDynamicView` | `/wojewodztwa/{slug}.html` | posts+yamls_changed | `render_voivodeship_page` |
| `LandDynamicView` | `/krainy/{slug}.html` | posts+yamls_changed | `render_land_page` |
| `PaginatedListView` | `/list/`, `/list/page/{n}` | posts_changed | `render_posts_paginated_lists` |

**Data dependencies**: All require `blog.post_collection.posts` and respective entity data from `data_manager`.

---

### DynamicView (Data-Heavy Pages)

These views do significant data processing to render statistics, timelines, reports.

| View Class | URL | Trigger | Renderer Method |
|------------|-----|---------|-----------------|
| `SummaryView` | `/zestawienie.html` | posts+yamls_changed | `render_summary` |
| `YearStatReportView` | `/rok/{year}.html` | posts+yamls_changed | `render_year_stat_reports` |
| `BurnoutStatView` | `/burnout.html` | posts+yamls_changed | `render_burnout_stat` |
| `TownsHistoryView` | `/gminy/historia.html` | posts+yamls_changed | `render_towns_history` |
| `TownsTimelineView` | `/gminy/chronologicznie.html` | posts+yamls_changed | `render_towns_timeline` |
| `PortfolioView` | `/portfolio.html` | exifs_changed | `render_portfolio` |
| `ExifStatsView` | `/exif_stats/` | exifs_changed | `render_exif_stats` |
| `TimelinePhotoView` | `/galeria/timeline.html` | exifs_changed | `render_gallery_stats` |
| `DebugPostView` | `/debug/posts.html` | posts_changed | `render_debug_posts` |
| `DebugTagStatsView` | `/debug/photo_tags.html` | exifs_changed | `render_gallery_stats` |
| `DebugPostCameraStuffView` | `/debug/camera_stuff.html` | exifs_changed | `render_debug_post_camera_stuff` |
| `DebugPostMissingPhotosExifView` | `/debug/missing_exif.html` | exifs_changed | `render_debug_post_photos_missing_exif` |
| `MountainRangePlannerView` | `/mountain_range_planner/` | posts_changed | `render_mountain_range_planner` |

**Note**: `MountainRangePlannerView` is marked DEPRECATED in code but still renders.

---

### StaticView (JS-Heavy Pages)

These views render simple HTML shells that load JavaScript for interactivity. Minimal server-side processing.

| View Class | URL | Trigger | Renderer Method |
|------------|-----|---------|-----------------|
| `MapView` | `/mapa.html` | posts_changed | `render_map` |
| `JsIdeasView` | `/pomysly.html` | posts_changed | `render_js_ideas` |
| `JsTimelineView` | `/linia_czasu.html` | posts_changed | `render_js_timeline` |
| `JsPanoramioView` | `/mapa2.html` | posts_changed | `render_js_panoramio` |
| `JsExifView` | `/exif_statystyki.html` | posts_changed | `render_js_exif_stats` |
| `JsBicyclePlannerView` | `/pomysly2.html` | posts_changed | `render_js_timeline` (duplicate method) |
| `MoreView` | `/wiecej.html` | always | `render_more` |
| `MarkdownPageView` | `/o_mnie.html`, `/en/index.html` | always | `render_about`, `render_en` |

---

### PostView (Individual Post Pages)

| View Class | URL | Trigger | Renderer Method |
|------------|-----|---------|-----------------|
| `ArticleView` | `/wpisy/{slug}.html` | per-post (changed posts) | `render_post` |

**Data dependencies**: Single post object, EXIF data for photos.

---

### GalleryView (Photo Galleries by EXIF)

All gallery views are triggered by `exifs_changed` via `render_all_photo_related`.

| View Class | URL Pattern | Description |
|------------|-------------|-------------|
| `IndexView` | `/galeria/` | Main gallery index |
| `TagView` | `/galeria/tagi/{tag}.html` | Photos by photo tag |
| `TagIndexView` | `/galeria/tagi/` | Photo tags index |
| `CameraView` | `/galeria/aparaty/{camera}.html` | Photos by camera |
| `CameraIndexView` | `/galeria/aparaty/` | Cameras index |
| `LensView` | `/galeria/obiektywy/{lens}.html` | Photos by lens |
| `LensIndexView` | `/galeria/obiektywy/` | Lenses index |
| `FocalLengthView` | `/galeria/ogniskowe/{range}.html` | Photos by focal length |
| `FocalLengthIndexView` | `/galeria/ogniskowe/` | Focal lengths index |
| `IsoView` | `/galeria/iso/{range}.html` | Photos by ISO |
| `IsoIndexView` | `/galeria/iso/` | ISO index |
| `ExposureView` | `/galeria/naswietlenie/{range}.html` | Photos by exposure |
| `ExposureIndexView` | `/galeria/naswietlenie/` | Exposure index |
| `QuantCoordView` | `/galeria/lokalizacje/{coords}.html` | Photos by location grid |
| `QuantCoordIndexView` | `/galeria/lokalizacje/` | Locations index |

---

### PhotoMap (SVG Map Views)

All photo map views are triggered by `exifs_changed` via `render_all_photo_maps`.

| View Class | URL Pattern | Description |
|------------|-------------|-------------|
| `IndexView` | `/mapy/` | Photo maps index |
| `GlobalDotsMapSvgView` | `/mapy/dots.svg` | All photo locations as dots |
| `GlobalGridMapSvgView` | `/mapy/grid.svg` | Photo density grid |
| `GlobalGridAndRoutesMapSvgView` | `/mapy/grid_routes.svg` | Grid + routes overlay |
| `GlobalAnimatedRoutesMapSvgView` | `/mapy/animated.svg` | Animated routes |
| `PostRouteMapSvgView` | `/mapy/trasa/{slug}.svg` | Single post route |
| `PostBigMapSvgView` | `/mapy/duza/{slug}.svg` | Large post map |
| `MultiplePostsGridAndRoutesMapSvgView` | various | Multiple posts combined |
| `MultiplePhotoEntitiesGridMapSvgView` | various | Photo grid for entities |
| `IdeaRouteMapSvgView` | `/mapy/pomysly/{idea}.svg` | Idea route map |

**Note**: PhotoMap views are functional but the user mentioned focusing more on JS Leaflet going forward.

---

### SpecialView (Feeds & Data Files)

| View Class | URL | Trigger | Renderer Method |
|------------|-----|---------|-----------------|
| `RssGenerator` | `/feed.xml` | posts+yamls_changed | `render_rss` |
| `AtomGenerator` | `/feed_atom.xml` | posts+yamls_changed | `render_atom` |
| `PayloadJsonGenerator` | `/data/payload.json` | posts+yamls_changed | `render_payload_json` |
| `PhotosJsonGenerator` | `/data/photos.json` | posts+yamls_changed | `render_photos_json` |
| `IdeasJsonGenerator` | `/data/ideas.json` | posts+yamls_changed | `render_ideas_json` |
| `TrainStationsJsonGenerator` | `/data/train_stations.json` | posts+yamls_changed | `render_train_stations_json` |
| `NavStatsJsonGenerator` | `/data/nav_stats.json` | posts+yamls_changed | `render_nav_stats_json` |
| `RedirectView` | `/{old_url}` | posts_changed | `render_posts_redirects` |

Also from Tremolite library:
- `SiteMapGenerator` → `/sitemap.xml`
- `RobotGenerator` → `/robots.txt`

---

### ModelView (Index Pages)

| View Class | URL | Trigger | Renderer Method |
|------------|-----|---------|-----------------|
| `TownsIndexView` | `/gminy.html` | posts+yamls_changed | `render_towns_index` |
| `LandView` | `/krainy.html` | posts+yamls_changed | `render_lands_index` |

---

## Renderer Mixin Organization

| Mixin | Purpose | Key Methods |
|-------|---------|-------------|
| `Accessors` | Helper methods | `blog`, `posts_descending`, `validator` |
| `RenderFast` | Quick renders (home, static pages) | `render_home_new`, `render_map`, `render_more`, `render_about`, `render_summary`, `render_year_stat_reports`, `render_burnout_stat`, `render_towns_history`, `render_towns_timeline` |
| `RenderPostRelated` | Post-dependent renders | `render_posts_paginated_lists`, `render_post`, `render_posts_redirects`, `render_debug_posts`, `render_last_updated_posts`, `render_mountain_range_planner` |
| `RenderPhotoRelated` | Photo gallery renders | `render_all_photo_related`, `render_*_galleries`, `render_portfolio`, `render_exif_stats` |
| `RenderPhotoMaps` | SVG map renders | `render_all_photo_maps`, `render_photo_maps_*` |
| `RenderTags` | Tag page renders | `render_tags_pages`, `render_tag_page` |
| `RenderTowns` | Town page renders | `render_towns_pages`, `render_town_page`, `render_towns_index` |
| `RenderVoivodeships` | Voivodeship page renders | `render_voivodeships_pages`, `render_voivodeship_page` |
| `RenderLands` | Land page renders | `render_lands_pages`, `render_land_page`, `render_lands_index` |
| `RenderSpecial` | Feeds and JSON | `render_rss`, `render_atom`, `render_*_json`, `render_sitemap` |
| `RenderOveralls` | Orchestration methods | `render_all_model_pages`, `render_all_views_*`, `render_fast_static_renders` |
| `RenderTodo` | TODO routes | `render_todo_routes` |

---

## Naming Clarification

Current naming is confusing. Here's what terms actually mean:

| Term | Actual Meaning |
|------|----------------|
| "fast" | Renders that don't require EXIF data loading |
| "static" | Pages with minimal server-side processing (JS-heavy) |
| "dynamic" | Pages with significant data processing (stats, reports) |
| `*DynamicView` in PostListView | New pattern - entity pages that load data via JSON |
| `*ListView` | OLD pattern - server-rendered lists (DEPRECATED) |
| `*MasonryView` | OLD pattern - server-rendered masonry grids (DEPRECATED) |

---

## Deprecated Views (To Be Removed)

These views are commented out in renderer mixins and should be deleted:

### PostListView (deprecated patterns)
- `NewPostsView` - replaced by `NewPostsDynamicView`
- `NewPostsMasonryView` - replaced by `NewPostsDynamicView`
- `HomeMasonryView` - replaced by `CollectionDynamicView`
- `TownListView` - replaced by `TownDynamicView`
- `TownMasonryView` - replaced by `TownDynamicView`
- `TagListView` - replaced by `TagDynamicView`
- `TagMasonryView` - replaced by `TagDynamicView`
- `VoivodeshipListView` - replaced by `VoivodeshipDynamicView`
- `VoivodeshipMasonryView` - replaced by `VoivodeshipDynamicView`
- `LandListView` - replaced by `LandDynamicView`
- `LandMasonryView` - replaced by `LandDynamicView`
- `AbstractMasonryView` - base class for deprecated masonry views

### DynamicView
- `TimelineView` - unused, never called

### PhotoMap
- `HtmlView` - unused, never called

---

## Views Needing Refresh (Not Deprecated)

These views work but may need updates/improvements:

- `DynamicView::SummaryView` - needs review
- `DynamicView::BurnoutStatView` - needs review
- `DynamicView::MountainRangePlannerView` - marked DEPRECATED but still used, decide fate
- `PostListView::PaginatedListView` - old pattern but still active, consider migration

---

## Base Classes (Keep)

These are inherited by other views:

- `AbstractListView` - base for paginated views
- `AbstractIndexView` - base for gallery index views
- `AbstractSvgView` - base for photo map SVG views
- `AbstractView` (in GalleryView) - base for gallery views
