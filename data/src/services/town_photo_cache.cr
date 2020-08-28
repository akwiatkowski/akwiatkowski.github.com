class TownPhotoCache
  Log = ::Log.for(self)

  alias TownPhotoCacheStructure = Hash(String, String)

  def initialize(@blog : Tremolite::Blog)
    @cache_path = Tremolite::DataManager::CACHE_PATH
    @cache_file_path = File.join([@cache_path, "town_photos.yml"])
    @cache = TownPhotoCacheStructure.new
    load_cache
  end

  getter :cache_file_path

  def refresh
    @blog.data_manager.towns.not_nil!.each do |town|
      if town.lat && town.lon
        closest_photo = search_best_photo_for_town(town)

        if closest_photo
          @cache[town.slug] = closest_photo.not_nil!.full_image_src
        end
      end
    end

    save_cache
  end

  def get(slug_name : String)
    return @cache[slug_name]?
  end

  private def search_best_photo_for_town(town)
    return exif_db.search_in_coord(
      lat: town.lat.not_nil!,
      lon: town.lon.not_nil!
    )
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
