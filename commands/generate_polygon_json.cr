require "json"
require "yaml"
require "file_utils"
require "log"
require "../data/src/services/area_matcher/all"

# Douglas-Peucker line simplification algorithm
module DouglasPeucker
  # Simplify a polygon (array of [lon, lat] coordinates)
  # tolerance: distance threshold in degrees (higher = more simplification)
  def self.simplify(coords : Array(Array(Float64)), tolerance : Float64) : Array(Array(Float64))
    return coords if coords.size <= 2

    # Find the point with maximum distance from the line between first and last
    max_dist = 0.0
    max_idx = 0

    first = coords.first
    last = coords.last

    (1...coords.size - 1).each do |i|
      dist = perpendicular_distance(coords[i], first, last)
      if dist > max_dist
        max_dist = dist
        max_idx = i
      end
    end

    # If max distance exceeds tolerance, recursively simplify
    if max_dist > tolerance
      # Recursively simplify both segments
      left = simplify(coords[0..max_idx], tolerance)
      right = simplify(coords[max_idx..], tolerance)

      # Combine results (remove duplicate point at junction)
      left[0...-1] + right
    else
      # Keep only endpoints
      [first, last]
    end
  end

  # Calculate perpendicular distance from point to line segment
  private def self.perpendicular_distance(
    point : Array(Float64),
    line_start : Array(Float64),
    line_end : Array(Float64)
  ) : Float64
    x, y = point
    x1, y1 = line_start
    x2, y2 = line_end

    # Handle degenerate case
    dx = x2 - x1
    dy = y2 - y1

    if dx == 0 && dy == 0
      # Line start == line end
      return Math.sqrt((x - x1) ** 2 + (y - y1) ** 2)
    end

    # Calculate perpendicular distance
    numerator = ((dy * x) - (dx * y) + (x2 * y1) - (y2 * x1)).abs
    denominator = Math.sqrt(dx ** 2 + dy ** 2)

    numerator / denominator
  end
end

