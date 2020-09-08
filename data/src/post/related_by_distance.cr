class Tremolite::Post
  def related_coords : Array(Tuple(Float64, Float64))
    cs = Array(Tuple(Float64, Float64)).new

    @pois.not_nil!.each do |p|
      cs << {p.lat, p.lon}
    end

    @coords.not_nil!.each do |ce|
      ce.route.each do |c|
        cs << {c[0], c[1]}
      end
    end

    return cs
  end

  def closest_to_point(lat : Float64, lon : Float64)
    cs = related_coords
    cs = cs.sort { |a, b|
      da = (a[0] - lat) ** 2 + (a[1] - lon) ** 2
      db = (b[0] - lat) ** 2 + (b[1] - lon) ** 2
      da <=> db
    }

    if cs.size > 0
      return cs.last
    else
      return nil
    end
  end

  def closest_distance_to_point(lat : Float64, lon : Float64)
    p = closest_to_point(lat: lat, lon: lon)
    if p
      cp = CrystalGpx::Point.new(lat: p[0], lon: p[1])
      d = cp.distance_to(other_lat: lat, other_lon: lon)
      return d
    else
      return nil
    end
  end
end
