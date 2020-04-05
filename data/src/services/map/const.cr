module Map
  enum MapType
    Ump
    Osm
  end

  TILE_WIDTH   = 256
  DEFAULT_ZOOM =  10
  DEFAULT_SMALL_ZOOM = 9
  DEFAULT_PHOTO_SIZE = 200

  DEFAULT_OVERALL_ZOOM = 10
  DEFAULT_OVERALL_PHOTO_SIZE = 200

  # TODO maybe dowload 11 later?
  DEFAULT_DETAILED_ZOOM = 10
  DEFAULT_DETAILED_PHOTO_SIZE = 80

  DEFAULT_SMALL_ZOOM = 8
  DEFAULT_SMALL_PHOTO_SIZE = 100

  DEFAULT_VOIVODESHIP_ZOOM = 10
  DEFAULT_VOIVODESHIP_PHOTO_SIZE = 100

  DEFAULT_VOIVODESHIP_SMALL_ZOOM = 9
  DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE = 80

  struct CoordRange
    @lat_from : Float64
    @lat_to : Float64
    @lon_from : Float64
    @lon_to : Float64

    property :lat_from, :lat_to, :lon_from, :lon_to

    def initialize(ve : VoivodeshipEntity)
      puts ve.inspect

      lats = [ve.border_top_left_lat.not_nil!, ve.border_bottom_right_lat.not_nil!]
      @lat_from = lats.min
      @lat_to = lats.max

      lons = [ve.border_top_left_lon.not_nil!, ve.border_bottom_right_lon.not_nil!]
      @lon_from = lons.min
      @lon_to = lons.max
    end

    def is_within?(lat : Float64, lon : Float64)
      return lat >= @lat_from && lat < @lat_to &&
        lon >= @lon_from && lon < @lon_to
    end
  end
end
