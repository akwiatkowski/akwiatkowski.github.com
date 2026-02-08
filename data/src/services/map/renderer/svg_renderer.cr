class Map::Renderer::SvgRenderer
  def self.render(result : MapResult) : String
    # Build inner SVG content
    inner_svg = String.build do |s|
      render_tiles(s, result)
      render_photo_elements(s, result)
      render_routes(s, result)
    end

    String.build do |s|
      cropped_width = result.view_box.width
      cropped_height = result.view_box.height
      crop_x = result.view_box.x
      crop_y = result.view_box.y

      width = result.custom_width || cropped_width
      aspect_ratio = cropped_width.to_f / cropped_height.to_f
      new_height = (width.to_f / aspect_ratio).to_i

      # Debug comment block
      s << "<!--\n"
      result.debug.each do |k, v|
        s << "#{k}: #{v}\n"
      end
      s << "zoom: #{result.zoom}\n"
      s << "tiles: width=#{result.map_width}, height=#{result.map_height}\n"
      s << "view_box: #{crop_x} #{crop_y} #{cropped_width} #{cropped_height}\n"
      s << "-->\n"

      # Wrapper for autoscaling
      s << "<svg preserveAspectRatio='xMinYMin meet' viewBox='0 0 #{width} #{new_height}' "
      s << "xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>\n"

      render_defs(s)
      render_style(s)

      # Inner viewport with viewBox crop
      s << "<svg width='#{width}' height='#{new_height}' "
      s << "viewBox='#{crop_x} #{crop_y} #{cropped_width} #{cropped_height}' "
      s << "class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' >\n"

      s << inner_svg

      s << "</svg>\n"

      # License
      render_licence(s, result, width, new_height)

      s << "</svg>\n"
    end
  end

  private def self.render_defs(s : IO)
    s << "<defs>\n"
    s << "  <filter id=\"photo-shadow\" x=\"-5%\" y=\"-5%\" width=\"115%\" height=\"115%\">\n"
    s << "    <feDropShadow dx=\"1\" dy=\"1\" stdDeviation=\"2\" flood-color=\"rgba(0,0,0,0.25)\" />\n"
    s << "  </filter>\n"
    s << "  <filter id=\"route-glow\" x=\"-15%\" y=\"-15%\" width=\"130%\" height=\"130%\">\n"
    s << "    <feGaussianBlur in=\"SourceGraphic\" stdDeviation=\"3\" />\n"
    s << "  </filter>\n"
    s << "</defs>\n"
  end

  private def self.render_style(s : IO)
    s << "<style>\n"
    s << "  .photo-map-photo { filter: url(#photo-shadow); }\n"
    s << "  .photo-map-route { stroke-linecap: round; stroke-linejoin: round; }\n"
    s << "  .photo-pointer { fill: none; stroke: rgba(0,0,0,0.4); stroke-width: 1; }\n"
    s << "  .photo-dot { stroke: rgba(0,0,0,0.5); stroke-width: 0.5; }\n"
    s << "  .route-point { fill: white; stroke: rgba(0,0,0,0.4); stroke-width: 1.5; }\n"
    s << "  .photo-border { fill: none; stroke: rgba(255,255,255,0.7); stroke-width: 1; }\n"
    s << "  .licence-text { font-family: sans-serif; font-size: 11px; fill: rgba(0,0,0,0.45); text-anchor: end; }\n"
    s << "</style>\n"
  end

  private def self.render_tiles(s : IO, result : MapResult)
    s << "<g id='photo-map-tiles' >\n"
    result.tiles.each do |tile|
      s << "<image href='#{tile.url}' x='#{tile.pixel_x}' y='#{tile.pixel_y}' class='photo-map-tile' />\n"
    end
    s << "</g>\n"
  end

  private def self.render_photo_elements(s : IO, result : MapResult)
    return if result.photo_elements.empty?

    # For assigned photos, render pointer lines first (z-index ordering)
    has_assigned = result.photo_elements.any? { |e| e.is_a?(AssignedPhotoElement) }

    if has_assigned
      s << "<g id='photo-map-to-route-photos' >\n"

      # Pointer lines first
      result.photo_elements.each do |elem|
        if elem.is_a?(AssignedPhotoElement)
          path_d = SmoothPath.pointer_path(elem.center_x, elem.center_y, elem.point_x, elem.point_y)
          s << "<path class='photo-pointer' d='#{path_d}' />\n"
          s << "<circle cx='#{elem.point_x}' cy='#{elem.point_y}' r='4' class='route-point' />\n"
        end
      end

      # Then images
      result.photo_elements.each do |elem|
        if elem.is_a?(AssignedPhotoElement)
          s << "<svg x='#{elem.corner_x}' y='#{elem.corner_y}' width='#{elem.image_size}' height='#{elem.image_size}' class='photo-map-photo'>\n"
          s << "<a href='#{elem.href_url}' target='_blank'>\n"
          s << "<image href='#{elem.image_src}' preserveAspectRatio='xMidYMid slice' width='#{elem.image_size}' height='#{elem.image_size}' />\n"
          s << "</a>\n"
          s << "</svg>\n"
        end
      end

      s << "</g>\n"
    else
      s << "<g id='photo-map-photos' >\n"

      result.photo_elements.each do |elem|
        case elem
        when GridPhotoElement
          s << "<svg x='#{elem.x}' y='#{elem.y}' width='#{elem.size}' height='#{elem.size}' class='photo-map-photo'>\n"
          s << "<a href='#{elem.link_url}' target='_blank'>\n"
          s << "<image href='#{elem.image_src}' preserveAspectRatio='xMidYMid slice' width='#{elem.size}' height='#{elem.size}' />\n"
          s << "</a>\n"
          s << "<rect width='#{elem.size}' height='#{elem.size}' class='photo-border' />\n"
          s << "</svg>\n"
        when DotElement
          circle_size = 8
          s << "<a href='#{elem.photo_url}' target='_blank'>\n"
          s << "  <rect x=\"#{elem.x - (circle_size / 2)}\" y=\"#{elem.y - (circle_size / 2)}\" width=\"#{circle_size}\" height=\"#{circle_size}\" rx=\"3\" fill='#{elem.color}' class='photo-dot' />\n"
          s << "</a>\n"
        end
      end

      s << "</g>\n"
    end
  end

  private def self.render_routes(s : IO, result : MapResult)
    return if result.route_polylines.empty?

    s << "<g id='photo-map-routes' >\n"

    route_number = 0
    result.route_polylines.each do |polyline|
      path_d = SmoothPath.to_path(polyline.points)

      if polyline.animated
        # Animated: single path with opacity animation (no glow)
        s << "<path class='photo-map-route' fill='none' "
        s << "opacity=\"0\" "
        s << "stroke='rgb(#{polyline.color_rgb})' stroke-width='2' "
        s << "d='#{path_d}'>\n"

        route_id = "route_#{route_number}"
        previous_route_id = "route_#{route_number - 1}"
        s << "<animate id=\"#{route_id}\" attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" dur=\"0.1s\" fill=\"freeze\" "
        if route_number > 1
          s << "begin=\"#{previous_route_id}.end\" "
        end
        s << "/>\n"
        route_number += 1
        s << "</path>\n"
      else
        # Static: glow path behind, then sharp path
        s << "<path fill='none' stroke='rgb(#{polyline.color_rgb})' stroke-width='6' opacity='0.25' filter='url(#route-glow)' d='#{path_d}' />\n"
        s << "<path class='photo-map-route' fill='none' stroke='rgb(#{polyline.color_rgb})' stroke-width='2' d='#{path_d}' />\n"
      end
    end

    s << "</g>"
  end

  private def self.render_licence(s : IO, result : MapResult, svg_width : Int32, svg_height : Int32)
    if result.tile_source == MapTile::Ump
      text_x = svg_width - 8
      text_y = svg_height - 8
      s << "\n"
      s << "<a href='https://mapa.ump.waw.pl/ump-www/?zoom=#{result.zoom}&amp;lat=#{result.center_lat}&amp;lon=#{result.center_lon}' target='_blank'>\n"
      s << "<text x='#{text_x}' y='#{text_y}' class='licence-text'>mapa z UMP-pcPL</text>\n"
      s << "</a>\n"
    end
  end
end
