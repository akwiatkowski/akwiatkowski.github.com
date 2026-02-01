require "../../tremolite/src/tremolite"
require "../data/src/blog"
require "../data/src/services/area_matcher/all"

# Job struct to pass work to workers
struct PostJob
  getter post : Tremolite::Post
  getter output_dir : String
  getter index : Int32
  getter total : Int32

  def initialize(@post, @output_dir, @index, @total)
  end
end

class Commands::GenerateAreasForPosts
  ENVS = ["dev", "full"]
  DEFAULT_WORKERS = 4

  @workers : Int32
  @overwrite : Bool
  @processed : Atomic(Int32)
  @skipped : Atomic(Int32)

  def initialize(@overwrite : Bool = false, @workers : Int32 = DEFAULT_WORKERS)
    @processed = Atomic(Int32).new(0)
    @skipped = Atomic(Int32).new(0)
    puts "Workers: #{@workers}"
    puts "Overwrite mode: #{@overwrite}"
  end

  def run
    ENVS.each do |env|
      puts "\n=== Processing env: #{env} ==="
      @processed.set(0)
      @skipped.set(0)
      process_env(env)
    end

    puts "\nDone!"
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
    total = posts_with_routes.size
    puts "Found #{total} posts with detailed routes (out of #{posts.size} total)"
    puts "Starting #{@workers} workers..."

    # Channels for work distribution
    jobs_channel = Channel(PostJob).new(@workers * 2)
    done_channel = Channel(Nil).new

    # Spawn workers
    @workers.times do |worker_id|
      spawn do
        # Each worker creates its own Matcher (memory-heavy but thread-safe)
        matcher = AreaMatcher::Matcher.new
        puts "  Worker #{worker_id} ready"

        loop do
          job = jobs_channel.receive?
          break if job.nil?

          process_post(job, matcher, worker_id)
        end

        matcher.finalize
        done_channel.send(nil)
      end
    end

    # Feed jobs to workers
    posts_with_routes.each_with_index do |post, idx|
      jobs_channel.send(PostJob.new(post, output_dir, idx + 1, total))
    end
    jobs_channel.close

    # Wait for all workers to finish
    @workers.times { done_channel.receive }

    puts "Processed: #{@processed.get}, Skipped: #{@skipped.get}"
  end

  private def process_post(job : PostJob, matcher : AreaMatcher::Matcher, worker_id : Int32)
    post = job.post
    output_path = File.join([job.output_dir, "#{post.slug}.yml"])

    # Skip if file exists and overwrite is false
    if !@overwrite && File.exists?(output_path)
      @skipped.add(1)
      puts "  [W#{worker_id}] [#{job.index}/#{job.total}] #{post.slug}... skipped"
      return
    end

    routes_data = [] of Hash(String, String | Float64 | Array(Hash(String, String | Float64 | Nil)))

    post.detailed_routes.each do |route_obj|
      next if route_obj.route.size < 2

      # Get route match result (distances)
      route_result = matcher.match_route(route_obj.route)

      # Get point match result (all touched areas)
      point_result = matcher.match_points(route_obj.route)

      route_data = {
        "type"                   => route_obj.type,
        "total_distance_meters"  => route_result.total_distance_meters.round(2),
        "total_distance_km"      => (route_result.total_distance_meters / 1000.0).round(3),
        "points_count"           => route_obj.route.size.to_f64,
        "towns"                  => format_distance_results(route_result.towns),
        "counties"               => format_distance_results(route_result.counties),
        "voivodeships"           => format_distance_results(route_result.voivodeships),
        "meso_regions"           => format_distance_results(route_result.meso_regions),
        "macro_regions"          => format_distance_results(route_result.macro_regions),
        "mega_regions"           => format_distance_results(route_result.mega_regions),
        "subprovinces"           => format_distance_results(route_result.subprovinces),
        "provinces"              => format_distance_results(route_result.provinces),
        "touched_towns"          => format_matched_areas(point_result.towns),
        "touched_counties"       => format_matched_areas(point_result.counties),
        "touched_voivodeships"   => format_matched_areas(point_result.voivodeships),
        "touched_meso_regions"   => format_matched_areas(point_result.meso_regions),
        "touched_macro_regions"  => format_matched_areas(point_result.macro_regions),
        "touched_mega_regions"   => format_matched_areas(point_result.mega_regions),
        "touched_subprovinces"   => format_matched_areas(point_result.subprovinces),
        "touched_provinces"      => format_matched_areas(point_result.provinces),
      }

      routes_data << route_data
    end

    # Write YAML file
    File.write(output_path, routes_data.to_yaml)

    @processed.add(1)
    puts "  [W#{worker_id}] [#{job.index}/#{job.total}] #{post.slug}... #{routes_data.size} routes"
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

# Parse workers count: --workers=N or -w N
workers = Commands::GenerateAreasForPosts::DEFAULT_WORKERS
ARGV.each_with_index do |arg, i|
  if arg.starts_with?("--workers=")
    workers = arg.split("=")[1].to_i
  elsif arg == "-w" && ARGV[i + 1]?
    workers = ARGV[i + 1].to_i
  end
end

command = Commands::GenerateAreasForPosts.new(overwrite: overwrite, workers: workers)
command.run
