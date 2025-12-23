require "json"

struct TrainStationEntity
  include YAML::Serializable
  include JSON::Serializable

  Log = ::Log.for(self)

  @name : String
  @time_distance : Float64
  @lat : Float64
  @lon : Float64

  getter :name, :time_distance, :lat, :lon

  def initialize(y : YAML::Any)
    @name = y["name"].as_s
    @time_distance = y["time_distance"].as_f
    @lat = y["lat"].as_f
    @lon = y["lon"].as_f
  end

  # def view_url
  #   "/stacja_kolejowa/#{slug}.html"
  # end

  def direction_to_other_train_station(other : TrainStationEntity)
    return CrystalGpx::Point.direction(
      lat1: lat,
      lon1: lon,
      lat2: other.lat,
      lon2: other.lon
    )

    # TODO: check if crystal_gpx calculate correctly
    # lat1 = lat1_deg * Math::PI / 180.0
    # lon1 = lon1_deg * Math::PI / 180.0
    # lat2 = lat2_deg * Math::PI / 180.0
    # lon2 = lon2_deg * Math::PI / 180.0
    #
    # delta_lon = lon2 - lon1
    # y = Math.sin(delta_lon) * Math.cos(lat2)
    # x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(delta_lon)
    #
    # bearing_rad = Math.atan2(y, x)
    # ((bearing_rad * 180.0 / Math::PI) + 360.0) % 360.0
  end
end
