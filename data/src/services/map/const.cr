module Map
  enum MapType
    Ump
    Osm
  end

  TILE_WIDTH   = 256
  DEFAULT_ZOOM =  10
  # size of photo in pixels
  DEFAULT_PHOTO_SIZE = 200
  DEFAULT_VOIVODESHIP_PHOTO_SIZE = 90

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
