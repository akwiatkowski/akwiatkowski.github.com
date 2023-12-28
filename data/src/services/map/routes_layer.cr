class Map::RoutesLayer
  Log = ::Log.for(self)

  def initialize(
    @posts : Array(Tremolite::Post),
    @crop : Map::Crop,
    @tiles_layer : TilesLayer,
    @type : Map::MapRoutesType = Map::MapRoutesType::Static
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

  def animated?
    @type == Map::MapRoutesType::Animated
  end

  def convert_route_object_to_array_of_svg_lines(route_object)
    svg_color =
      allowed_types = {
        "hike"    => "255,100,0",
        "bicycle" => "0,55,230",
        "train"   => "80,80,0",
      }

    return String.build do |s|
      if allowed_types.keys.includes?(route_object.type)
        # color is determined by type
        color_svg_for_route_object = allowed_types[route_object.type]
        geo_coords = route_object.route.as(SingleRouteObject)

        # render only if there 2 or more
        if geo_coords.size >= 2
          s << "<polyline class='photo-map-route' fill='none' "

          # animated svg should have not visible poly lines
          if animated?
            s << "opacity=\"0\" "
          end

          # styles
          if animated?
            # TODO: temporary same style
            s << "style='stroke:rgb(#{color_svg_for_route_object});stroke-width:2' "
          else
            # regular, not so wide line
            s << "style='stroke:rgb(#{color_svg_for_route_object});stroke-width:2' "
          end

          s << " points='"

          # polyline is more optimized solution
          geo_coords.each do |geo_coord|
            lat, lon = geo_coord
            x, y = @tiles_layer.in_map_position_from_geo_coords(
              lat_deg: lat,
              lon_deg: lon
            ).as(Tuple(Int32, Int32))

            @crop.mark_point(x.to_i, y.to_i, :route)

            s << "#{x.to_i},#{y.to_i} "
          end

          if animated?
            # finish polyline tag start
            s << "'>\n"

            @route_number = 0 if @route_number.nil?
            route_id = "route_#{@route_number}"
            previous_route_id = "route_#{@route_number.not_nil! - 1}"

            # add animation tag
            s << "<animate id=\"#{route_id}\" attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" dur=\"0.1s\" fill=\"freeze\" "
            if @route_number.not_nil! > 1
              s << "begin=\"#{previous_route_id}.end\" "
            end
            s << "/>\n"

            @route_number = @route_number.not_nil! + 1

            # finish poly line after animation tag
            s << "</polyline>\n"
          else
            # finish poly line here
            s << "'  />\n"
          end
        end
      end
    end
  end
end
