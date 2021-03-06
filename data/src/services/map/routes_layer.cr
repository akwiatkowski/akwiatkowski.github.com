class Map::RoutesLayer
  Log = ::Log.for(self)

  def initialize(
    @posts : Array(Tremolite::Post),
    @tiles_layer : TilesLayer
  )
  end

  def render_svg
    Log.debug { "#{self.class} #{@posts.size} @posts" }
    return String.build do |s|
      s << "<g id='photo-map-routes' >\n"

      @posts.each do |post|
        routes = post.detailed_routes
        Log.debug { "#{routes.size} routes in #{post.slug}" }
        if routes.size > 0
          # post can have multiple route objects
          post.detailed_routes.each do |route_object|
            # append
            s << "<!-- #{post.slug} -->\n"
            s << convert_route_object_to_array_of_svg_lines(route_object)
          end
        end
      end

      s << "</g>"
      Log.debug { "svg done" }
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
      if allowed_types.keys.includes?(route_object.type)
        # color is determined by type
        color_svg_for_route_object = allowed_types[route_object.type]
        geo_coords = route_object.route.as(SingleRouteObject)

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
            @tiles_layer.mark_bottom_right_corner(x.to_i, y.to_i)

            s << "#{x.to_i},#{y.to_i} "
          end
          s << "'  />\n"
        end
      end
    end
  end
end
