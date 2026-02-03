require "json"
require "./area_type"

struct AreaMatcher::MatchedArea
  include JSON::Serializable

  property slug : String
  property name : String?
  property area_type : AreaType
  property voivodeship : String?
  property terc : String?
  property code : String?

  def initialize(
    @slug : String,
    @name : String?,
    @area_type : AreaType,
    @voivodeship : String? = nil,
    @terc : String? = nil,
    @code : String? = nil,
  )
  end
end

struct AreaMatcher::PointMatchResult
  include JSON::Serializable

  property towns : Array(MatchedArea)
  property counties : Array(MatchedArea)
  property voivodeships : Array(MatchedArea)
  property meso_regions : Array(MatchedArea)
  property macro_regions : Array(MatchedArea)
  property mega_regions : Array(MatchedArea)
  property subprovinces : Array(MatchedArea)
  property provinces : Array(MatchedArea)

  def initialize
    @towns = Array(MatchedArea).new
    @counties = Array(MatchedArea).new
    @voivodeships = Array(MatchedArea).new
    @meso_regions = Array(MatchedArea).new
    @macro_regions = Array(MatchedArea).new
    @mega_regions = Array(MatchedArea).new
    @subprovinces = Array(MatchedArea).new
    @provinces = Array(MatchedArea).new
  end

  def initialize(
    @towns : Array(MatchedArea),
    @counties : Array(MatchedArea),
    @voivodeships : Array(MatchedArea),
    @meso_regions : Array(MatchedArea),
    @macro_regions : Array(MatchedArea),
    @mega_regions : Array(MatchedArea),
    @subprovinces : Array(MatchedArea),
    @provinces : Array(MatchedArea),
  )
  end

  # Merge another result into this one (for combining multiple points)
  def merge(other : PointMatchResult) : PointMatchResult
    PointMatchResult.new(
      towns: merge_areas(@towns, other.towns),
      counties: merge_areas(@counties, other.counties),
      voivodeships: merge_areas(@voivodeships, other.voivodeships),
      meso_regions: merge_areas(@meso_regions, other.meso_regions),
      macro_regions: merge_areas(@macro_regions, other.macro_regions),
      mega_regions: merge_areas(@mega_regions, other.mega_regions),
      subprovinces: merge_areas(@subprovinces, other.subprovinces),
      provinces: merge_areas(@provinces, other.provinces)
    )
  end

  # Check if result is empty (no matches)
  def empty? : Bool
    @towns.empty? &&
      @counties.empty? &&
      @voivodeships.empty? &&
      @meso_regions.empty? &&
      @macro_regions.empty? &&
      @mega_regions.empty? &&
      @subprovinces.empty? &&
      @provinces.empty?
  end

  # Total count of all matched areas
  def total_count : Int32
    @towns.size +
      @counties.size +
      @voivodeships.size +
      @meso_regions.size +
      @macro_regions.size +
      @mega_regions.size +
      @subprovinces.size +
      @provinces.size
  end

  private def merge_areas(a : Array(MatchedArea), b : Array(MatchedArea)) : Array(MatchedArea)
    result = a.dup
    b.each do |area|
      result << area unless result.any? { |existing| existing.slug == area.slug }
    end
    result
  end
end

struct AreaMatcher::PolygonMatchResult
  include JSON::Serializable

  property area : MatchedArea
  property coverage_percent : Float64

  def initialize(@area : MatchedArea, @coverage_percent : Float64)
  end
end

struct AreaMatcher::RouteDistanceResult
  include JSON::Serializable

  property area : MatchedArea
  property distance_meters : Float64
  property distance_percent : Float64 # % of total route distance

  def initialize(@area : MatchedArea, @distance_meters : Float64, @distance_percent : Float64)
  end
end

struct AreaMatcher::RouteMatchResult
  include JSON::Serializable

  property total_distance_meters : Float64
  property towns : Array(RouteDistanceResult)
  property counties : Array(RouteDistanceResult)
  property voivodeships : Array(RouteDistanceResult)
  property meso_regions : Array(RouteDistanceResult)
  property macro_regions : Array(RouteDistanceResult)
  property mega_regions : Array(RouteDistanceResult)
  property subprovinces : Array(RouteDistanceResult)
  property provinces : Array(RouteDistanceResult)

  def initialize(
    @total_distance_meters : Float64,
    @towns : Array(RouteDistanceResult),
    @counties : Array(RouteDistanceResult),
    @voivodeships : Array(RouteDistanceResult),
    @meso_regions : Array(RouteDistanceResult),
    @macro_regions : Array(RouteDistanceResult),
    @mega_regions : Array(RouteDistanceResult),
    @subprovinces : Array(RouteDistanceResult),
    @provinces : Array(RouteDistanceResult),
  )
  end
end
