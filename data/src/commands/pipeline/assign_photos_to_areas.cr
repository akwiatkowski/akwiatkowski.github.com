require "../base"

class Commands::Pipeline::AssignPhotosToAreas
  AREA_TYPES = ["towns", "counties", "voivodeships", "meso_regions", "macro_regions"]

  @matcher : AreaMatcher::Matcher
  @owns_matcher : Bool

  def initialize(@overwrite : Bool = false, matcher : AreaMatcher::Matcher? = nil)
    if matcher
      @matcher = matcher
      @owns_matcher = false
    else
      @matcher = AreaMatcher::Matcher.new
      @owns_matcher = true
    end
    puts "AreaMatcher loaded: #{@matcher.stats}"
    puts "Overwrite mode: #{@overwrite}"
  end

  def run
    Commands::ENVS.each do |env|
      puts "\n=== Processing env: #{env} ==="
      process_env(env)
    end

    @matcher.finalize if @owns_matcher
    puts "\nDone!"
  end

  private def process_env(env : String)
    blog = Commands.init_blog(env)
    posts = blog.post_collection.posts

    # Initialize EXIF data so published_photo_entities are populated with GPS coords
    exif_db = blog.data_manager.exif_db
    puts "Initializing EXIF data for #{posts.size} posts..."
    posts.each { |post| exif_db.initialize_post_photos_exif(post) }

    # Base cache directory
    cache_dir = File.join([blog.cache_path, "photos_in_area"])
    Dir.mkdir_p(cache_dir) unless Dir.exists?(cache_dir)

    # Create subdirectories for each area type
    AREA_TYPES.each do |type_name|
      subdir = File.join([cache_dir, type_name])
      Dir.mkdir_p(subdir) unless Dir.exists?(subdir)
    end

    # Read manifest of already-processed photos
    manifest_path = File.join([cache_dir, "already_assigned.txt"])
    already_assigned = read_manifest(manifest_path)
    puts "Already assigned: #{already_assigned.size} photos"

    # Collect all geo-tagged photos
    all_photos = [] of {String, Float64, Float64} # {photo_id, lat, lon}
    posts.each do |post|
      post.published_photo_entities.each do |photo|
        lat = photo.exif.lat
        lon = photo.exif.lon
        next unless lat && lon

        photo_id = "#{photo.post_slug}/#{photo.image_filename}"
        all_photos << {photo_id, lat, lon}
      end
    end

    puts "Total geo-tagged photos: #{all_photos.size}"

    # Filter to new photos only (unless overwrite)
    if @overwrite
      already_assigned.clear
      photos_to_process = all_photos
    else
      photos_to_process = all_photos.reject { |id, _, _| already_assigned.includes?(id) }
    end

    puts "Photos to process: #{photos_to_process.size}"

    if photos_to_process.empty?
      puts "Nothing to do."
      ensure_empty_files(cache_dir)
      return
    end

    # Process each photo through matcher
    results = Hash({String, String}, Array({String, String})).new
    newly_assigned = [] of String

    photos_to_process.each_with_index do |(photo_id, lat, lon), idx|
      if (idx + 1) % 100 == 0 || idx == 0
        print "  Processing #{idx + 1}/#{photos_to_process.size}...\r"
      end

      match = @matcher.match_point(lat, lon)

      add_matches(results, "towns", match.towns, photo_id)
      add_matches(results, "counties", match.counties, photo_id)
      add_matches(results, "voivodeships", match.voivodeships, photo_id)
      add_matches(results, "meso_regions", match.meso_regions, photo_id)
      add_matches(results, "macro_regions", match.macro_regions, photo_id)

      newly_assigned << photo_id
    end

    puts "  Processed #{photos_to_process.size} photos, matched to #{results.size} area-slug pairs"

    # Merge results into existing cache files
    results.each do |(type_name, slug), entries|
      cache_file = File.join([cache_dir, type_name, "#{slug}.yml"])

      existing = if !@overwrite && File.exists?(cache_file)
                   read_cache_file(cache_file)
                 else
                   [] of {String, String}
                 end

      existing_set = existing.map { |f, p| "#{p}/#{f}" }.to_set
      entries.each do |filename, post_slug|
        photo_id = "#{post_slug}/#{filename}"
        unless existing_set.includes?(photo_id)
          existing << {filename, post_slug}
        end
      end

      write_cache_file(cache_file, existing)
    end

    ensure_empty_files(cache_dir)

    # Update manifest
    if @overwrite
      File.write(manifest_path, newly_assigned.join("\n") + "\n")
    else
      File.open(manifest_path, "a") do |f|
        newly_assigned.each { |id| f.puts(id) }
      end
    end

    puts "Manifest updated: #{already_assigned.size + newly_assigned.size} total photos tracked"
  end

  private def add_matches(
    results : Hash({String, String}, Array({String, String})),
    type_name : String,
    matched_areas : Array(AreaMatcher::MatchedArea),
    photo_id : String,
  )
    parts = photo_id.split("/", 2)
    post_slug = parts[0]
    filename = parts[1]

    matched_areas.each do |area|
      key = {type_name, area.slug}
      results[key] ||= [] of {String, String}
      results[key] << {filename, post_slug}
    end
  end

  def read_manifest(path : String) : Set(String)
    return Set(String).new unless File.exists?(path)
    lines = File.read(path).split("\n").reject(&.empty?)
    lines.to_set
  end

  def read_cache_file(path : String) : Array({String, String})
    entries = [] of {String, String}
    yaml = YAML.parse(File.read(path))
    return entries unless yaml.raw.is_a?(Array)

    yaml.as_a.each do |entry|
      filename = entry["filename"]?.try(&.as_s) || next
      post_slug = entry["post_slug"]?.try(&.as_s) || next
      entries << {filename, post_slug}
    end
    entries
  end

  def write_cache_file(path : String, entries : Array({String, String}))
    data = entries.map do |filename, post_slug|
      {"filename" => filename, "post_slug" => post_slug}
    end
    File.write(path, data.to_yaml)
  end

  private def ensure_empty_files(cache_dir : String)
    ensure_empty_for_type(cache_dir, "towns", @matcher.towns)
    ensure_empty_for_type(cache_dir, "counties", @matcher.counties)
    ensure_empty_for_type(cache_dir, "voivodeships", @matcher.voivodeships)
    ensure_empty_for_type(cache_dir, "meso_regions", @matcher.meso_regions)
    ensure_empty_for_type(cache_dir, "macro_regions", @matcher.macro_regions)
  end

  private def ensure_empty_for_type(cache_dir : String, type_name : String, areas : Array(AreaMatcher::Area))
    dir = File.join([cache_dir, type_name])
    created = 0
    areas.each do |area|
      path = File.join([dir, "#{area.slug}.yml"])
      unless File.exists?(path)
        File.write(path, "--- []\n")
        created += 1
      end
    end
    puts "  Created #{created} empty cache files for #{type_name}" if created > 0
  end
end
