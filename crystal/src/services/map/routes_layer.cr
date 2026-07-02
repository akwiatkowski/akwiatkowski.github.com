class Map::RoutesLayer
  Log = ::Log.for(self)

  def initialize(
    @posts : Array(Tremolite::Post),
    @routes : Array(PostRouteObject),
    @raster_crop : Map::Crop::RasterCrop,
    @tiles_layer : TilesLayer,
    @route_colors : RouteColors,
    @type : Map::MapRoutesType = Map::MapRoutesType::Static,
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

      @routes.each_with_index do |route_object, i|
        # append
        s << "<!-- route: #{i} -->\n"
        s << convert_route_object_to_array_of_svg_lines(route_object)
      end

      s << "</g>"
      Log.debug { "svg done" }
    end
  end

  def animated?
    @type == Map::MapRoutesType::Animated
  end

  def convert_route_object_to_array_of_svg_lines(route_object)
    return String.build do |s|
      if @route_colors.has_type?(route_object.type)
        color_svg_for_route_object = @route_colors.color_rgb_for(route_object.type)
        geo_coords = route_object.route.as(SingleRouteObject)

        if geo_coords.size >= 2
          # Collect pixel points and register them for cropping
          points = Array(Tuple(Int32, Int32)).new
          geo_coords.each do |geo_coord|
            lat, lon = geo_coord
            x, y = @tiles_layer.in_map_position_from_geo_coords(
              lat_deg: lat,
              lon_deg: lon
            ).as(Tuple(Int32, Int32))
            @raster_crop.route(x.to_i, y.to_i)
            points << {x.to_i, y.to_i}
          end

          path_d = Map::SmoothPath.to_path(points)

          if animated?
            # Animated: single path with opacity animation (no glow)
            s << "<path class='photo-map-route' fill='none' "
            s << "opacity=\"0\" "
            s << "stroke='rgb(#{color_svg_for_route_object})' stroke-width='2' "
            s << "d='#{path_d}'>\n"

            @route_number = 0 if @route_number.nil?
            route_id = "route_#{@route_number}"
            previous_route_id = "route_#{@route_number.not_nil! - 1}"

            s << "<animate id=\"#{route_id}\" attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" dur=\"0.1s\" fill=\"freeze\" "
            if @route_number.not_nil! > 1
              s << "begin=\"#{previous_route_id}.end\" "
            end
            s << "/>\n"

            @route_number = @route_number.not_nil! + 1
            s << "</path>\n"
          else
            # Static: glow path behind, then sharp path
            s << "<path fill='none' stroke='rgb(#{color_svg_for_route_object})' stroke-width='6' opacity='0.25' filter='url(#route-glow)' d='#{path_d}' />\n"
            s << "<path class='photo-map-route' fill='none' stroke='rgb(#{color_svg_for_route_object})' stroke-width='2' d='#{path_d}' />\n"
          end
        end
      end
    end
  end
end
