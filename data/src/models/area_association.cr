require "./area_type"

# Represents a post's association with an area, including route distance data
# Loaded from cache/areas_for_post/<post_slug>.yml
struct AreaAssociation
  getter slug : String
  getter name : String
  getter area_type : AreaType
  getter code : String?
  getter distance_meters : Float64
  getter distance_percent : Float64

  def initialize(
    @slug : String,
    @name : String,
    @area_type : AreaType,
    @distance_meters : Float64,
    @distance_percent : Float64,
    @code : String? = nil
  )
  end

  # Initialize from YAML data (from areas_for_post cache)
  def self.from_yaml(yaml : YAML::Any, area_type : AreaType) : AreaAssociation
    AreaAssociation.new(
      slug: yaml["slug"].as_s,
      name: yaml["name"]?.try(&.as_s?) || yaml["slug"].as_s,
      area_type: area_type,
      distance_meters: yaml["distance_meters"].as_f,
      distance_percent: yaml["distance_percent"].as_f,
      code: yaml["code"]?.try(&.as_s?)
    )
  end

  # Check if distance is above threshold (default 1%)
  def above_threshold?(min_percent : Float64 = 1.0) : Bool
    distance_percent >= min_percent
  end

  # Distance in kilometers
  def distance_km : Float64
    distance_meters / 1000.0
  end

  # Comparison for sorting (by distance descending)
  def <=>(other : AreaAssociation) : Int32
    (other.distance_meters <=> distance_meters) || 0
  end

  def to_s(io : IO)
    io << "AreaAssociation(#{area_type}: #{slug}, #{distance_percent.round(2)}%)"
  end
end
