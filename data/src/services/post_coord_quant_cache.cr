class PostCoordQuantCache
  Log = ::Log.for(self)

  QUANT = 0.2

  alias PostCoordCache = NamedTuple(
    related_posts: Hash(String, PostCoordRelatedCache),
    quants: Array(CoordQuant))
  alias PostCoordRelatedCache = NamedTuple(
    common_factor: Int32,
    common_size: Int32,
    not_common_size: Int32,
    days_diff: Int32)
  alias PostCoordQuantCacheStruct = Hash(String, PostCoordCache)

  getter :cache_file_path

  def initialize(@blog : Tremolite::Blog)
    @cache_path = @blog.cache_path.as(String)
    @cache_file_path = File.join([@cache_path, "post_coord_quant.yml"])
    @cache = PostCoordQuantCacheStruct.new
    load_cache
  end

  def refresh
    # TODO what about empty posts?

    # generate quant coords first
    @blog.post_collection.posts.each do |post|
      refresh_for_post(post)
    end

    # using generated values calculate similarity coefficient
    @blog.post_collection.posts.each do |post|
      @blog.post_collection.posts.each do |compared_post|
        next if post == compared_post

        compare_result = CoordSet.compare(
          set: @cache[post.slug][:quants],
          other_set: @cache[compared_post.slug][:quants],
        )

        # there is no point of having large N*N array
        if compare_result[:common_factor] > 1
          @cache[post.slug][:related_posts][compared_post.slug] = {
            common_factor:   compare_result[:common_factor],
            common_size:     compare_result[:common_size],
            not_common_size: compare_result[:not_common_size],
            days_diff:       (post.time - compared_post.time).days.abs.to_i32,
          }
        end
      end
    end

    save_cache
  end

  # refresh quants for post
  # not calculate `related_posts`
  def refresh_for_post(post : Tremolite::Post)
    set = CoordSet.new(
      post: post,
      quant: QUANT
    )

    @cache[post.slug] = PostCoordCache.new(
      related_posts: Hash(String, PostCoordRelatedCache).new,
      quants: set.set
    )

    return @cache[post.slug][:quants]
  end

  def get(slug_name : String)
    return @cache[slug_name]?
  end

  private def exif_db
    @blog.data_manager.exif_db
  end

  private def save_cache
    Log.debug { "save_cache" }

    File.open(cache_file_path, "w") do |f|
      @cache.to_yaml(f)
    end
  end

  private def load_cache
    if File.exists?(cache_file_path)
      Log.debug { "loading cache #{cache_file_path}" }
      begin
        @cache = PostCoordQuantCacheStruct.from_yaml(File.open(cache_file_path))
      rescue YAML::ParseException
        Log.error { "cache #{cache_file_path} format invalid" }
      end
    end
  end
end
