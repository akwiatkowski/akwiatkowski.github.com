# Area Entity Refactoring Plan

## Status: PLANNING

**Goal**: Unified area entity system with 5 area types, calculated route data, photo selection, and Polish URL paths.

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases archive
- `PLAN_FUTURE.md` - Future ideas

---

## Key Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| Entity approach | **Unified AreaEntity** | Single struct with `area_type` enum, not multiple classes |
| Data source | **Supplement** | Manual YAML primary, calculated areas_for_post as additional. Ask for details before implementing |
| Filtering | **Configurable** | Default >1% of route distance |
| Photo selection | **Bbox intersection** | Fallback to closest photo if none in bbox |
| URL paths | **Polish** | `/gminy/`, `/powiaty/`, `/wojewodztwa/`, `/regiony/`, `/obszary/` |
| Multiple routes | **Sum distances** | Combine all routes in a post |
| Backward compat | **Not needed** | Clean break, app works after finishing |
| Post entity access | **Memoization** | Hide old `.towns`/`.lands` interface |

---

## Area Types (5)

| Type | Polish | URL Prefix | Entity |
|------|--------|------------|--------|
| Town | gmina | `/gminy/` | AreaEntity (type: Town) |
| County | powiat | `/powiaty/` | AreaEntity (type: County) |
| Voivodeship | województwo | `/wojewodztwa/` | AreaEntity (type: Voivodeship) |
| MesoRegion | region | `/regiony/` | AreaEntity (type: MesoRegion) |
| MacroRegion | obszar | `/obszary/` | AreaEntity (type: MacroRegion) |

---

## Phase 1: Unified AreaEntity

### 1.1 AreaType Enum

```crystal
# data/src/models/area_type.cr
enum AreaType
  Town        # gmina
  County      # powiat
  Voivodeship # województwo
  MesoRegion  # region
  MacroRegion # obszar
end
```

### 1.2 AreaEntity Struct

```crystal
# data/src/models/area_entity.cr
struct AreaEntity
  getter slug : String
  getter name : String
  getter area_type : AreaType
  getter code : String?
  getter voivodeship_slug : String?  # for towns, counties
  getter bbox : BBox?

  # Center point (calculated from bbox)
  def center : {Float64, Float64}?
    return nil if bbox.nil?
    {
      (bbox.south + bbox.north) / 2.0,
      (bbox.west + bbox.east) / 2.0
    }
  end

  # URL helpers
  def url_prefix : String
    case area_type
    when .town?         then "/gminy/"
    when .county?       then "/powiaty/"
    when .voivodeship?  then "/wojewodztwa/"
    when .meso_region?  then "/regiony/"
    when .macro_region? then "/obszary/"
    else raise "Unknown area type"
    end
  end

  def gallery_type_prefix : String
    case area_type
    when .town?         then "gminy"
    when .county?       then "powiaty"
    when .voivodeship?  then "wojewodztwa"
    when .meso_region?  then "regiony"
    when .macro_region? then "obszary"
    else raise "Unknown area type"
    end
  end

  # Show page: /gminy/pobiedziska.html
  def show_url : String
    "#{url_prefix}#{slug}.html"
  end

  # Post list page: /wpisy_dla/gminy/pobiedziska.html (like TownDynamicView)
  def post_list_url : String
    "/wpisy_dla/#{gallery_type_prefix}/#{slug}.html"
  end

  # Gallery page: /galeria/gminy/pobiedziska.html
  def gallery_url : String
    "/galeria/#{gallery_type_prefix}/#{slug}.html"
  end
end
```

### 1.3 Three View Types per Area

| View Type | URL Pattern | Example | Based on |
|-----------|-------------|---------|----------|
| **Show** | `/<type>/<slug>.html` | `/gminy/pobiedziska.html` | New (to implement) |
| **Post List** | `/wpisy_dla/<type>/<slug>.html` | `/wpisy_dla/gminy/pobiedziska.html` | TownDynamicView |
| **Gallery** | `/galeria/<type>/<slug>.html` | `/galeria/gminy/pobiedziska.html` | GalleryView::CameraView |

### 1.4 Remove Old Entities

