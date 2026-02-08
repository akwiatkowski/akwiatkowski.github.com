module Map::PhotoSelection
  def select_photos_for_area(
    photos : Array(PhotoEntity),
    lat_min : Float64,
    lat_max : Float64,
    lon_min : Float64,
    lon_max : Float64,
  ) : Array(PhotoEntity)
    photos.select do |photo|
      next false if photo.exif.not_nil!.lat.nil? || photo.exif.not_nil!.lon.nil?

      photo_lat = photo.exif.not_nil!.lat.not_nil!
      photo_lon = photo.exif.not_nil!.lon.not_nil!

      photo_lat >= lat_min &&
        photo_lat < lat_max &&
        photo_lon >= lon_min &&
        photo_lon < lon_max
    end
  end

  def select_suitable_photo(array : Array(PhotoEntity)) : (PhotoEntity | Nil)
    return nil if array.size == 0

    selected = array.select { |photo| photo.is_map }
    if selected.size == 0
      selected = array.select { |photo| photo.is_timeline }
    end
    if selected.size == 0
      selected = array
    end

    # sort by time ASC and return latest
    selected = selected.sort { |a, b| a.time <=> b.time }
    return selected.last
  end

  # Seasonal color based on day of year (used by DotsLayer)
  def self.day_of_year_to_color(day_of_year : Int32) : String
    phase = (day_of_year.to_f / 365.to_f) * 2.0 * Math::PI

    blue = 255.0 * ((Math.cos(phase) + 1.0) / 2.0)
    green = 255.0 * ((Math.sin(phase) + 1.0) / 2.0)
    red = 0.0
    if day_of_year >= 150 && day_of_year < 350
      red_phase = ((day_of_year - 150).to_f / (350.0 - 150.0)) * Math::PI
      red = 255.0 * (Math.sin(red_phase))
    end

    blue = blue.clamp(0.0, 255.0)
    green = green.clamp(0.0, 255.0)
    red = red.clamp(0.0, 255.0)

    "rgb(#{red.to_i},#{green.to_i},#{blue.to_i})"
  end
end
