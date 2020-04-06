module Map
  class NotEnoughPhotos < Exception
  end

  enum MapType
    Ump
    Osm
  end

  TILE_WIDTH   = 256
  DEFAULT_ZOOM =  10
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

  DEFAULT_POST_ZOOM = 14
  DEFAULT_POST_PHOTO_SIZE = 120

  struct CoordRange
    @lat_from : Float64
    @lat_to : Float64
    @lon_from : Float64
    @lon_to : Float64

    property :lat_from, :lat_to, :lon_from, :lon_to

    def initialize(ve : VoivodeshipEntity)
      lats = [ve.border_top_left_lat.not_nil!, ve.border_bottom_right_lat.not_nil!]
      @lat_from = lats.min
      @lat_to = lats.max

      lons = [ve.border_top_left_lon.not_nil!, ve.border_bottom_right_lon.not_nil!]
      @lon_from = lons.min
      @lon_to = lons.max
    end

    def initialize(apro : Array(PostRouteObject))
      # [{"route": [[50.29740,16.87356], [50.26888,16.88094], [50.26317,16.87613], [50.25011,16.85055], [50.20849,16.83193]], "type": "hike"}]
      initial_coords = apro[0]["route"][0]

      @lat_from = initial_coords.as(Array(Float64))[0].as(Float64)
      @lon_from = initial_coords.as(Array(Float64))[1].as(Float64)
      @lat_to = @lat_from
      @lon_to = @lon_from

      apro.each do |pro|
        pro["route"].as(Array(Array(Float64))).each do |ro|
          lat = ro[0].as(Float64)
          lon = ro[1].as(Float64)

          @lat_from = [@lat_from, lat].min
          @lat_to = [@lat_from, lat].max

          @lon_from = [@lon_from, lon].min
          @lon_to = [@lon_from, lon].max
        end
      end
    end

    def is_within?(lat : Float64, lon : Float64)
      return lat >= @lat_from && lat < @lat_to &&
        lon >= @lon_from && lon < @lon_to
    end
  end
end