Delete after migration:
- [ ] `data/src/models/land_entity.cr`
- [ ] `data/src/models/town_entity.cr` (keep VoivodeshipEntity temporarily or merge)
- [ ] Update all imports/references

### 1.5 DataManager Updates

```crystal
# data/src/data_manager.cr
class DataManager
  # Single collection for all areas
  getter areas : Array(AreaEntity)

  # Filtered accessors (memoized)
  def towns : Array(AreaEntity)
    @towns ||= @areas.select(&.area_type.town?)
  end

  def counties : Array(AreaEntity)
    @counties ||= @areas.select(&.area_type.county?)
  end

  def voivodeships : Array(AreaEntity)
    @voivodeships ||= @areas.select(&.area_type.voivodeship?)
  end

  def meso_regions : Array(AreaEntity)
    @meso_regions ||= @areas.select(&.area_type.meso_region?)
  end

  def macro_regions : Array(AreaEntity)
    @macro_regions ||= @areas.select(&.area_type.macro_region?)
  end

  # Lookup by slug (requires area_type to avoid collisions)
  def area_by_slug(area_type : AreaType, slug : String) : AreaEntity?
    areas_of_type(area_type).find { |a| a.slug == slug }
  end

  # Memoized filtered accessors
  def areas_of_type(type : AreaType) : Array(AreaEntity)
    case type
    when .town?         then towns
    when .county?       then counties
    when .voivodeship?  then voivodeships
    when .meso_region?  then meso_regions
    when .macro_region? then macro_regions
    else [] of AreaEntity
    end
  end
end
```

---

## Phase 2: Area Config Generation

### 2.1 Data Source Architecture

```
data/external/*.yaml (source of truth, ~90MB with full polygons)
       ↓ generate_areas_for_posts.cr (extended)
data/config/areas/*.yml (generated cache, ~2MB, no polygons, with bbox)
       ↓
DataManager loads AreaEntity (fast, unified)
```

**Key principle:**
- **Config files**: ALL areas from `data/external/` (complete data)
- **Rendered pages**: Only areas with posts (filtered at render time)

### 2.2 Extend generate_areas_for_posts.cr

Add area config generation after processing posts:

```crystal
# commands/generate_areas_for_posts.cr

def run
  ENVS.each { |env| process_env(env) }

  # NEW: Generate area config files
  generate_area_configs

  @matcher.finalize
end

private def generate_area_configs
  output_dir = "data/config/areas"
  Dir.mkdir_p(output_dir)

  generate_config("towns", @matcher.towns, output_dir)
  generate_config("counties", @matcher.counties, output_dir)
  generate_config("voivodeships", @matcher.voivodeships, output_dir)
  generate_config("meso_regions", @matcher.meso_regions, output_dir)
  generate_config("macro_regions", @matcher.macro_regions, output_dir)
end

private def generate_config(name : String, areas : Array(Area), output_dir : String)
  data = areas.map do |area|
    {
      "slug"        => area.slug,
      "name"        => area.name,
      "code"        => area.code || area.terc,
      "voivodeship" => area.voivodeship,
      "bbox"        => compute_bbox(area.coords),
    }
  end

  File.write(File.join(output_dir, "#{name}.yml"), data.to_yaml)
  puts "Generated #{name}.yml with #{data.size} entries"
end

private def compute_bbox(coords : Array(Array(Float64))) : Hash(String, Float64)
  # coords are [lon, lat] for GEOS
  lons = coords.map { |c| c[0] }
  lats = coords.map { |c| c[1] }
  {
    "south" => lats.min,
    "north" => lats.max,
    "west"  => lons.min,
    "east"  => lons.max,
  }
end
```

### 2.3 Generated Config Structure

```
data/config/areas/
├── towns.yml         # ALL ~2500 towns
├── counties.yml      # ALL ~380 counties
├── voivodeships.yml  # ALL 16 voivodeships
├── meso_regions.yml  # ALL ~300 meso regions (renamed from lands.yml)
└── macro_regions.yml # ALL ~30 macro regions
```

**Each entry format:**
```yaml
- slug: pobiedziska
  name: Pobiedziska
  code: "3021123"
  voivodeship: wielkopolskie
  bbox:
    south: 52.38
    north: 52.52
    west: 17.12
    east: 17.35
```

