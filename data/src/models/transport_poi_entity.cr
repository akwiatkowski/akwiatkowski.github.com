require "crystal_gpx"

class TransportPoiEntity
  HOME_LAT   = 52.40285
  HOME_LON   = 16.91062
  HOME_POINT = CrystalGpx::Point.new(lat: HOME_LAT, lon: HOME_LON)

  MAX_DISTANCE_TO_MAJOR = 30.0

  @commune_slug : String
  @name : String
  @time_cost : (Int32 | Nil) # minutes

  @lat : Float64
  @lon : Float64

  @major : Bool

  # closest major
  @closest_major_name : (String | Nil)
  @closest_major_lat : (Float64 | Nil)
  @closest_major_lon : (Float64 | Nil)
  @closest_major_time_cost : (Int32 | Nil)

  @closest_major_line_distance_from_home : (Float64 | Nil)
  @closest_major_direction_from_home : (Float64 | Nil)
  @closest_major_direction_from_home_human : (String | Nil)

  getter :commune_slug, :name, :time_cost, :lat, :lon
  getter :major
  getter :line_distance_from_home, :direction_from_home, :direction_from_home_human

  getter :closest_major_name, :closest_major_lat, :closest_major_lon, :closest_major_time_cost
  getter :closest_major_line_distance_from_home, :closest_major_direction_from_home, :closest_major_direction_from_home_human

  def initialize(y : YAML::Any)
    @commune_slug = y["commune_slug"].to_s
    @name = y["name"].to_s
    @time_cost = y["time_cost"].to_s.to_i if y["time_cost"]?
    # some locations are without train station
    @no_train = false
    @no_train = true if y["no_train"]?

    @lat = y["lat"].to_s.to_f
    @lon = y["lon"].to_s.to_f

    @line_distance_from_home = HOME_POINT.distance_to(other_lat: @lat, other_lon: @lon).as(Float64)
    @direction_from_home = HOME_POINT.direction_to(other_lat: @lat, other_lon: @lon).as(Float64)
    @direction_from_home_human = CrystalGpx::Point.direction_to_human(@direction_from_home)

    @major = false
    @major = true if y["major"]?
  end

  def with_train?
    false == @time_cost.nil? && false == @no_train
  end

  def url
    "/town/#{@commune_slug}"
  end

  def distance_to(other : TransportPoiEntity)
    return CrystalGpx::Point.distance(
      lat1: self.lat,
      lon1: self.lon,
      lat2: other.lat,
      lon2: other.lon
    )
  end

  def assign_closest_major(transport_pois : Array(TransportPoiEntity))
    close_majors = transport_pois.select { |m| self.distance_to(m) < MAX_DISTANCE_TO_MAJOR }

    majors = close_majors.select(&.major).sort { |a, b|
      self.distance_to(a) <=> self.distance_to(b)
    }

    if majors.size > 0
      closest_major = majors.first

      @closest_major_name = closest_major.name
      @closest_major_lat = closest_major.lat
      @closest_major_lon = closest_major.lon
      @closest_major_time_cost = closest_major.time_cost

      @closest_major_line_distance_from_home = HOME_POINT.distance_to(other_lat: @lat, other_lon: @lon).as(Float64)
      @closest_major_direction_from_home = HOME_POINT.direction_to(other_lat: @lat, other_lon: @lon).as(Float64)
      @closest_major_direction_from_home_human = CrystalGpx::Point.direction_to_human(@direction_from_home)
    end
  end
end
