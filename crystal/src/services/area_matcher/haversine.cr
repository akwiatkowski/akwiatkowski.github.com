module AreaMatcher::Haversine
  EARTH_RADIUS_METERS = 6_371_000.0

  # Calculate distance between two points in meters
  # Input: lat1, lon1, lat2, lon2 (all in degrees)
  def self.distance(lat1 : Float64, lon1 : Float64, lat2 : Float64, lon2 : Float64) : Float64
    lat1_rad = lat1 * Math::PI / 180.0
    lat2_rad = lat2 * Math::PI / 180.0
    delta_lat = (lat2 - lat1) * Math::PI / 180.0
    delta_lon = (lon2 - lon1) * Math::PI / 180.0

    a = Math.sin(delta_lat / 2) ** 2 +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lon / 2) ** 2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    EARTH_RADIUS_METERS * c
  end

  # Calculate total distance of a linestring in meters
  # Input: coords as [[lon, lat], ...] (GEOS order)
  def self.linestring_distance(coords : Array(Array(Float64))) : Float64
    return 0.0 if coords.size < 2

    total = 0.0
    (0...(coords.size - 1)).each do |i|
      # coords are [lon, lat], need to pass as lat, lon
      lon1, lat1 = coords[i]
      lon2, lat2 = coords[i + 1]
      total += distance(lat1, lon1, lat2, lon2)
    end

    total
  end

  # Calculate total distance of multiple linestrings
  def self.multi_linestring_distance(linestrings : Array(Array(Array(Float64)))) : Float64
    linestrings.sum { |ls| linestring_distance(ls) }
  end
end
