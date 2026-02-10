# Renderer & Views Refactoring - Future Work

This document contains ideas and plans for future phases (beyond current work).

---

## Phase 5: View Decoupling - COMPLETE

**Status**: All views migrated to `context: RenderContext`. See PLAN.md for details.

- [x] 55+ views migrated
- [x] Photo Map Views (10 files) - migrated, `Map::Base` now takes `posts` parameter
- [x] `IdeaEntity#routes` updated to take `data_path` instead of `blog`

**External dependency (unchanged):**
- `SiteMapGenerator` in Tremolite library still uses `blog`

---

## Phase 6: Nice to Have

### Image Size Optimization

1. [ ] Check defined image size (downscaled photos). Some may not be needed, some should be changed
2. [ ] Analyze where sizes are used (check json serializers)
3. [ ] Write documentation about sizes we use
4. [ ] Tweak sizes to suit current width of post (images could be bigger on laptop)
5. [ ] Consider stronger jpeg compression

---

## Phase 7: New Features

### Town/Voivodeship Show Pages

Frontend page render as standalone html in `env/<env>/public/<target>/test.html`.

1. [ ] Create "show" page for towns and voivodeships with:
   - Leaflet JS map with polygon area rendered (frozen, no zoom/move)
   - Gradient transparency to middle of page
   - Best photos on map (like Panoramio)
   - Important stats (distance on foot, bicycle, etc.)

---

## Code Organization Ideas

### `all.cr` Convention

Every directory with multiple `.cr` files should have an `all.cr` that requires all files:

```crystal
# data/src/views/dynamic_view/all.cr
require "./summary_view"
require "./year_stat_report_view"
require "./burnout_stat_view"
# ... etc
```

Benefits:
- Single require for entire namespace: `require "./dynamic_view/all"`
- No need to track individual file names at call sites
- Adding new view only requires updating `all.cr`

Directories with `all.cr`:
- [x] `views/dynamic_view/`
- [x] `views/static_view/`
- [x] `views/post_list_view/`
- [x] `views/gallery_view/`
- [x] `views/special_view/`
- [x] `views/photo_map/`
- [x] `views/model_view/`

**Status:** All view directories have `all.cr` - COMPLETE

### Debug Views Reorganization ✓ COMPLETE

Debug views moved to separate `DebugView` namespace:
- [x] Created `DebugView` namespace in `views/debug_view/`
- [x] URLs unchanged (`/debug/*`)
- [x] Priority unchanged (100+, runs last)
- [x] Views migrated:
  - `DynamicView::DebugPostView` → `DebugView::PostsView`
  - `DynamicView::DebugPostCameraStuffView` → `DebugView::CameraStuffView`
  - `DynamicView::DebugPostMissingPhotosExifView` → `DebugView::MissingExifView`
  - `DynamicView::DebugTagStatsView` → `DebugView::TagStatsView`

---

## BuildContext: Separate Pipeline from Rendering

`RenderContext` currently serves two roles:
1. **View rendering** — read-only data access (posts, entities, router, asset bundles)
2. **Pipeline operations** — mutating services (exif_db, photo_analysis_cache, image_resizer)

PostRenderer uses RenderContext for both: pipeline services to process data, then passes the same context to views for rendering. This conflates two different interfaces.

**Proposed split:**
- **RenderContext** — stays read-only, used by views. Remove pipeline service proxies (exif_db, photo_analysis_cache) that views don't need.
- **BuildContext** (new) — holds pipeline/mutating services: exif_db, photo_analysis_cache, image_resizer. Passed to PostRenderer. Contains a reference to RenderContext for the view-rendering step.

**Benefits:**
- Clear separation: views can't accidentally call `save_cache()` or `process_photos()`
- PostRenderer dependencies become explicit through BuildContext
- Adding new pipeline services doesn't pollute the view interface
- Easier to reason about what views can and cannot do

**When to do:** When the pipeline grows beyond 2-3 services, or during next major refactor.

---

## Missing GPS Geotags (Manual Task)

Posts that have a route (GPX/JSON) but photos without GPS coordinates. This indicates photos that should have been geotagged but weren't (human error during import/processing). 100 posts have exactly 1 photo missing GPS — likely the header image, probably fine.

### ALL photos missing GPS (11 posts) — highest priority

| Post | Type | Distance | Missing |
|------|------|----------|---------|
| 2013-07-20-z-wielkiej-raczy-na-rycerzowa | hike | 16km | 25/25 |
| 2018-01-20-trudno-trafic-na-zimowy-zachod-slonca | hike | 11km | 22/22 |
| 2018-07-07-plasko-zle-gory-zle | bicycle | 62km | 39/39 |
| 2018-07-08-wschodnie-przedgorze-sudeckie | bicycle | 74km | 80/80 |
| 2018-07-09-opuszczajac-nyse-na-polnoc | bicycle | 22km | 9/9 |
| 2018-07-29-okolica-jankowa-dolnego | hike | 9km | 40/40 |
| 2016-08-20-mialy-byc-pagorki-a-pozniej-morze | bicycle | 90km | 11/11 |
| 2014-03-29-petla-wokol-murowanej-gosliny | bicycle | 75km | 1/1 |
| 2014-11-11-wokol-jeziora-kierskiego | bicycle | 45km | 1/1 |
| 2015-08-09-do-gluszynki | bicycle | 26km | 2/2 |
| 2016-10-20-radojewo-i-okolice-warty | hike | 3km | 1/1 |

