struct CoordRange
  @lat_from : Float64
  @lat_to : Float64
  @lon_from : Float64
  @lon_to : Float64

  @lat_from_set : Bool = false
  @lat_to_set : Bool = false
  @lon_from_set : Bool = false
  @lon_to_set : Bool = false

  getter :lat_from, :lat_to, :lon_from, :lon_to

  def initialize
    @lat_from = 0.0
    @lat_to = 0.0
    @lon_from = 0.0
    @lon_to = 0.0

    @lat_from_set = false
    @lat_to_set = false
    @lon_from_set = false
    @lon_to_set = false
  end

  def initialize(ve : VoivodeshipEntity)
    lats = [ve.border_top_left_lat.not_nil!, ve.border_bottom_right_lat.not_nil!]
    @lat_from = lats.min.as(Float64)
    @lat_to = lats.max.as(Float64)

    lons = [ve.border_top_left_lon.not_nil!, ve.border_bottom_right_lon.not_nil!]
    @lon_from = lons.min.as(Float64)
    @lon_to = lons.max.as(Float64)

    @lat_from_set = true
    @lat_to_set = true
    @lon_from_set = true
    @lon_to_set = true
  end

  def initialize(
    @lat_from,
    @lat_to,
    @lon_from,
    @lon_to
  )
    @lat_from_set = true
    @lat_to_set = true
    @lon_from_set = true
    @lon_to_set = true
  end

  def +(coord_range : CoordRange)
    self.enlarge!(
      [coord_range.lat_from, coord_range.lat_to].min,
      [coord_range.lon_from, coord_range.lon_to].min
    )

    self.enlarge!(
      [coord_range.lat_from, coord_range.lat_to].max,
      [coord_range.lon_from, coord_range.lon_to].max
    )

    return self
  end

  def valid?
    @lat_from_set && @lat_to_set && @lon_from_set && @lon_to_set
  end

  def enlarge!(lat, lon)
    if @lat_from_set
      @lat_from = [lat, @lat_from].min
    else
      @lat_from = lat
      @lat_from_set = true
    end

    if @lon_from_set
      @lon_from = [lon, @lon_from].min
    else
      @lon_from = lon
      @lon_from_set = true
    end

    if @lat_to_set
      @lat_to = [lat, @lat_to].max
    else
      @lat_to = lat
      @lat_to_set = true
    end

    if @lon_to_set
      @lon_to = [lon, @lon_to].max
    else
      @lon_to = lon
      @lon_to_set = true
    end
  end

  def enlarge!(coord_range)
    return self + coord_range
  end

  def to_s
    return String.build do |s|
      if @lat_from_set
        s << "#{@lat_from}"
      else
        s << "---"
      end
      s << ","

      if @lon_from_set
        s << "#{@lon_from}"
      else
        s << "---"
      end

      s << " -> "

      if @lat_to_set
        s << "#{@lat_to}"
      else
        s << "---"
      end
      s << ","

      if @lon_to_set
        s << "#{@lon_to}"
      else
        s << "---"
      end
    end
  end

  def is_within?(lat : Float64, lon : Float64)
    return lat >= @lat_from && lat < @lat_to &&
      lon >= @lon_from && lon < @lon_to
  end

  def overlap_other(other : CoordRange) : Bool
    # not sure if it's working
    return false if self.lat_from < other.lat_to || other.lat_from > self.lat_to
    return false if self.lon_from < other.lon_to || other.lon_from > self.lon_to

    return true
  end
end
