class Map::RoutesLayer
  def initialize(
    @posts : Array(Tremolite::Post),
    @tiles_layer : TilesLayer,
    @logger : Logger = Logger.new(STDOUT)
  )
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-routes' >\n"

      @posts.each do |post|
        if post.coords
          if post.coords.not_nil!.size > 0
            # post can have multiple route objects
            post.coords.not_nil!.each do |route_object|
              # append
              s << "<!-- #{post.slug} -->\n"
              s << convert_route_object_to_array_of_svg_lines(route_object)
            end
          end
        end
      end

      s << "</g>"
    end
  end

  def convert_route_object_to_array_of_svg_lines(route_object)
    svg_color =
      allowed_types = {
        "hike"    => "100,250,0",
        "bicycle" => "0,150,250",
        "train"   => "200,100,0",
      }

    return String.build do |s|
      if allowed_types.keys.includes?(route_object["type"])
        # color is determined by type
        color_svg_for_route_object = allowed_types[route_object["type"]]
        geo_coords = route_object["route"].as(Array(Array(Float64)))

        # render only if there 2 or more
        if geo_coords.size >= 2
          s << "<polyline class='photo-map-route' fill='none' style='stroke:rgb(#{color_svg_for_route_object});stroke-width:2' points='"

          # polyline is more optimized solution
          geo_coords.each do |geo_coord|
            lat, lon = geo_coord
            x, y = @tiles_layer.in_map_position_from_geo_coords(
              lat_deg: lat,
              lon_deg: lon
            ).as(Tuple(Int32, Int32))

            # for cropping
            @tiles_layer.mark_top_left_corner(x.to_i, y.to_i)
            @tiles_layer.mark_top_left_corner(x.to_i, y.to_i)

            s << "#{x.to_i},#{y.to_i} "
          end
          s << "'  />\n"
        end
      end
    end
  end
end
