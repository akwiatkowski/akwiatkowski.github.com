class Tremolite::Validator
  def custom_validators
    check_missing_towns
    validate_exif_name_dictionary
  end

  # Validate objects passed from registry
  # Note: TownEntity validation removed - areas now use auto-selected photos via AreaPhotoSelector
  def validate_object(object)
    # TagEntity validation can be added here if needed
  end

  private def validate_exif_name_dictionary
    ExifEntity.log_not_named
  end

  private def check_missing_towns
    all_towns_or_voivodeships = (@blog.data_manager.not_nil!.towns.not_nil! + @blog.data_manager.not_nil!.voivodeships.not_nil!).map(&.slug)
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }

    self_propelled_posts = posts.select { |post| post.self_propelled? }
    not_self_propelled_posts = posts.select { |post| post.self_propelled? != true }

    # self propelled posts should have defined towns
    self_propelled_posts.each do |post|
      towns_or_voivodeships = post.towns.not_nil!
      self_propelled = post.self_propelled?

      towns_or_voivodeships.each do |slug|
        common_count = all_towns_or_voivodeships.select { |s| slug == s }.size
        if common_count == 0
          error_in_post(post, "missing town #{slug}")
        end
      end
    end

    # not self propelled posts towns are optional
    not_self_propelled_posts.each do |post|
      towns_or_voivodeships = post.towns.not_nil!
      self_propelled = post.self_propelled?

      towns_or_voivodeships.each do |slug|
        common_count = all_towns_or_voivodeships.select { |s| slug == s }.size
        if common_count == 0
          warning_in_post(post, "missing town #{slug}")
        end
      end
    end
  end

  private def is_url_html?(url)
    # puts "#{url} - #{File.extname(url).to_s}"
    File.extname(url).to_s == "" || File.extname(url).to_s == ".html" || File.extname(url).to_s == ".htm"
  end

  # duplicated for debugging
  private def check_missing_referenced_links
    @html_buffer.buffer.each do |url, content|
      # puts "#{url} - #{is_url_html?(url)}"
      if is_url_html?(url)
        # only check html
        result = content.scan(/\[([^]]+)\]\[([^]]+)\]/)
        if result.size > 0
          Log.error { "missing referenced definitons at #{url}, reference buffer size #{@html_buffer.referenced_links_count}" }
          # removed sort because having order it's easier to find meaning of
          # link symbol, ex: when searcing for town in wikipedia
          result.map { |r| r[2] }.uniq.each do |key|
            # note, if it process only changed post we won't have
            # access to already finished post and this would be useles
            existing_url = @html_buffer.get_referenced_link(key)

            if existing_url
              puts "<!-- from #{existing_url[:post_slug]} -->" if existing_url[:post_slug]
              existing_url_string = "#{existing_url[:url]}"
            else
              existing_url_string = ""
            end

            # we want to use it most efficiently
            # so I could copy these lines and use wikipedia to get links
            puts "[#{key.to_s.colorize(:red)}]: #{existing_url_string}"
          end
        end
      end
    end
  end
end
