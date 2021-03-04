struct TownPhotoResult
  def initialize(
    @photo_entity : PhotoEntity,
    @coord_distance : Float64,
    @days_ago : Int32
  )
    @value = calculate_value.as(Float64)
  end

  getter :value, :photo_entity, :coord_distance, :days_ago

  def to_s
    return "#{@photo_entity.image_filename}: #{@days_ago}days, #{@coord_distance.round(4)}dist => #{distance_ideal_coeff.round(3)} * #{time_coeff.round(3)} * #{published_coeff.round(3)}"
  end

  def distance_ideal_coeff
    return (@coord_distance - TownPhotoCache::SEARCH_PHOTO_TOWN_IDEAL_DISTANCE).abs ** 1.6
  end

  def time_coeff
    # fresh photos are better

    # that was not working because it's better to have 1 year older photo
    # which is closer

    # return @days_ago.to_f ** 0.08

    # TODO temporary disabled because it's harder to do it they way I wanted

    return 1.0
  end

  def published_coeff
    if @photo_entity.is_published
      return TownPhotoCache::SEARCH_PHOTO_TOWN_PUBLISHED_COEFF
    else
      return 1.0
    end
  end

  def calculate_value : Float64
    return distance_ideal_coeff * time_coeff * published_coeff
  end
end

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

  SEARCH_PHOTO_COORD_DISTANCE_TRESHOLD = 0.55
  SEARCH_PHOTO_TOWN_IDEAL_DISTANCE     = 0.04

  SEARCH_PHOTO_TOWN_PUBLISHED_COEFF = 0.2

  DEBUG_TOWNS = [
    "ustronie_morskie",
    "mielno",

    "zabkowice_slaskie",
    "kamiennik",
    "nysa",
  ]
  DEBUG_FLAG = false

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

    # save_cache
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
      lon: town.lon.not_nil!,
      town: town,
    )
  end

  # TODO refactor
  def search_for_town_area(lat : Float64, lon : Float64, town : TownEntity)
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
      results = Array(TownPhotoResult).new
      selected_photos.each do |photo_entity|
        coord_distance = (photo_entity.exif.lat.not_nil! - lat).abs + (photo_entity.exif.lon.not_nil! - lon).abs
        days_ago = (Time.utc - photo_entity.time).days.to_i

        results << TownPhotoResult.new(
          photo_entity: photo_entity,
          days_ago: days_ago,
          coord_distance: coord_distance
        )
      end

      # sort
      results = results.sort do |a, b|
        a.value <=> b.value
      end

      if DEBUG_FLAG
        if DEBUG_TOWNS.includes?(town.slug)
          puts town.slug
          results.each do |r|
            puts r.to_s
          end
          puts ""
        end
      end

      if results.size > 0
        return {
          photo_entity:     results.first.photo_entity,
          coeff:            results.first.value,
          preselected_size: results.size,
        }
      end
    end

    return nil
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
