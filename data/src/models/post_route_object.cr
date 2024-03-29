require "./coord_range"
require "./coord_set"

alias SingleRouteObject = Array(Array(Float64))

struct PostRouteObject
  include JSON::Serializable

  Log = ::Log.for(self)

  @type : String
  @route : SingleRouteObject

  getter :type, :route

  def initialize(hash : YAML::Any)
    @type = hash["type"].to_s

    @route = Array(Array(Float64)).new

    hash["route"].as_a.each do |coord|
      if coord.size == 2
        @route << [coord[0].to_s.to_f, coord[1].to_s.to_f]
      end
    end
  end

  def initialize(@type : String, @route : SingleRouteObject)
  end

  def to_coord_range : CoordRange?
    # NOTE maybe I should require at least 2 route coords?
    return nil if route.size <= 1

    lat_from = route[0][0].as(Float64)
    lon_from = route[0][1].as(Float64)
    lat_to = lat_from
    lon_to = lon_from

    self.route.each do |ro|
      lat = ro[0].as(Float64)
      lon = ro[1].as(Float64)

      lat_from = [lat_from, lat].min
      lat_to = [lat_to, lat].max

      lon_from = [lon_from, lon].min
      lon_to = [lon_to, lon].max
    end

    return CoordRange.new(
      lat_from: lat_from,
      lon_from: lon_from,
      lat_to: lat_to,
      lon_to: lon_to,
    )
  end

  def self.array_to_coord_range(
    array : Array(PostRouteObject),
    only_types : Array(String) = Array(String).new
  ) : CoordRange?
    filtered_array = array

    # if `only_types` provided filter only selected types
    if only_types.size > 0
      filtered_array = filtered_array.select do |pro|
        only_types.includes?(pro.type)
      end
    end

    # if empty return nil
    return nil if filtered_array.size == 0

    # blank one
    coord_range = CoordRange.new

    filtered_array.each do |pro|
      # operator override
      new_coord_range = pro.to_coord_range

      if new_coord_range.is_a?(CoordRange)
        coord_range += new_coord_range.as(CoordRange)
      end
    end

    return coord_range.as(CoordRange)
  end
end
