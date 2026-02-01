require "yaml"

require "./geos/geos"
require "./area_type"
require "./area"
require "./match_result"
require "./loader"
require "./haversine"

class AreaMatcher::Matcher
  Log = ::Log.for(self)

  # Data storage
  @towns : Array(Area)
  @counties : Array(Area)
  @voivodeships : Array(Area)
  @meso_regions : Array(Area)
  @macro_regions : Array(Area)
  @mega_regions : Array(Area)
  @subprovinces : Array(Area)
  @provinces : Array(Area)

  # GEOS context (kept alive for geometries)
  @ctx : GEOS::Context

  def initialize(
    towns_path : String = "data/external/towns.yaml",
    counties_path : String = "data/external/counties.yaml",
    voivodeships_path : String = "data/external/voivodeships.yaml",
    meso_regions_path : String = "data/external/meso_regions.yaml",
    macro_regions_path : String = "data/external/macro_regions.yaml",
    mega_regions_path : String = "data/external/mega_regions.yaml",
    subprovinces_path : String = "data/external/subprovinces.yaml",
    provinces_path : String = "data/external/provinces.yaml"
  )
    @ctx = GEOS::Context.new

    # Load all data
    @towns = Loader.load_towns(towns_path)
    @counties = Loader.load_counties(counties_path)
    @voivodeships = Loader.load_voivodeships(voivodeships_path)
    @meso_regions = Loader.load_meso_regions(meso_regions_path)
    @macro_regions = Loader.load_macro_regions(macro_regions_path)
    @mega_regions = Loader.load_mega_regions(mega_regions_path)
    @subprovinces = Loader.load_subprovinces(subprovinces_path)
    @provinces = Loader.load_provinces(provinces_path)

    # Build geometries for all areas
    build_all_geometries
  end

  # Match single point - returns full objects for all matching areas
  # Input: lat, lon (standard geographic order)
  def match_point(lat : Float64, lon : Float64) : PointMatchResult
    result = PointMatchResult.new

    result.towns = find_containing_areas(@towns, lat, lon)
    result.counties = find_containing_areas(@counties, lat, lon)
    result.voivodeships = find_containing_areas(@voivodeships, lat, lon)
    result.meso_regions = find_containing_areas(@meso_regions, lat, lon)
    result.macro_regions = find_containing_areas(@macro_regions, lat, lon)
    result.mega_regions = find_containing_areas(@mega_regions, lat, lon)
    result.subprovinces = find_containing_areas(@subprovinces, lat, lon)
    result.provinces = find_containing_areas(@provinces, lat, lon)

    result
  end

  # Match array of points - check each point and merge results
  # Input: Array of [lat, lon] pairs
  def match_points(points : Array(Array(Float64))) : PointMatchResult
    result = PointMatchResult.new

    points.each do |point|
      next if point.size < 2
      lat = point[0]
      lon = point[1]
      point_result = match_point(lat, lon)
      result = result.merge(point_result)
    end

    result
  end

  # Match polygon against all areas - returns coverage percentages
  # Input: Array of [lat, lon] pairs forming a closed polygon
  def match_polygon(coords : Array(Array(Float64))) : Hash(AreaType, Array(PolygonMatchResult))
    result = Hash(AreaType, Array(PolygonMatchResult)).new

    # Convert input coords from [lat, lon] to [lon, lat] for GEOS
    geos_coords = coords.map { |c| [c[1], c[0]] }

    # Create input polygon geometry
    input_geom = @ctx.polygon_from_coords(geos_coords)
    return result if input_geom.nil?

    unless @ctx.valid?(input_geom.not_nil!)
      fixed = @ctx.make_valid(input_geom.not_nil!)
      @ctx.destroy(input_geom.not_nil!)
      input_geom = fixed
    end

    return result if input_geom.nil? || @ctx.empty?(input_geom.not_nil!)

    input_area = @ctx.area(input_geom.not_nil!)
    if input_area.nil? || input_area <= 0
      @ctx.destroy(input_geom.not_nil!)
      return result
    end

    result[AreaType::Town] = find_overlapping_areas(@towns, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::County] = find_overlapping_areas(@counties, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::Voivodeship] = find_overlapping_areas(@voivodeships, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::MesoRegion] = find_overlapping_areas(@meso_regions, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::MacroRegion] = find_overlapping_areas(@macro_regions, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::MegaRegion] = find_overlapping_areas(@mega_regions, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::Subprovince] = find_overlapping_areas(@subprovinces, input_geom.not_nil!, input_area.not_nil!)
    result[AreaType::Province] = find_overlapping_areas(@provinces, input_geom.not_nil!, input_area.not_nil!)

    @ctx.destroy(input_geom.not_nil!)
    result
  end

  # Match route against all areas - returns distance traveled through each area
  # Input: Array of [lat, lon] pairs forming a route (polyline)
  # Returns: RouteMatchResult with distances in meters and percentages
  def match_route(coords : Array(Array(Float64))) : RouteMatchResult
    # Convert input coords from [lat, lon] to [lon, lat] for GEOS
    geos_coords = coords.map { |c| [c[1], c[0]] }

    # Calculate total route distance using Haversine
    total_distance = Haversine.linestring_distance(geos_coords)

    # Create route linestring geometry
    route_geom = @ctx.linestring_from_coords(geos_coords)

    # If we can't create geometry, return empty result
    if route_geom.nil?
      return RouteMatchResult.new(
        total_distance_meters: total_distance,
        towns: [] of RouteDistanceResult,
        counties: [] of RouteDistanceResult,
        voivodeships: [] of RouteDistanceResult,
        meso_regions: [] of RouteDistanceResult,
        macro_regions: [] of RouteDistanceResult,
        mega_regions: [] of RouteDistanceResult,
        subprovinces: [] of RouteDistanceResult,
        provinces: [] of RouteDistanceResult
      )
    end

    result = RouteMatchResult.new(
      total_distance_meters: total_distance,
      towns: find_route_distances(@towns, route_geom.not_nil!, total_distance),
      counties: find_route_distances(@counties, route_geom.not_nil!, total_distance),
      voivodeships: find_route_distances(@voivodeships, route_geom.not_nil!, total_distance),
      meso_regions: find_route_distances(@meso_regions, route_geom.not_nil!, total_distance),
      macro_regions: find_route_distances(@macro_regions, route_geom.not_nil!, total_distance),
      mega_regions: find_route_distances(@mega_regions, route_geom.not_nil!, total_distance),
      subprovinces: find_route_distances(@subprovinces, route_geom.not_nil!, total_distance),
      provinces: find_route_distances(@provinces, route_geom.not_nil!, total_distance)
    )

    @ctx.destroy(route_geom.not_nil!)
    result
  end

  # Get counts of loaded areas
  def stats : Hash(String, Int32)
    {
      "towns"         => @towns.size,
      "counties"      => @counties.size,
      "voivodeships"  => @voivodeships.size,
      "meso_regions"  => @meso_regions.size,
      "macro_regions" => @macro_regions.size,
      "mega_regions"  => @mega_regions.size,
      "subprovinces"  => @subprovinces.size,
      "provinces"     => @provinces.size,
    }
  end

  # Cleanup GEOS resources
  def finalize
    cleanup_geometries(@towns)
    cleanup_geometries(@counties)
    cleanup_geometries(@voivodeships)
    cleanup_geometries(@meso_regions)
    cleanup_geometries(@macro_regions)
    cleanup_geometries(@mega_regions)
    cleanup_geometries(@subprovinces)
    cleanup_geometries(@provinces)
    @ctx.finalize
  end

  # Access to loaded data (read-only)
  getter towns, counties, voivodeships, meso_regions, macro_regions, mega_regions, subprovinces, provinces

  private def build_all_geometries
    build_geometries_for(@towns, "towns")
    build_geometries_for(@counties, "counties")
    build_geometries_for(@voivodeships, "voivodeships")
    build_geometries_for(@meso_regions, "meso_regions")
    build_geometries_for(@macro_regions, "macro_regions")
    build_geometries_for(@mega_regions, "mega_regions")
    build_geometries_for(@subprovinces, "subprovinces")
    build_geometries_for(@provinces, "provinces")
  end

  private def build_geometries_for(areas : Array(Area), name : String)
    success_count = 0
    areas.each do |area|
      if area.build_geometry(@ctx)
        success_count += 1
      else
        Log.warn { "Failed to build geometry for #{name}/#{area.slug}" }
      end
    end
    Log.info { "Built #{success_count}/#{areas.size} geometries for #{name}" }
  end

  private def cleanup_geometries(areas : Array(Area))
    areas.each { |area| area.destroy_geometry(@ctx) }
  end

  # Find all areas containing the given point
  private def find_containing_areas(areas : Array(Area), lat : Float64, lon : Float64) : Array(MatchedArea)
    result = Array(MatchedArea).new

    areas.each do |area|
      # GEOS uses [lon, lat] order
      if area.contains_point?(@ctx, lon, lat)
        result << area.to_matched_area
      end
    end

    result
  end

  # Find all areas overlapping with input polygon and calculate coverage
  private def find_overlapping_areas(
    areas : Array(Area),
    input_geom : GEOS::Geometry,
    input_area : Float64
  ) : Array(PolygonMatchResult)
    result = Array(PolygonMatchResult).new

    areas.each do |area|
      next if area.geom.nil?

      # Check if they intersect
      next unless @ctx.intersects?(area.geom.not_nil!, input_geom)

      # Calculate intersection area
      inter_area = @ctx.intersection_area(area.geom.not_nil!, input_geom)
      next if inter_area <= 0

      # Calculate coverage as percentage of input polygon covered by this area
      coverage = (inter_area / input_area) * 100.0

      result << PolygonMatchResult.new(
        area: area.to_matched_area,
        coverage_percent: coverage.round(4)
      )
    end

    # Sort by coverage descending
    result.sort_by! { |r| -r.coverage_percent }
    result
  end

  # Find route distance through each area
  private def find_route_distances(
    areas : Array(Area),
    route_geom : GEOS::Geometry,
    total_distance : Float64
  ) : Array(RouteDistanceResult)
    result = Array(RouteDistanceResult).new

    areas.each do |area|
      next if area.geom.nil?

      # Check if route intersects this area
      next unless @ctx.intersects?(area.geom.not_nil!, route_geom)

      # Get intersection geometry
      intersection = @ctx.intersection(area.geom.not_nil!, route_geom)
      next if intersection.nil?

      # Extract all linestring coordinates from intersection
      # (could be linestring, multilinestring, or geometry collection)
      linestrings = @ctx.extract_all_linestring_coords(intersection.not_nil!)
      @ctx.destroy(intersection.not_nil!)

      next if linestrings.empty?

      # Calculate distance using Haversine
      distance = Haversine.multi_linestring_distance(linestrings)
      next if distance <= 0

      # Calculate percentage of total route
      percent = if total_distance > 0
                  (distance / total_distance) * 100.0
                else
                  0.0
                end

      result << RouteDistanceResult.new(
        area: area.to_matched_area,
        distance_meters: distance.round(2),
        distance_percent: percent.round(4)
      )
    end

    # Sort by distance descending
    result.sort_by! { |r| -r.distance_meters }
    result
  end
end