### 2.4 Migration: Rename lands.yml

- Delete old `data/config/lands.yml`
- New file: `data/config/areas/meso_regions.yml`
- Update DataManager to load from new location

### 2.5 AreaAssociation (Route Data per Post)

```crystal
# data/src/models/area_association.cr
struct AreaAssociation
  getter slug : String
  getter name : String
  getter area_type : AreaType
  getter distance_meters : Float64
  getter distance_percent : Float64

  def above_threshold?(min_percent : Float64 = 1.0) : Bool
    distance_percent >= min_percent
  end
end
```

### 2.6 AreaDataLoader Service

```crystal
# data/src/services/area_data_loader.cr
class AreaDataLoader
  THRESHOLD_DEFAULT = 1.0  # percent

  def initialize(@cache_path : String, @threshold : Float64 = THRESHOLD_DEFAULT)
  end

  # Load and parse areas_for_post/<slug>.yml
  # Sum distances across all routes in post
  def load_for_post(post_slug : String) : Hash(AreaType, Array(AreaAssociation))

  # Apply threshold filter
  def filter(associations, threshold = @threshold)
end
```

---

## Phase 3: Post Entity Access

### 3.1 Hide Old Interface

```crystal
# In Post class
# OLD - hide these, make private or remove
# post.towns   # Array(String)
# post.lands   # Array(String)

# NEW - memoized entity access
private getter _area_entities : Hash(AreaType, Array(AreaEntity))?

def area_entities(type : AreaType) : Array(AreaEntity)
  @_area_entities ||= load_area_entities
  @_area_entities[type]? || [] of AreaEntity
end

# Convenience methods
def town_entities : Array(AreaEntity)
  area_entities(AreaType::Town)
end

def county_entities : Array(AreaEntity)
  area_entities(AreaType::County)
end
# etc.
```

### 3.2 Calculated Areas Access

```crystal
# Detailed route data (with distances)
private getter _detailed_areas : Hash(AreaType, Array(AreaAssociation))?

def detailed_areas(type : AreaType) : Array(AreaAssociation)
  @_detailed_areas ||= load_detailed_areas
  @_detailed_areas[type]? || [] of AreaAssociation
end
```

### 3.3 Post Initialization

Post receives context/data_manager reference for memoized lookups:
```crystal
def initialize(..., @data_manager : DataManager)
  # Area entities loaded lazily via memoization
end
```

---

## Phase 4: Photo Selection for Areas

### 4.1 AreaPhotoSelector Service

```crystal
# data/src/services/area_photo_selector.cr
class AreaPhotoSelector
  def initialize(@all_photos : Array(PhotoEntity))
  end

  # Find best photo within area bbox
  # Falls back to closest photo if none in bbox
  def best_photo_for(area : AreaEntity) : PhotoEntity?
    photos_in_bbox = photos_in_area(area.bbox)

    if photos_in_bbox.empty?
      closest_photo_to(area.bbox.center)
    else
      photos_in_bbox.max_by(&.points)  # PhotoTags score
    end
  end

  # All photos within bbox
  def photos_in_area(bbox : BBox?) : Array(PhotoEntity)
    return [] of PhotoEntity if bbox.nil?
    @all_photos.select { |p| bbox.contains?(p.exif.lat, p.exif.lon) }
  end

  # Fallback: closest photo to bbox center
  def closest_photo_to(center : {Float64, Float64}) : PhotoEntity?
    @all_photos.min_by? { |p| distance(p.exif.lat, p.exif.lon, center) }
  end
end
```

### 4.2 Caching

- [ ] `AreaPhotoCache` service
- [ ] Cache: `env/<env>/cache/area_photos.yml`
- [ ] Store best photo slug per area

---

## Phase 5: Area Views

### 5.1 View Structure (per area type)

Three views per area type:

| View | URL | Example | Based on |
|------|-----|---------|----------|
| **ShowView** | `/<type>/<slug>.html` | `/gminy/pobiedziska.html` | New - details + map |
| **PostListView** | `/wpisy_dla/<type>/<slug>.html` | `/wpisy_dla/gminy/pobiedziska.html` | TownDynamicView |
| **GalleryView** | `/galeria/<type>/<slug>.html` | `/galeria/gminy/pobiedziska.html` | GalleryView::CameraView |

