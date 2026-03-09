require "json"
require "yaml"
require "file_utils"
require "../base"

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
      left = simplify(coords[0..max_idx], tolerance)
      right = simplify(coords[max_idx..], tolerance)
      left[0...-1] + right
    else
      [first, last]
    end
  end

  private def self.perpendicular_distance(
    point : Array(Float64),
    line_start : Array(Float64),
    line_end : Array(Float64),
  ) : Float64
    x, y = point
    x1, y1 = line_start
    x2, y2 = line_end

    dx = x2 - x1
    dy = y2 - y1

    if dx == 0 && dy == 0
      return Math.sqrt((x - x1) ** 2 + (y - y1) ** 2)
    end

    numerator = ((dy * x) - (dx * y) + (x2 * y1) - (y2 * x1)).abs
    denominator = Math.sqrt(dx ** 2 + dy ** 2)

    numerator / denominator
  end
end

class Commands::Pipeline::GeneratePolygonJson
  OUTPUT_DIR = "data/config/polygons"
  CACHE_ENVS = ["dev", "full"]

  AREA_TYPES = {
    "towns"         => :towns,
    "counties"      => :counties,
    "voivodeships"  => :voivodeships,
    "meso_regions"  => :meso_regions,
    "macro_regions" => :macro_regions,
  }

  @matcher : AreaMatcher::Matcher
  @owns_matcher : Bool

  def initialize(
    @tolerance : Float64 = 0.001,
    @force : Bool = false,
    matcher : AreaMatcher::Matcher? = nil,
  )
    if matcher
      @matcher = matcher
      @owns_matcher = false
    else
      @matcher = AreaMatcher::Matcher.new
      @owns_matcher = true
    end
    puts "AreaMatcher loaded: #{@matcher.stats}"
    puts "Simplification tolerance: #{@tolerance}"
    puts "Force regenerate: #{@force}"
  end

  def run
    visited_areas = collect_visited_areas

    puts "\nVisited areas summary:"
    AREA_TYPES.keys.each do |type|
      count = visited_areas[type]?.try(&.size) || 0
      puts "  #{type}: #{count} unique areas"
    end

    puts "\n=== Generating polygon GeoJSON ==="
    polygons = generate_polygons(visited_areas)

    puts "\n=== Writing to #{OUTPUT_DIR} ==="
    write_polygons(polygons)

    @matcher.finalize if @owns_matcher
    puts "\nDone!"
  end

  private def collect_visited_areas : Hash(String, Set(String))
    visited = Hash(String, Set(String)).new { |h, k| h[k] = Set(String).new }

    # Source 1: GPS-matched areas from route cache
    CACHE_ENVS.each do |env|
      cache_dir = File.join(["env", env, "cache", "areas_for_post"])
      next unless Dir.exists?(cache_dir)

      Dir.glob(File.join([cache_dir, "*.yml"])).each do |file|
        parse_area_file(file, visited)
      end
    end

    # Source 2: Manually listed areas in post frontmatter (additive)
    collect_frontmatter_areas(visited)

    visited
  end

  private def parse_area_file(path : String, visited : Hash(String, Set(String)))
    data = YAML.parse(File.read(path))
    return unless data.as_a?

    data.as_a.each do |route|
      AREA_TYPES.keys.each do |type|
        if areas = route[type]?
          areas.as_a.each do |area|
            if slug = area["slug"]?.try(&.as_s?)
              visited[type].add(slug)
            end
          end
        end

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

  # Scan post frontmatter for manually listed towns/lands and add them
  # to the visited set. Post frontmatter `towns:` can contain both town
  # and voivodeship slugs; `lands:` can contain meso/macro region slugs.
  private def collect_frontmatter_areas(visited : Hash(String, Set(String)))
    # Build slug → area type lookup from matcher data
    slug_to_type = Hash(String, String).new
    {
      "towns"         => @matcher.towns,
      "counties"      => @matcher.counties,
      "voivodeships"  => @matcher.voivodeships,
      "meso_regions"  => @matcher.meso_regions,
      "macro_regions" => @matcher.macro_regions,
    }.each do |type_name, areas|
      areas.each { |area| slug_to_type[area.slug] = type_name }
    end

    added = 0

    CACHE_ENVS.each do |env|
      posts_dir = File.join(["env", env, "data", "posts"])
      next unless Dir.exists?(posts_dir)

      Dir.glob(File.join([posts_dir, "**", "*.md"])).each do |path|
        added += parse_frontmatter_areas(path, visited, slug_to_type)
      end
    end

    puts "Frontmatter: #{added} additional area references added" if added > 0
  end

  # Parse a post markdown file and extract towns:/lands: from YAML frontmatter.
  # Returns count of newly added slugs.
  private def parse_frontmatter_areas(
    path : String,
    visited : Hash(String, Set(String)),
    slug_to_type : Hash(String, String),
  ) : Int32
    content = File.read(path)
    return 0 unless content.starts_with?("---")

    # Find end of YAML frontmatter
    end_idx = content.index("---", 3)
    return 0 unless end_idx

    frontmatter = content[4...end_idx]
    added = 0

    # Extract towns: [...] — contains town and voivodeship slugs
    if match = frontmatter.match(/^towns:\s*\[([^\]]*)\]/m)
      match[1].split(",").each do |raw|
        slug = raw.strip
        next if slug.empty?
        if type = slug_to_type[slug]?
          unless visited[type].includes?(slug)
            visited[type].add(slug)
            added += 1
          end
        end
      end
    end

    # Extract lands: [...] — contains meso/macro region slugs
    if match = frontmatter.match(/^lands:\s*\[([^\]]*)\]/m)
      match[1].split(",").each do |raw|
        slug = raw.strip
        next if slug.empty?
        if type = slug_to_type[slug]?
          unless visited[type].includes?(slug)
            visited[type].add(slug)
            added += 1
          end
        end
      end
    end

    added
  end

  private def generate_polygons(
    visited_areas : Hash(String, Set(String)),
  ) : Hash(String, Hash(String, String))
    result = Hash(String, Hash(String, String)).new { |h, k| h[k] = Hash(String, String).new }

    AREA_TYPES.each do |type_name, area_method|
      areas = get_areas_by_type(area_method)
      visited_slugs = visited_areas[type_name]? || Set(String).new

      generated = 0

      areas.each do |area|
        next unless visited_slugs.includes?(area.slug)

        geojson = generate_geojson(area, type_name)
        result[type_name][area.slug] = geojson
        generated += 1
      end

      puts "  #{type_name}: #{generated} polygons generated"
    end

    result
  end

  private def write_polygons(polygons : Hash(String, Hash(String, String)))
    written = 0
    skipped = 0

    polygons.each do |type_name, type_polygons|
      output_dir = File.join([OUTPUT_DIR, type_name])
      Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

      type_polygons.each do |slug, geojson|
        output_path = File.join([output_dir, "#{slug}.json"])

        if !@force && File.exists?(output_path)
          skipped += 1
          next
        end

        File.write(output_path, geojson)
        written += 1
      end
    end

    puts "  #{written} written, #{skipped} skipped"
  end

  private def get_areas_by_type(area_type : Symbol) : Array(AreaMatcher::Area)
    case area_type
    when :towns         then @matcher.towns
    when :counties      then @matcher.counties
    when :voivodeships  then @matcher.voivodeships
    when :meso_regions  then @matcher.meso_regions
    when :macro_regions then @matcher.macro_regions
    else                     [] of AreaMatcher::Area
    end
  end

  private def generate_geojson(area : AreaMatcher::Area, type_name : String) : String
    coords = area.coords
    simplified = DouglasPeucker.simplify(coords, @tolerance)

    if simplified.size >= 3 && simplified.first != simplified.last
      simplified << simplified.first.dup
    end

    reduction = ((1.0 - simplified.size.to_f / coords.size.to_f) * 100).round(1)

    JSON.build do |json|
      json.object do
        json.field "type", "Feature"
        json.field "properties" do
          json.object do
            json.field "slug", area.slug
            json.field "name", area.name
            json.field "type", type_name.chomp("s")
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
                      json.number point[0].round(6) # lon
                      json.number point[1].round(6) # lat
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
