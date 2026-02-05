require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/services/area_matcher/all"

class Commands::GenerateAreasForPosts
  ENVS = ["dev", "full"]

  def initialize(@overwrite : Bool = false)
    @matcher = AreaMatcher::Matcher.new
    puts "AreaMatcher loaded: #{@matcher.stats}"
    puts "Overwrite mode: #{@overwrite}"
  end

  def run
    ENVS.each do |env|
      puts "\n=== Processing env: #{env} ==="
      process_env(env)
    end

    # Generate area config files (once, not per-env)
    puts "\n=== Generating area config files ==="
    generate_area_configs

    @matcher.finalize
    puts "\nDone!"
  end

  # Generate area config files from data/external/ to data/config/areas/
  private def generate_area_configs
    output_dir = "data/config/areas"
    Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

    generate_area_config("towns", @matcher.towns, output_dir)
    generate_area_config("counties", @matcher.counties, output_dir)
    generate_area_config("voivodeships", @matcher.voivodeships, output_dir)
    generate_area_config("meso_regions", @matcher.meso_regions, output_dir)
    generate_area_config("macro_regions", @matcher.macro_regions, output_dir)
  end

  private def generate_area_config(name : String, areas : Array(AreaMatcher::Area), output_dir : String)
    data = areas.map do |area|
      entry = {
        "slug" => area.slug,
        "name" => area.name,
        "code" => area.code || area.terc,
      } of String => String | Hash(String, Float64) | Nil

      # special fix for voivodeships where name was uppercase
      if name == "voivodeships"
        entry["name"] = entry["name"].to_s.downcase
      end

      # Add voivodeship for administrative areas
      if area.voivodeship
        entry["voivodeship"] = area.voivodeship
      end

      # Compute bbox from polygon coords
      if area.coords.size > 0
        entry["bbox"] = compute_bbox(area.coords)
      end

      entry
    end

    output_path = File.join([output_dir, "#{name}.yml"])
    File.write(output_path, data.to_yaml)
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

  private def process_env(env : String)
    env_path = File.join(["env", env])
    universal_path = "data"

    blog = Tremolite::Blog.new(
      mod_watcher_yaml_path: File.join([env_path, "cache", "mod_watcher.yml"]),
      data_path: File.join([env_path, "data"]),
      output_path: File.join([env_path, "public"]),
      config_path: File.join([universal_path, "config"]),
      cache_path: File.join([env_path, "cache"]),
      layout_path: File.join([universal_path, "layout"]),
      assets_path: File.join([universal_path, "assets"]),
      pages_path: File.join([universal_path, "pages"]),
    ).as(Tremolite::Blog)

    blog.post_collection.initialize_posts
    posts = blog.post_collection.posts

    # Create output directory
    output_dir = File.join([blog.cache_path, "areas_for_post"])
    Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

    posts_with_routes = posts.select { |p| p.has_detailed_route? }
    puts "Found #{posts_with_routes.size} posts with detailed routes (out of #{posts.size} total)"

    processed = 0
    skipped = 0

    posts_with_routes.each_with_index do |post, idx|
      result = process_post(post, output_dir, idx + 1, posts_with_routes.size)
      if result
        processed += 1
      else
        skipped += 1
      end
    end

    puts "Processed: #{processed}, Skipped: #{skipped}"
  end

  private def process_post(post : Tremolite::Post, output_dir : String, current : Int32, total : Int32) : Bool
    output_path = File.join([output_dir, "#{post.slug}.yml"])

    # Skip if file exists and overwrite is false
    if !@overwrite && File.exists?(output_path)
      puts "  [#{current}/#{total}] #{post.slug}... skipped (exists)"
      return false
    end

    print "  [#{current}/#{total}] #{post.slug}... "

    routes_data = [] of Hash(String, String | Float64 | Array(Hash(String, String | Float64 | Nil)))

    post.detailed_routes.each do |route_obj|
      next if route_obj.route.size < 2

      # Get route match result (distances)
      route_result = @matcher.match_route(route_obj.route)

      # Get point match result (all touched areas)
      point_result = @matcher.match_points(route_obj.route)

      route_data = {
        "type"                  => route_obj.type,
        "total_distance_meters" => route_result.total_distance_meters.round(2),
        "total_distance_km"     => (route_result.total_distance_meters / 1000.0).round(3),
        "points_count"          => route_obj.route.size.to_f64,
        "towns"                 => format_distance_results(route_result.towns),
        "counties"              => format_distance_results(route_result.counties),
        "voivodeships"          => format_distance_results(route_result.voivodeships),
        "meso_regions"          => format_distance_results(route_result.meso_regions),
        "macro_regions"         => format_distance_results(route_result.macro_regions),
        "mega_regions"          => format_distance_results(route_result.mega_regions),
        "subprovinces"          => format_distance_results(route_result.subprovinces),
        "provinces"             => format_distance_results(route_result.provinces),
        "touched_towns"         => format_matched_areas(point_result.towns),
        "touched_counties"      => format_matched_areas(point_result.counties),
        "touched_voivodeships"  => format_matched_areas(point_result.voivodeships),
        "touched_meso_regions"  => format_matched_areas(point_result.meso_regions),
        "touched_macro_regions" => format_matched_areas(point_result.macro_regions),
        "touched_mega_regions"  => format_matched_areas(point_result.mega_regions),
        "touched_subprovinces"  => format_matched_areas(point_result.subprovinces),
        "touched_provinces"     => format_matched_areas(point_result.provinces),
      }

      routes_data << route_data
    end

    # Write YAML file
    File.write(output_path, routes_data.to_yaml)

    puts "#{routes_data.size} routes saved"
    true
  end

  private def format_distance_results(results : Array(AreaMatcher::RouteDistanceResult)) : Array(Hash(String, String | Float64 | Nil))
    results.map do |r|
      # Use terc for administrative areas (Town, County, Voivodeship), code for geographic regions
      code_value = r.area.terc || r.area.code
      {
        "slug"             => r.area.slug,
        "name"             => r.area.name,
        "code"             => code_value,
        "distance_meters"  => r.distance_meters,
        "distance_km"      => (r.distance_meters / 1000.0).round(3),
        "distance_percent" => r.distance_percent,
      }
    end
  end

  private def format_matched_areas(areas : Array(AreaMatcher::MatchedArea)) : Array(Hash(String, String | Float64 | Nil))
    areas.map do |a|
      # Use terc for administrative areas (Town, County, Voivodeship), code for geographic regions
      code_value = a.terc || a.code
      hash = Hash(String, String | Float64 | Nil).new
      hash["slug"] = a.slug
      hash["name"] = a.name
      hash["code"] = code_value
      hash
    end
  end
end

# Parse command line args
overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::GenerateAreasForPosts.new(overwrite: overwrite)
command.run
