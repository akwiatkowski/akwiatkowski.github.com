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

  def initialize(
    @lat_from,
    @lat_to,
    @lon_from,
    @lon_to,
  )
  end

  def +(coord_range : CoordRange)
    return self.class.new(
      lat_from: [lat_from, coord_range.lat_from].min,
      lon_from: [lon_from, coord_range.lon_from].min,
      lat_to: [lat_to, coord_range.lat_to].max,
      lon_to: [lon_to, coord_range.lon_to].max,
    )
  end

  def is_within?(lat : Float64, lon : Float64)
    return lat >= @lat_from && lat < @lat_to &&
      lon >= @lon_from && lon < @lon_to
  end
end
