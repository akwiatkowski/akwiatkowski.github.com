class PhotoAnalysisCache
  Log = ::Log.for(self)

  SCRIPT_PATH = "tools/photo_analysis.py"

  def initialize(
    @cache_path : String,
    @data_path : String,
  )
    @entries = Hash(String, Array(PhotoAnalysisEntity)).new
    @dirty = Hash(String, Bool).new
    @loaded_posts = Hash(String, Bool).new
  end

  def entries_for(post_slug : String) : Array(PhotoAnalysisEntity)
    @entries[post_slug]? || Array(PhotoAnalysisEntity).new
  end

  def process_photos(post_slug : String, photo_filenames : Array(String))
    load_or_initialize(post_slug)

    existing_filenames = @entries[post_slug].map(&.image_filename).to_set
    missing = photo_filenames.reject { |f| existing_filenames.includes?(f) }

    return if missing.empty?

    # Build absolute paths for missing photos
    image_paths = missing.compact_map do |filename|
      path = File.join(@data_path, "images", post_slug_to_image_dir(post_slug), filename)
      if File.exists?(path)
        path
      else
        Log.debug { "Image not found: #{path}" }
        nil
      end
    end

    return if image_paths.empty?

    results = run_analysis(image_paths, post_slug)
    results.each do |entity|
      @entries[post_slug] << entity
      @dirty[post_slug] = true
    end
  end

  def save_cache(post_slug : String)
    dirty = @dirty[post_slug]?
    return unless dirty

    create_path_if_needed
    File.open(cache_file_path(post_slug), "w") do |f|
      @entries[post_slug].sort { |a, b|
        a.image_filename <=> b.image_filename
      }.to_yaml(f)
    end

    Log.info { "save_photo_analysis #{@entries[post_slug].size} entries for #{post_slug}" }
  end

  def load_or_initialize(post_slug : String)
    return if @entries[post_slug]?

    create_path_if_needed
    path = cache_file_path(post_slug)
    if File.exists?(path)
      @entries[post_slug] = Array(PhotoAnalysisEntity).from_yaml(File.open(path))
      @dirty[post_slug] = false
    else
      @entries[post_slug] = Array(PhotoAnalysisEntity).new
      @dirty[post_slug] = true
    end
  end

  def cache_parent_path : String
    File.join(@cache_path, "photo_analysis")
  end

  def cache_file_path(post_slug : String) : String
    File.join(cache_parent_path, "#{post_slug}.yml")
  end

  private def create_path_if_needed
    Dir.mkdir_p(cache_parent_path)
  end

  # Convert post slug like "2021-07-18-pagorki" to image dir "2021/2021-07-18-pagorki"
  private def post_slug_to_image_dir(post_slug : String) : String
    year = post_slug[0..3]
    File.join(year, post_slug)
  end

  private def run_analysis(image_paths : Array(String), post_slug : String) : Array(PhotoAnalysisEntity)
    unless File.exists?(SCRIPT_PATH)
      Log.warn { "Photo analysis script not found: #{SCRIPT_PATH}" }
      return Array(PhotoAnalysisEntity).new
    end

    input = image_paths.join("\n") + "\n"
    output = IO::Memory.new
    error = IO::Memory.new

    status = Process.run(
      "python3", [SCRIPT_PATH],
      input: IO::Memory.new(input),
      output: output,
      error: error
    )

    unless status.success?
      Log.warn { "Photo analysis failed: #{error.to_s}" }
      return Array(PhotoAnalysisEntity).new
    end

    json_str = output.to_s.strip
    return Array(PhotoAnalysisEntity).new if json_str.empty?

    begin
      raw_results = JSON.parse(json_str).as_a
      raw_results.map do |item|
        PhotoAnalysisEntity.new(
          image_filename: item["file"].as_s,
          post_slug: post_slug,
          ahash: item["ahash"].as_s,
          dhash: item["dhash"].as_s,
          phash: item["phash"].as_s,
          avg_rgb: item["avg_rgb"].as_a.map(&.as_i),
          top5_rgb: item["top5_rgb"].as_a.map { |row| row.as_a.map(&.as_i) },
        )
      end
    rescue ex
      Log.warn { "Failed to parse photo analysis output: #{ex.message}" }
      Array(PhotoAnalysisEntity).new
    end
  end
end
