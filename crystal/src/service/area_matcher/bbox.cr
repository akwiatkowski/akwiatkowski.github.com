# Bounding box structure
struct AreaMatcher::BBox
  property south : Float64
  property north : Float64
  property west : Float64
  property east : Float64

  def initialize(@south, @north, @west, @east)
  end

  def overlaps?(other : BBox) : Bool
    west <= other.east && east >= other.west &&
      south <= other.north && north >= other.south
  end

  def intersection_area(other : BBox) : Float64
    w = Math.max(west, other.west)
    e = Math.min(east, other.east)
    s = Math.max(south, other.south)
    n = Math.min(north, other.north)
    return 0.0 if e <= w || n <= s
    (e - w) * (n - s)
  end

  def area : Float64
    (east - west) * (north - south)
  end

  def center : {Float64, Float64}
    {(north + south) / 2, (east + west) / 2} # {lat, lon}
  end
end
