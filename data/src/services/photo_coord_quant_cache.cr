class PhotoCoordQuantCache
  Log = ::Log.for(self)

  QUANT = 0.2

  getter :cache_file_path, :cache

  alias PhotoCoordCacheKey = NamedTuple(
    lat: Float32,
    lon: Float32)
  alias PhotoCoordPhoto = NamedTuple(
    image_filename: String,
    post_slug: String,
    time: Time,
    lat: Float32,
    lon: Float32,
  )
  alias PhotoCoordCacheArray = Array(PhotoCoordPhoto)
  alias PhotoCoordQuantCacheStruct = Hash(PhotoCoordCacheKey, PhotoCoordCacheArray)

  def initialize(@blog : Tremolite::Blog)
    @cache_path = @blog.cache_path.as(String)
    @cache_file_path = File.join([@cache_path, "photo_coord_quant.yml"])
    @cache = PhotoCoordQuantCacheStruct.new
    load_cache
  end

  def refresh
    @blog.post_collection.posts.each do |post|
      refresh_for_post(post)
    end

    save_cache
  end

  # refresh quants for post
  # not calculate `related_posts`
  def refresh_for_post(post : Tremolite::Post)
    post.all_photo_entities_unsorted.each do |photo_entity|
      next if photo_entity.exif.lat.nil? || photo_entity.exif.lon.nil?

      key = convert_photo_entity_to_key(photo_entity)
      coord_photo = convert_photo_entity_to_coord_photo(photo_entity)

      @cache[key] ||= PhotoCoordCacheArray.new
      unless @cache[key].includes?(coord_photo)
        @cache[key] << coord_photo
      end
    end
  end

  def convert_photo_entity_to_key(photo_entity : PhotoEntity)
    return key_for_coord(
      lat: photo_entity.exif.lat.not_nil!.to_f32,
      lon: photo_entity.exif.lon.not_nil!.to_f32,
    )
  end

  def convert_photo_entity_to_coord_photo(photo_entity : PhotoEntity)
    PhotoCoordPhoto.new(
      image_filename: photo_entity.image_filename,
      post_slug: photo_entity.post_slug,
      time: photo_entity.accurate_time,
      lat: photo_entity.exif.lat.not_nil!.to_f32,
      lon: photo_entity.exif.lon.not_nil!.to_f32,
    )
  end

  def key_for_coord(lat : Float32, lon : Float32)
    return PhotoCoordCacheKey.new(
      lat: CoordQuant.round(value: lat, quant: QUANT),
      lon: CoordQuant.round(value: lon, quant: QUANT)
    )
  end

  def get(lat : Float32, lon : Float32)
    return @cache[{lat: lat, lon: lon}]?
  end

  def get(photo_entity : PhotoEntity)
    key = convert_photo_entity_to_key(photo_entity)
    return get(
      lat: key[:lat],
      lon: key[:lon]
    )
  end

  private def exif_db
    @blog.data_manager.exif_db
  end

  private def save_cache
    Log.info { "save_cache with #{@cache.keys.size} arrays" }

    File.open(cache_file_path, "w") do |f|
      @cache.to_yaml(f)
    end
  end

  private def load_cache
    if File.exists?(cache_file_path)
      Log.debug { "loading cache #{cache_file_path}" }
      begin
        @cache = PhotoCoordQuantCacheStruct.from_yaml(File.open(cache_file_path))
      rescue YAML::ParseException
        Log.error { "cache #{cache_file_path} format invalid" }
      end
    end
  end
end
