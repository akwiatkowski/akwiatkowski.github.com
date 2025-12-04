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
  alias PhotoCoordCacheAdditionalInfo = NamedTuple(closest_town_name: String?, closest_town_distance: Float32)
  alias PhotoCoordCacheContainer = NamedTuple(array: PhotoCoordCacheArray, info: PhotoCoordCacheAdditionalInfo)
  alias PhotoCoordQuantCacheStruct = Hash(PhotoCoordCacheKey, PhotoCoordCacheContainer)

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
      # for now only photos in Poland and close to it
      next unless CoordRange.within_poland?(
                    lat: photo_entity.exif.lat.not_nil!,
                    lon: photo_entity.exif.lon.not_nil!,
                  )

      key = convert_photo_entity_to_key(photo_entity)
      coord_photo = convert_photo_entity_to_coord_photo(photo_entity)

      @cache[key] ||= photo_container_for(
        lat: photo_entity.exif.lat.not_nil!.to_f32,
        lon: photo_entity.exif.lon.not_nil!.to_f32
      )
      unless @cache[key][:array].includes?(coord_photo)
        @cache[key][:array] << coord_photo
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

  def closest_town(lat : Float32, lon : Float32)
    all_towns = @blog.data_manager.not_nil!.towns.not_nil!
    towns_with_coords = all_towns.select do |town|
      town.lat != nil && town.lon != nil
    end

    sorted_towns = towns_with_coords.sort do |town_a, town_b|
      a_distance = town_a.distance_to_coord(
        other_lat: lat,
        other_lon: lon
      )

      b_distance = town_b.distance_to_coord(
        other_lat: lat,
        other_lon: lon
      )

      a_distance <=> b_distance
    end

    return sorted_towns[0]?
  end

  def additional_info_for(lat : Float32, lon : Float32) : PhotoCoordCacheAdditionalInfo
    closest = closest_town(lat: lat, lon: lon)

    if closest
      closest_town_name = closest.not_nil!.name
      closest_town_distance = CrystalGpx::Point.distance(
        lat1: closest.not_nil!.lat.not_nil!.to_f64,
        lon1: closest.not_nil!.lon.not_nil!.to_f64,
        lat2: lat.not_nil!.to_f64,
        lon2: lon.not_nil!.to_f64
      ).to_f32
    else
      closest_town_name = nil
      closest_town_distance = 0.0.to_f32
    end

    PhotoCoordCacheAdditionalInfo.new(
      closest_town_name: closest_town_name, closest_town_distance: closest_town_distance
    )
  end

  def photo_container_for(lat : Float32, lon : Float32)
    return PhotoCoordCacheContainer.new(
      array: PhotoCoordCacheArray.new,
      info: additional_info_for(lat: lat, lon: lon)
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