### >50% photos missing GPS (8 posts)

| Post | Type | Distance | Missing |
|------|------|----------|---------|
| 2018-05-01-poludniowe-kaszuby-i-kociewie | bicycle | 106km | 36/45 |
| 2018-06-14-zachod-w-kolobrzegu | hike | 10km | 29/38 |
| 2018-08-11-co-mozna-robic-w-tykocinie-gdy-pada-deszcz | bicycle | 14km | 38/66 |
| 2018-06-01-upalny-piaszczysty-dojazd-do-pszczewa | bicycle | 43km | 10/14 |
| 2013-11-30-pierwsze-wejscie-na-sniezke | hike | 11km | 13/21 |
| 2016-08-26-powrot-z-przedgorza-sudeckiego | bicycle | 98km | 5/8 |
| 2016-09-25-ze-skokow-do-janikowa | bicycle | 77km | 6/8 |
| 2014-07-14-z-sianozet-do-dabek | bicycle | 61km | 3/5 |

### 2+ photos missing GPS, <=50% (82 posts)

<details>
<summary>Click to expand full list</summary>

| Post | Type | Distance | Missing |
|------|------|----------|---------|
| 2012-05-03-krotka-trasa-przez-ropki | hike | 10km | 4/14 |
| 2013-03-02-z-pttk-odrodzenia-pod-dom-slaski | hike | 8km | 2/16 |
| 2013-07-19-podejscie-ze-zwardonia-na-wielka-racze | hike | 17km | 9/29 |
| 2013-07-21-zejscie-z-rycerzowej-do-rajczy | hike | 15km | 5/10 |
| 2013-07-22-z-miedzylesia-do-schroniska-pod-snieznikiem | hike | 21km | 6/18 |
| 2013-07-24-zejscie-do-miedzygorza-przez-czarna-gore | hike | 14km | 3/11 |
| 2013-10-19-fotowarsztaty-w-gorach-stolowych | hike | ? | 6/49 |
| 2013-11-11-fotowarsztaty-w-bieszczadach | car | ? | 9/19 |
| 2013-12-01-zejscie-przez-samotnie-do-karpacza | hike | 9km | 3/8 |
| 2014-01-03-okolice-gluszycy | hike | 6km | 2/10 |
| 2014-07-15-z-dabek-do-ustki | bicycle | 57km | 4/9 |
| 2014-10-19-fotowarsztaty-w-gorach-stolowych | hike | ? | 2/24 |
| 2015-02-01-drugie-zimowe-wejscie-na-sniezke | hike | 14km | 8/21 |
| 2015-08-22-z-rebusza-do-cieszyno | bicycle | 110km | 2/14 |
| 2015-12-30-poczatek-sylwestra-w-maciejowej | hike | 6km | 6/15 |
| 2015-12-31-przechadzka-na-turbacz | hike | 22km | 8/21 |
| 2016-07-23-rowerem-przez-pieniny | bicycle | 35km | 2/14 |
| 2016-08-25-pagorkami-ze-strzelina-do-zarowa | bicycle | 83km | 4/12 |
| 2016-09-03-zachodnie-okolice-dobiegniewa | hike | 30km | 2/31 |
| 2017-04-16-paluckie-pagorki | car | 100km | 2/17 |
| 2017-07-28-z-krempnej-do-jaslisk | bicycle | 44km | 7/19 |
| 2017-10-22-palac-w-kamiencu-zabkowickim | hike | 9km | 4/15 |
| 2018-01-07-mewia-lacha | hike | 7km | 8/33 |
| 2018-01-08-wschod-nad-baltykiem | hike | 2km | 12/29 |
| 2018-02-03-fokarium-na-helu | hike | 8km | 6/24 |
| 2018-02-04-orlowskie-kamyczki | hike | 4km | 2/21 |
| 2018-04-29-swornegacie-i-zaborski-park-krajobrazowy | bicycle | 72km | 8/27 |
| 2018-05-02-dojazd-na-kociewie | bicycle | 64km | 7/25 |
| 2018-05-03-wzdluz-brdy-do-rytla | bicycle | 49km | 2/19 |
| 2018-05-05-petla-wokol-jezior-wdzydzkich | bicycle | 101km | 7/61 |
| 2018-05-06-petla-wokol-jeziora-borzechowskiego | bicycle | 37km | 2/21 |
| 2018-05-19-przez-wioski-do-kruszwicy | bicycle | 73km | 4/38 |
| 2018-05-31-dojazd-do-trzciela | bicycle | 15km | 3/7 |
| 2018-05-31-trzciel-miasto-kotow-i-starych-domow | hike | 9km | 16/35 |
| 2018-06-02-w-strone-miedzyrzecza | bicycle | 37km | 6/20 |
| 2018-06-03-lubuskie-pagorki-do-sieniawy | bicycle | 73km | 5/53 |
| 2018-07-15-eksplorujac-puszcze-notecka | bicycle | 91km | 22/56 |
| 2018-07-23-parowozem-do-suwalk | train | 470km | 4/109 |
| 2018-08-04-przez-piaski-do-kruszynian | bicycle | 62km | 18/66 |
| 2018-08-05-swisloczany-i-granica-z-bialorusia | bicycle | 40km | 3/55 |
| 2018-08-06-pod-wiatr-do-sokolki | bicycle | 60km | 16/42 |
| 2018-08-08-jadac-wzdluz-biebrzy | bicycle | 50km | 25/84 |
| 2018-08-09-jeszcze-wiekszy-upal-wiec-tylko-do-osowca | bicycle | 29km | 8/29 |
| 2018-08-12-narwianski-park-narodowy-w-remoncie | bicycle | 59km | 14/81 |
| 2018-08-21-sladami-zlikwidowanej-linii-z-wagrowca-do-bydgoszczy | bicycle | 102km | 3/27 |
| 2018-08-27-dwa-dni-nostalgii-kolejowej | train | 726km | 4/98 |
| 2018-09-22-proba-obserwacji-ptakow-przy-rzece-postomia | hike | 16km | 23/74 |
| 2018-10-06-zakonczenie-sezonu-rowerowego-w-2018 | bicycle | 98km | 5/29 |
| 2018-10-08-wieczor-w-wojanowie | hike | 5km | 4/41 |
| 2018-11-04-wioski-na-zachod-od-bystrzycy | hike | 18km | 12/148 |
| 2018-12-09-kiedy-nie-jechac-w-gory | hike | 4km | 6/78 |
| 2019-02-17-polowanie-na-koty | hike | 7km | 12/47 |
| 2019-02-23-pierwsze-dzikie-foki | hike | 8km | 10/56 |
| 2019-02-24-dwa-wschody-w-sopocie | hike | 8km | 6/29 |
| 2019-06-01-male-labedzie-w-lubniewicach | hike | 11km | 23/91 |
| 2019-06-02-przez-trzy-rzeki | bicycle | 67km | 2/81 |
| 2019-06-15-okolice-promna | hike | 7km | 3/41 |
| 2019-07-03-lodz-i-linia-tramwajowa-41 | train | ? | 3/49 |
| 2019-07-13-okolice-drawskiego-parku-krajobrazowego | bicycle | 87km | 10/120 |
| 2019-07-21-pelna-klatka-na-szosie | bicycle | 20km | 6/21 |
| 2019-07-28-eksploracja-jezior-mogilna | bicycle | 36km | 4/31 |
| 2019-08-24-dojazd-w-inski-park-krajobrazowy | bicycle | 46km | 2/99 |
| 2019-08-24-wieczor-w-insko | hike | 5km | 2/41 |
| 2019-09-28-z-kobylnicy-do-kicina | hike | 7km | 5/60 |
| 2019-10-06-jesienne-okolice-puszczy-zielonki | hike | 6km | 2/54 |
| 2019-10-11-mgielek-nie-bylo | hike | 4km | 6/85 |
| 2019-10-12-wietrzny-grzbiet-karkonoszy | hike | 22km | 2/105 |
| 2019-10-24-taka-wiosenna-jesien | hike | 22km | 12/132 |
| 2019-11-17-drezyna-do-chrzypska-wielkiego | train | 16km | 3/36 |
| 2020-10-09-swietokrzyskie-koleja | train | 4km | 2/111 |
| 2020-11-14-niepoznane-okolice-kruszwicy | car | 120km | 2/48 |
| 2021-05-01-zimna-majowka | hike | 3km | 3/28 |
| 2021-05-11-z-murowanej-gosliny-do-sokolowa-budzynskiego | bicycle | 46km | 2/50 |
| 2021-05-22-najlepsze-co-w-wielkopolsce | bicycle | 90km | 2/89 |
| 2021-05-30-centrum-gniezna | hike | ? | 2/11 |
| 2021-05-30-pociagiem-z-wagrowca-do-gniezna | train | 120km | 3/73 |
| 2021-06-05-tutaj-nie-ma-nic | bicycle | 103km | 4/88 |
| 2021-08-27-wokol-jeziora-rydzowka | bicycle | 28km | 9/120 |
| 2021-09-11-rezerwat-jezioro-czarne | hike | 9km | 2/33 |
| 2021-09-12-poludniowy-brzeg-jeziora-kowalskiego | hike | 9km | 2/90 |
| 2022-09-03-lednogora-i-okolice | bicycle | 60km | 2/20 |
| 2023-10-18-mgielki-w-pobiedziskach | hike | 5km | 6/27 |

</details>

---

## Testing Improvements

Future testing enhancements:
- [ ] Snapshot testing for HTML output
- [ ] Integration tests for full coordinator
- [ ] More tests for photo, feed, debug views
