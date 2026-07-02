module Map::SmoothPath
  # Convert polyline points to a smooth SVG path using Catmull-Rom splines.
  # Each input point is visited exactly; tension is implicit (1/6 factor).
  # Returns SVG path `d` attribute string: "M x,y C ..."
  def self.to_path(points : Array(Tuple(Int32, Int32))) : String
    return "" if points.empty?
    return "M #{points[0][0]},#{points[0][1]}" if points.size == 1

    String.build do |s|
      s << "M #{points[0][0]},#{points[0][1]}"

      if points.size == 2
        # Straight line for 2 points
        s << " L #{points[1][0]},#{points[1][1]}"
      else
        # Catmull-Rom to cubic bezier for each segment P[i] -> P[i+1]
        (0...points.size - 1).each do |i|
          p0 = i > 0 ? points[i - 1] : points[i]
          p1 = points[i]
          p2 = points[i + 1]
          p3 = i + 2 < points.size ? points[i + 2] : points[i + 1]

          # Control points: CP1 = P1 + (P2 - P0) / 6, CP2 = P2 - (P3 - P1) / 6
          cp1x = p1[0] + (p2[0] - p0[0]) / 6.0
          cp1y = p1[1] + (p2[1] - p0[1]) / 6.0
          cp2x = p2[0] - (p3[0] - p1[0]) / 6.0
          cp2y = p2[1] - (p3[1] - p1[1]) / 6.0

          s << " C #{cp1x.round.to_i},#{cp1y.round.to_i}"
          s << " #{cp2x.round.to_i},#{cp2y.round.to_i}"
          s << " #{p2[0]},#{p2[1]}"
        end
      end
    end
  end

  # Quadratic bezier arc between two points.
  # Control point offset perpendicular to line, magnitude ~15% of distance.
  # Returns: "M fx,fy Q cx,cy tx,ty"
  def self.pointer_path(from_x : Int32, from_y : Int32, to_x : Int32, to_y : Int32) : String
    dx = (to_x - from_x).to_f
    dy = (to_y - from_y).to_f
    mid_x = (from_x + to_x) / 2.0
    mid_y = (from_y + to_y) / 2.0

    # Perpendicular offset: rotate (dx, dy) by 90 degrees, scale to 15%
    ctrl_x = (mid_x + dy * 0.15).round.to_i
    ctrl_y = (mid_y - dx * 0.15).round.to_i

    "M #{from_x},#{from_y} Q #{ctrl_x},#{ctrl_y} #{to_x},#{to_y}"
  end
end