### 5.2 Unified Views

```crystal
# data/src/views/area/area_show_view.cr
# NEW - area detail page with stats, map, best photo
class AreaShowView < PageView
  def initialize(context, @area : AreaEntity)
    @url = @area.show_url
    # ...
  end
end

# data/src/views/area/area_post_list_view.cr
# Based on TownDynamicView - list of posts for area
# URL: /wpisy_dla/gminy/pobiedziska.html
class AreaPostListView < CollectionDynamicView
  def initialize(context, @area : AreaEntity)
    super(
      context: context,
      url: @area.post_list_url,
      filter_by: "area",
      filter_value: @area.slug
    )
  end
end

# data/src/views/area/area_gallery_view.cr
# Based on GalleryView::CameraView - photos filtered by bbox
class AreaGalleryView < PageView
  def initialize(context, @area : AreaEntity)
    @url = @area.gallery_url
    # Filter photos using @area.bbox
  end
end
```

### 5.3 View Registry Entries

```crystal
# view_registry/views/area_views.cr
# Register for each area type
[AreaType::Town, AreaType::County, ...].each do |type|
  # All three views for each area (ONLY areas with posts)
  r.register("Area: #{type} pages", [:yamls, :posts], priority: 11) do |ctx|
    ctx.areas_of_type(type).each do |area|
      posts = ctx.posts_for(area)
      next if posts.empty?  # Skip areas without posts

      # Show page: /gminy/pobiedziska.html
      ctx.write_output(AreaShowView.new(context: ctx, area: area))

      # Post list: /wpisy_dla/gminy/pobiedziska.html
      ctx.write_output(AreaPostListView.new(context: ctx, area: area))

      # Gallery: /galeria/gminy/pobiedziska.html
      ctx.write_output(AreaGalleryView.new(context: ctx, area: area))
    end
  end
end
```

**Important**: Config contains ALL areas, but pages rendered only for areas with posts.

---

## Phase 6: Cleanup

### 6.1 Current View Status

| View | Status | Purpose | Action |
|------|--------|---------|--------|
| `LandDynamicView` | **USED** | Post list page (cool design) | Keep, migrate to AreaEntity |
| `TownDynamicView` | **USED** | Post list page | Keep, migrate to AreaEntity |
| `VoivodeshipDynamicView` | **USED** | Post list page | Keep, migrate to AreaEntity |
| `LandsIndexView` | DEPRECATED | Old post list | Don't test, keep for now |
| `TownsIndexView` | Check | Old post list? | Verify status |
| `LandView` | NOT USED | Future show page | Don't test, keep for now |
| `TownView` | Check | Future show page? | Verify status |

### 6.2 Migration Plan

**Keep and migrate** (used views):
- `*DynamicView` classes → update to use AreaEntity instead of specific entity types

**Mark deprecated** (don't test, don't remove yet):
- `LandsIndexView` - old post list design
- `LandView` - not used, future show page (URL schema TBD)

**New views to create**:
- `AreaShowView` - new show page with stats, map, best photo
- `AreaGalleryView` - photo gallery for area
- `AreaIndexView` - list all areas of a type (if needed, or reuse DynamicView pattern)

### 6.3 Final Rename (end of refactoring)

Rename views for clarity:

| Current Name | New Name | Purpose |
|--------------|----------|---------|
| `*DynamicView` | `AreaPostListView` | List of posts for an area |
| `AreaShowView` | `AreaShowView` | Area detail page (stats, map, photo) |
| `AreaGalleryView` | `AreaGalleryView` | Area photo gallery |

Clear naming convention:
- `*PostListView` = page listing posts filtered by something
- `*ShowView` = detail page for a single entity
- `*GalleryView` = photo gallery page
- `*IndexView` = list of entities (deprecated pattern)

### 6.2 Update RenderContext

