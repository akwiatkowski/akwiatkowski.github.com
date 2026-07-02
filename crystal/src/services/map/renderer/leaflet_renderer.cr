require "json"

class Map::Renderer::LeafletJsonRenderer
  def self.render(result : MapResult) : String
    JSON.build do |json|
      json.object do
        # Map bounds (for fitBounds)
        json.field "bounds" do
          json.array do
            # SW corner
            json.array do
              # Approximate geo bounds from tile info
              json.number result.center_lat - 0.5
              json.number result.center_lon - 0.5
            end
            # NE corner
            json.array do
              json.number result.center_lat + 0.5
              json.number result.center_lon + 0.5
            end
          end
        end

        json.field "zoom", result.zoom
        json.field "center" do
          json.array do
            json.number result.center_lat
            json.number result.center_lon
          end
        end

        # Routes as geo coord arrays
        json.field "routes" do
          json.array do
            result.route_polylines.each do |polyline|
              json.object do
                json.field "color", "rgb(#{polyline.color_rgb})"
                json.field "animated", polyline.animated
                json.field "points" do
                  json.array do
                    # Note: points are in pixel coords. For Leaflet,
                    # we'd need to convert back to geo. For now, pass as-is.
                    polyline.points.each do |p|
                      json.array do
                        json.number p[0]
                        json.number p[1]
                      end
                    end
                  end
                end
              end
            end
          end
        end

        # Photos
        json.field "photos" do
          json.array do
            result.photo_elements.each do |elem|
              json.object do
                case elem
                when DotElement
                  json.field "type", "dot"
                  json.field "x", elem.x
                  json.field "y", elem.y
                  json.field "color", elem.color
                  json.field "photo_url", elem.photo_url
                when GridPhotoElement
                  json.field "type", "grid"
                  json.field "x", elem.x
                  json.field "y", elem.y
                  json.field "image_src", elem.image_src
                  json.field "link_url", elem.link_url
                when AssignedPhotoElement
                  json.field "type", "assigned"
                  json.field "point_x", elem.point_x
                  json.field "point_y", elem.point_y
                  json.field "image_src", elem.image_src
                  json.field "href_url", elem.href_url
                end
              end
            end
          end
        end

        # Tile URL template
        json.field "tile_url", "https://tiles.ump.waw.pl/ump_tiles/{z}/{x}/{y}.png"
      end
    end
  end
end
