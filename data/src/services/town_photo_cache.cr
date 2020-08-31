class TownPhotoCache
  Log = ::Log.for(self)

  alias TownPhotoCacheData = NamedTuple(
    photo_path: String,
    coeff: Float64,
    post_slug: String,
    preselected_size: Int32)
  alias TownPhotoCacheStructure = Hash(String, TownPhotoCacheData)

  def initialize(@blog : Tremolite::Blog)
    @cache_path = Tremolite::DataManager::CACHE_PATH
    @cache_file_path = File.join([@cache_path, "town_photos.yml"])
    @cache = TownPhotoCacheStructure.new
    load_cache
  end

  SEARCH_PHOTO_COORD_DISTANCE_TRESHOLD = 0.65
  SEARCH_PHOTO_TOWN_IDEAL_DISTANCE     = 0.14

  SEARCH_PHOTO_TOWN_PUBLISHED_COEFF = 0.12
  SEARCH_PHOTO_TOWN_TIMELINE_COEFF  =  0.3
  SEARCH_PHOTO_TOWN_MAP_COEFF       = 0.55

  getter :cache_file_path

  def refresh
    @blog.data_manager.towns.not_nil!.each do |town|
      if town.lat && town.lon
        closest_photo_tuple = search_best_photo_for_town(town)

        if closest_photo_tuple
          closest_photo = closest_photo_tuple.not_nil![:photo_entity]
          closest_coeff = closest_photo_tuple.not_nil![:coeff]
          preselected_size = closest_photo_tuple.not_nil![:preselected_size]

          @cache[town.slug] = TownPhotoCacheData.new(
            photo_path: closest_photo.not_nil!.full_image_src,
            post_slug: closest_photo.not_nil!.post_slug,
            coeff: closest_coeff,
            preselected_size: preselected_size,
          )
        end
      end
    end

    save_cache
  end

  def get_cache_structure(slug_name : String)
    return @cache[slug_name]?
  end

  def get_photo_path_for_town(slug_name : String)
    data = get_cache_structure(slug_name)
    if data
      return data[:photo_path]?
    else
      return nil
    end
  end

  private def search_best_photo_for_town(town)
    return search_for_town_area(
      lat: town.lat.not_nil!,
      lon: town.lon.not_nil!
    )
  end

  def search_for_town_area(lat : Float64, lon : Float64)
    # select SEARCH_PHOTO_COORD_DISTANCE_TRESHOLD photos and only horizontal
    selected_photos = exif_db.all_flatten_photo_entities.select do |photo_entity|
      if photo_entity.exif.lat && photo_entity.exif.lon
        # only check with coords
        distance = (photo_entity.exif.lat.not_nil! - lat).abs + (photo_entity.exif.lon.not_nil! - lon).abs
        distance_bool = (distance < SEARCH_PHOTO_COORD_DISTANCE_TRESHOLD)
        horizontal_bool = photo_entity.exif.is_horizontal?

        select_bool = distance_bool && horizontal_bool

        select_bool
      else
        false
      end
    end

    if selected_photos.size > 0
      valued_photos = Hash(PhotoEntity, Float64).new

      selected_photos.each do |photo_entity|
        distance = (photo_entity.exif.lat.not_nil! - lat).abs + (photo_entity.exif.lon.not_nil! - lon).abs
        distance_ideal_coeff = (distance - SEARCH_PHOTO_TOWN_IDEAL_DISTANCE).abs

        # fresh photos are better
        time_coeff = (Time.utc - photo_entity.time).days.to_f

        # combine two coefficient
        total_coeff = distance_ideal_coeff * time_coeff

        # if photo is published -> reduce coeff
        total_coeff *= SEARCH_PHOTO_TOWN_PUBLISHED_COEFF if photo_entity.is_published

        # if photo is timeline -> reduce coeff
        total_coeff *= SEARCH_PHOTO_TOWN_TIMELINE_COEFF if photo_entity.is_timeline

        # if photo is timeline -> reduce coeff
        total_coeff *= SEARCH_PHOTO_TOWN_MAP_COEFF if photo_entity.is_map

        valued_photos[photo_entity] = total_coeff

        # Log.debug { "calculated photo_value #{total_coeff} = #{photo_entity.full_image_src}" }
      end

      # convert to array, sort, return best
      selected_photo_entity = valued_photos.to_a.sort do |a, b|
        a[1] <=> b[1]
      end[0]

      return {
        photo_entity:     selected_photo_entity[0],
        coeff:            selected_photo_entity[1],
        preselected_size: selected_photos.size,
      }
    else
      return nil
    end
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
      Log.debug { "loading cache" }
      @cache = TownPhotoCacheStructure.from_yaml(File.open(cache_file_path))
    end
  end
end
