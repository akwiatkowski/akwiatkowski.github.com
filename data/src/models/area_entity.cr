require "./area_type"
require "../services/area_matcher/bbox"

# Unified entity for all geographic area types (towns, counties, voivodeships, regions)
# Loaded from data/config/areas/*.yml (generated from data/external/)
struct AreaEntity
  getter slug : String
  getter name : String
  getter area_type : AreaType
  getter code : String?           # TERC code for administrative, region code for geographic
  getter voivodeship_slug : String?  # Parent voivodeship (for towns, counties)
  getter bbox : AreaMatcher::BBox?
  getter country : String?        # nil for Polish areas, country slug for external (e.g., "czechy")

  def initialize(
    @slug : String,
    @name : String,
    @area_type : AreaType,
    @code : String? = nil,
    @voivodeship_slug : String? = nil,
    @bbox : AreaMatcher::BBox? = nil,
    @country : String? = nil
  )
  end

  # Returns true if this is an external (non-Polish) area
  def external? : Bool
    !@country.nil?
  end

  # Initialize from YAML data
  def self.from_yaml(yaml : YAML::Any, area_type : AreaType) : AreaEntity
    slug = yaml["slug"].as_s
    name = yaml["name"]?.try(&.as_s?) || slug
    code = yaml["code"]?.try(&.as_s?)
    voivodeship_slug = yaml["voivodeship"]?.try(&.as_s?)
    country = yaml["country"]?.try(&.as_s?)

    bbox = if yaml["bbox"]?
             bbox_data = yaml["bbox"]
             AreaMatcher::BBox.new(
               south: bbox_data["south"].as_f,
               north: bbox_data["north"].as_f,
               west: bbox_data["west"].as_f,
               east: bbox_data["east"].as_f
             )
           else
             nil
           end

    AreaEntity.new(
      slug: slug,
      name: name,
      area_type: area_type,
      code: code,
      voivodeship_slug: voivodeship_slug,
      bbox: bbox,
      country: country
    )
  end

  # Center point of the area (calculated from bbox)
  def center : {Float64, Float64}?
    bbox.try(&.center)
  end

  # Center latitude (average of min/max)
  def lat : Float64?
    center.try(&.[0])
  end

  # Center longitude (average of min/max)
  def lon : Float64?
    center.try(&.[1])
  end

  # Check if a point (lat, lon) is within this area's bounding box
  def bbox_contains?(lat : Float64, lon : Float64) : Bool
    return false if bbox.nil?
    b = bbox.not_nil!
    lat >= b.south && lat <= b.north && lon >= b.west && lon <= b.east
  end

  # ============================================
  # URL Generation (delegated to Router)
  # ============================================
  #
  # URL methods moved to Router class for centralized URL management.
  # Use: context.router.area_show_url(area)
  #      context.router.area_post_list_url(area)
  #      context.router.area_gallery_url(area)
  #
  # For convenience, these methods delegate to a shared Router instance.
  # This keeps backward compatibility while centralizing URL logic.
  #
  @@router = Router.new

  def show_url : String
    @@router.area_show_url(self)
  end

  def view_url : String
    @@router.area_show_url(self)
  end

  def post_list_url : String
    @@router.area_post_list_url(self)
  end

  def post_areas_link_url : String
    @@router.area_post_list_url(self)
  end

  def gallery_url : String
    @@router.area_gallery_url(self)
  end

  # Check if this area belongs to a post (by slug matching)
  # Used for filtering posts by area
  def belongs_to_post?(post, area_slugs : Array(String)) : Bool
    area_slugs.includes?(slug)
  end

  # Comparison for sorting (by name)
  def <=>(other : AreaEntity) : Int32
    name <=> other.name
  end

  def to_s(io : IO)
    io << "AreaEntity(#{area_type}: #{slug})"
  end
end