```crystal
# data/src/render_context.cr
class RenderContext
  # Single accessor for all areas
  def areas : Array(AreaEntity)
    data_manager.areas
  end

  def areas_of_type(type : AreaType) : Array(AreaEntity)
    data_manager.areas_of_type(type)
  end

  def area_by_slug(type : AreaType, slug : String) : AreaEntity?
    data_manager.area_by_slug(type, slug)
  end

  # Remove old accessors after migration
  # def towns, def lands, def voivodeships
end
```

---

## Phase 7: External Towns (Last)

Handle towns outside Poland (foreign countries, edge cases):

### 7.1 External Towns Config

```yaml
# data/config/external_towns.yml
- slug: praha
  name: Praha
  country: Czechia
  lat: 50.0755
  lon: 14.4378
- slug: berlin
  name: Berlin
  country: Germany
  lat: 52.5200
  lon: 13.4050
```

### 7.2 Load into AreaEntity

- Load `external_towns.yml` as AreaType::Town with special flag or separate type
- Include in town lookups for post associations
- Skip for bbox-based photo selection (no polygon data)

---

## Implementation Order

1. **Phase 1**: Create unified AreaEntity, AreaType enum
2. **Phase 2**: Extend `generate_areas_for_posts.cr` to generate area configs
3. **Phase 3**: Post memoized entity access, hide old interface
4. **Phase 4**: AreaPhotoSelector with bbox + fallback
5. **Phase 5**: Unified area views (index, show, gallery)
6. **Phase 6**: Cleanup old entities, views, accessors
7. **Phase 7**: External towns support (last, if needed)

---

## Files to Create

| File | Purpose |
|------|---------|
| `data/src/models/area_type.cr` | AreaType enum |
| `data/src/models/area_entity.cr` | Unified AreaEntity struct |
| `data/src/models/area_association.cr` | Route distance data |
| `data/src/services/area_data_loader.cr` | Load areas_for_post YAML |
| `data/src/services/area_photo_selector.cr` | Best photo for area |
| `data/src/views/area/area_index_view.cr` | Area list page |
| `data/src/views/area/area_show_view.cr` | Area detail page |
| `data/src/views/area/area_gallery_view.cr` | Area photo gallery |
| `data/src/view_registry/views/area_views.cr` | Registry entries |
| `data/config/external_towns.yml` | Foreign towns (Phase 7) |

## Files to Delete (after migration)

| File | Action |
|------|--------|
| `data/src/models/land_entity.cr` | Delete → replaced by AreaEntity |
| `data/src/models/town_entity.cr` | Delete → replaced by AreaEntity |
| `data/config/lands.yml` | Delete → replaced by `data/config/areas/meso_regions.yml` |
| `data/config/towns/**/*.yml` | Delete → replaced by `data/config/areas/towns.yml` + `voivodeships.yml` |

## Files to Mark Deprecated (keep, don't test)

| File | Reason |
|------|--------|
| `data/src/views/land_view.cr` | Not used, future show page |
| `data/src/views/model_view/lands_index_view.cr` | Old post list design |
| `data/src/views/model_view/towns_index_view.cr` | Old post list design (verify) |

## Files to Migrate (keep, update to AreaEntity)

| File | New Name (end of refactor) |
|------|----------------------------|
| `land_dynamic_view.cr` | `area_post_list_view.cr` |
| `town_dynamic_view.cr` | merged into `area_post_list_view.cr` |
| `voivodeship_dynamic_view.cr` | merged into `area_post_list_view.cr` |

---

## Open Questions (Resolved)

| Question | Answer |
|----------|--------|
| URL scheme for lands? | Polish: `/regiony/` |
| Multiple routes per post? | Sum distances |
| Photo fallback? | Yes, closest photo if none in bbox |
| Backward compatibility? | Not needed |

## Resolved Questions

| Question | Answer |
|----------|--------|
| Data source | `data/external/` is source of truth, generate config from it |
| Post header `towns:`/`lands:` | User will remove from posts with routes. Treat as addition to cached data |
| Existing `/lands/` URLs | Ignore, user will clean up. No redirects needed |
| Generate command timing | Run manually by user (takes several minutes). `data/external/` won't change |
| Foreign towns | Convert to `external_towns`, store in `data/config/external_towns.yml`. Phase 7 (last) |

---

*Scope: ~15 files to create, ~10 files to delete, unified cleaner architecture*