class Commands::GeneratePolygonJson
  # All env/target combinations to write polygons to
  ENV_TARGETS = [
    {"dev", "local"},
    {"dev", "release"},
    {"full", "local"},
    {"full", "release"},
  ]

  # Envs to scan for visited areas (cache lookup)
  CACHE_ENVS = ["dev", "full"]

  # Area types to process (matching AreaMatcher types)
  AREA_TYPES = {
    "towns"        => :towns,
    "counties"     => :counties,
    "voivodeships" => :voivodeships,
    "meso_regions" => :meso_regions,
    "macro_regions" => :macro_regions,
  }

  def initialize(
    @tolerance : Float64 = 0.001,
    @force : Bool = false
  )
    @matcher = AreaMatcher::Matcher.new
    puts "AreaMatcher loaded: #{@matcher.stats}"
    puts "Simplification tolerance: #{@tolerance}"
    puts "Force regenerate: #{@force}"
  end

  def run
    # Collect all visited area slugs from both environments
    visited_areas = collect_visited_areas

    puts "\nVisited areas summary:"
    AREA_TYPES.keys.each do |type|
      count = visited_areas[type]?.try(&.size) || 0
      puts "  #{type}: #{count} unique areas"
    end

    # Generate polygon files for each env/target combination
    ENV_TARGETS.each do |(env, target)|
      puts "\n=== Generating polygons for env: #{env}, target: #{target} ==="
      generate_polygons_for_env(env, target, visited_areas)
    end

    @matcher.finalize
    puts "\nDone!"
  end

  # Collect visited area slugs from all environments
  private def collect_visited_areas : Hash(String, Set(String))
    visited = Hash(String, Set(String)).new { |h, k| h[k] = Set(String).new }

    CACHE_ENVS.each do |env|
      cache_dir = File.join(["env", env, "cache", "areas_for_post"])
      next unless Dir.exists?(cache_dir)

      Dir.glob(File.join([cache_dir, "*.yml"])).each do |file|
        parse_area_file(file, visited)
      end
    end

    visited
  end

  # Parse a single areas_for_post YAML file and add slugs to visited
  private def parse_area_file(path : String, visited : Hash(String, Set(String)))
    data = YAML.parse(File.read(path))
    return unless data.as_a?

    data.as_a.each do |route|
      # Extract slugs from distance-based fields (these have distance data)
      AREA_TYPES.keys.each do |type|
        if areas = route[type]?
          areas.as_a.each do |area|
            if slug = area["slug"]?.try(&.as_s?)
              visited[type].add(slug)
            end
          end
        end

        # Also check touched_* fields
        touched_key = "touched_#{type}"
        if touched = route[touched_key]?
          touched.as_a.each do |area|
            if slug = area["slug"]?.try(&.as_s?)
              visited[type].add(slug)
            end
          end
        end
      end
    end
  rescue ex
    puts "  Warning: Failed to parse #{path}: #{ex.message}"
  end

  # Generate polygon JSON files for a specific environment
  private def generate_polygons_for_env(
    env : String,
    target : String,
    visited_areas : Hash(String, Set(String))
  )
    base_output_dir = File.join(["env", env, "public", target, "polygons"])

    AREA_TYPES.each do |type_name, area_method|
      areas = get_areas_by_type(area_method)
      visited_slugs = visited_areas[type_name]? || Set(String).new

      output_dir = File.join([base_output_dir, type_name])
      Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

      generated = 0
      skipped = 0

      areas.each do |area|
        # Only generate for visited areas
        next unless visited_slugs.includes?(area.slug)

        output_path = File.join([output_dir, "#{area.slug}.json"])

        # Skip if exists and not forcing
        if !@force && File.exists?(output_path)
          skipped += 1
          next
        end

        # Generate GeoJSON
        geojson = generate_geojson(area, type_name)
        File.write(output_path, geojson)
        generated += 1
      end

      puts "  #{type_name}: generated #{generated}, skipped #{skipped}"
    end
  end

  # Get areas array by type
  private def get_areas_by_type(area_type : Symbol) : Array(AreaMatcher::Area)
    case area_type
    when :towns        then @matcher.towns
    when :counties     then @matcher.counties
    when :voivodeships then @matcher.voivodeships
    when :meso_regions then @matcher.meso_regions
    when :macro_regions then @matcher.macro_regions
    else                    [] of AreaMatcher::Area
    end
  end

  # Generate GeoJSON for a single area
  private def generate_geojson(area : AreaMatcher::Area, type_name : String) : String
    # Simplify coordinates
    coords = area.coords
    simplified = DouglasPeucker.simplify(coords, @tolerance)

    # Ensure polygon is closed (first point == last point)
    if simplified.size >= 3 && simplified.first != simplified.last
      simplified << simplified.first.dup
    end

    # Calculate simplification stats
    reduction = ((1.0 - simplified.size.to_f / coords.size.to_f) * 100).round(1)

    # Build GeoJSON
    JSON.build do |json|
      json.object do
        json.field "type", "Feature"
        json.field "properties" do
          json.object do
            json.field "slug", area.slug
            json.field "name", area.name
            json.field "type", type_name.chomp("s")  # Remove trailing 's'
            json.field "original_points", coords.size
            json.field "simplified_points", simplified.size
            json.field "reduction_percent", reduction
          end
        end
        json.field "geometry" do
          json.object do
            json.field "type", "Polygon"
            json.field "coordinates" do
              json.array do
                json.array do
                  simplified.each do |point|
                    json.array do
                      json.number point[0].round(6)  # lon
                      json.number point[1].round(6)  # lat
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

# Parse command line args
tolerance = 0.001
force = false

ARGV.each do |arg|
  if arg.starts_with?("--tolerance=")
    tolerance = arg.split("=")[1].to_f
  elsif arg == "--force" || arg == "-f"
    force = true
  elsif arg == "--help" || arg == "-h"
    puts "Usage: crystal run commands/generate_polygon_json.cr [options]"
    puts ""
    puts "Options:"
    puts "  --tolerance=N   Douglas-Peucker tolerance in degrees (default: 0.001)"
    puts "                  Lower = more detail, larger files"
    puts "                  Higher = less detail, smaller files"
    puts "                  Suggested: 0.0001 (detailed), 0.001 (balanced), 0.01 (minimal)"
    puts "  --force, -f     Regenerate all files (default: skip existing)"
    puts "  --help, -h      Show this help"
    exit 0
  end
end

command = Commands::GeneratePolygonJson.new(tolerance: tolerance, force: force)
command.run
