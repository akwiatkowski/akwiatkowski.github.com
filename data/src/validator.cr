class Tremolite::Validator
  include Profiled

  def custom_validators
    check_missing_towns
    validate_exif_name_dictionary
    validate_html_output
  end

  # Validate objects passed from registry
  # Note: TownEntity validation removed - areas now use auto-selected photos via AreaPhotoSelector
  def validate_object(object)
    # TagEntity validation can be added here if needed
  end

  @[Profile(category: "validation")]
  private def validate_exif_name_dictionary
    ExifEntity.log_not_named
  end

  @[Profile(category: "validation")]
  private def check_missing_towns
    known_slugs = @blog.data_manager.not_nil!.area_data_loader.not_nil!
      .areas.select { |a| a.area_type.town? || a.area_type.voivodeship? }
      .map(&.slug)
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }

    post_data = posts.map { |p| {p.town_slugs, p.self_propelled?, p.slug} }
    results = self.class.find_missing_towns(known_slugs, post_data)
    results[:errors].each { |msg| Log.error { msg } }
    results[:warnings].each { |msg| Log.warn { msg } }
  end

  # Pure logic: find posts referencing unknown town slugs (testable without Blog)
  # Each post_data tuple: {town_slugs, self_propelled?, post_slug}
  def self.find_missing_towns(known_slugs : Array(String), post_data : Array({Array(String), Bool, String}))
    known = Set(String).new(known_slugs)
    errors = Array(String).new
    warnings = Array(String).new

    post_data.each do |town_slugs, self_propelled, post_slug|
      town_slugs.each do |slug|
        unless known.includes?(slug)
          if self_propelled
            errors << "#{post_slug}: missing town #{slug}"
          else
            warnings << "#{post_slug}: missing town #{slug}"
          end
        end
      end
    end

    {errors: errors, warnings: warnings}
  end

  @[Profile(category: "validation")]
  private def validate_html_output
    processor = HtmlProcessor.new(validate: true)
    error_count = 0
    warning_count = 0
    page_count = 0
    total_size = 0_i64
    slowest_url = ""
    slowest_ms = 0.0

    t_start = Time.instant

    @html_buffer.buffer.each do |url, content|
      next unless is_url_html?(url)

      page_count += 1
      total_size += content.bytesize

      t_page = Time.instant
      result = processor.process(content, url)
      page_ms = (Time.instant - t_page).total_milliseconds

      if page_ms > slowest_ms
        slowest_ms = page_ms
        slowest_url = url
      end

      if page_ms > 500
        Log.warn { "Slow validation: #{url} (#{page_ms.round(1)}ms, #{content.bytesize / 1024}KB)" }
      end

      result.errors.each do |error|
        Log.error { error.to_s }
        error_count += 1
      end
    end

    elapsed = (Time.instant - t_start).total_milliseconds

    if error_count > 0
      Log.error { "HTML validation: #{error_count} errors found" }
    else
      Log.info { "HTML validation: passed" }
    end

    Log.info { "HTML validation stats: #{page_count} pages, #{total_size / 1024}KB total, #{elapsed.round(1)}ms" }
    Log.info { "HTML validation slowest: #{slowest_url} (#{slowest_ms.round(1)}ms)" }
  end

  private def is_url_html?(url)
    # Skip internal cache keys (e.g. __html_head_core__)
    return false if url.starts_with?("__")

    # Skip template cache entries (no leading /, e.g. "pomysly_tras.html")
    return false unless url.starts_with?("/")

    ext = File.extname(url).to_s
    ext == "" || ext == ".html" || ext == ".htm"
  end

end
