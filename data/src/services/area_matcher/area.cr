require "./area_type"
require "./geos/geos"

class AreaMatcher::Area
  property slug : String
  property name : String?
  property area_type : AreaType

  # Administrative areas (towns, counties, voivodeships)
  property voivodeship : String?
  property terc : String?

  # Geographic regions (meso, macro, mega, province)
  # Hierarchical: meso_region 521.11 -> macro_region 521 -> mega_region 52 -> province 5
  property code : String?

  # Geometry data
  # Coords stored as [lon, lat] for GEOS compatibility
  property coords : Array(Array(Float64))
  property geom : GEOS::Geometry?
  property prepared : GEOS::PreparedGeometry?

  def initialize(
    @slug : String,
    @name : String?,
    @area_type : AreaType,
    @coords : Array(Array(Float64)),
    @voivodeship : String? = nil,
    @terc : String? = nil,
    @code : String? = nil
  )
    @geom = nil
    @prepared = nil
  end

  # Build GEOS geometry from coords
  def build_geometry(ctx : GEOS::Context) : Bool
    return false if @coords.size < 4

    @geom = ctx.polygon_from_coords(@coords)
    return false if @geom.nil?

    # Validate and fix if needed
    unless ctx.valid?(@geom.not_nil!)
      fixed = ctx.make_valid(@geom.not_nil!)
      ctx.destroy(@geom.not_nil!)
      @geom = fixed
    end

    return false if @geom.nil?

    if ctx.empty?(@geom.not_nil!)
      ctx.destroy(@geom.not_nil!)
      @geom = nil
      return false
    end

    # Create prepared geometry for faster contains checks
    @prepared = ctx.prepare(@geom.not_nil!)
    true
  end

  # Check if point [lon, lat] is inside this area
  def contains_point?(ctx : GEOS::Context, lon : Float64, lat : Float64) : Bool
    return false if @prepared.nil? || @geom.nil?

    point_wkt = "POINT(#{lon} #{lat})"
    point_geom = ctx.from_wkt(point_wkt)
    return false if point_geom.nil?

    result = ctx.prepared_intersects?(@prepared.not_nil!, point_geom.not_nil!)
    ctx.destroy(point_geom.not_nil!)
    result
  end

  # Cleanup GEOS resources
  def destroy_geometry(ctx : GEOS::Context)
    ctx.destroy(@prepared.not_nil!) if @prepared
    ctx.destroy(@geom.not_nil!) if @geom
    @prepared = nil
    @geom = nil
  end

  # Convert to matched area result (without geometry data)
  def to_matched_area : MatchedArea
    MatchedArea.new(
      slug: @slug,
      name: @name,
      area_type: @area_type,
      voivodeship: @voivodeship,
      terc: @terc,
      code: @code
    )
  end
end
