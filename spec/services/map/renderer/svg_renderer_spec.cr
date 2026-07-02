require "../../../spec_helper"

describe Map::Renderer::SvgRenderer do
  it "produces valid SVG (starts with <svg, contains xmlns)" do
    result = Map::MapResult.new(
      tiles: [Map::TileInfo.new(pixel_x: 0, pixel_y: 0, url: "/tiles/ump/10/571/337.png")],
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<svg")
    svg.should contain("xmlns='http://www.w3.org/2000/svg'")
    svg.should contain("</svg>")
  end

  it "contains SVG defs with filters" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<defs>")
    svg.should contain("photo-shadow")
    svg.should contain("route-glow")
    svg.should contain("</defs>")
  end

  it "contains SVG style block" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<style>")
    svg.should contain(".photo-map-route")
    svg.should contain(".photo-dot")
    svg.should contain("</style>")
  end

  it "contains debug comment block" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<!--")
    svg.should contain("-->")
    svg.should contain("zoom: 10")
  end

  it "contains license text for UMP tiles" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("mapa z UMP-pcPL")
    svg.should contain("licence-text")
    svg.should contain("text-anchor: end")
  end

  it "renders tile images" do
    result = Map::MapResult.new(
      tiles: [
        Map::TileInfo.new(pixel_x: 0, pixel_y: 0, url: "/tiles/ump/10/571/337.png"),
        Map::TileInfo.new(pixel_x: 256, pixel_y: 0, url: "/tiles/ump/10/572/337.png"),
      ],
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 512, height: 256),
      map_width: 512,
      map_height: 256,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.scan(/<image href/).size.should eq 2
  end

  it "renders route as smooth path with glow" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: [
        Map::RoutePolyline.new(
          points: [{100, 200}, {150, 250}, {200, 300}],
          color_rgb: "255,0,0"
        ),
      ],
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<path")
    svg.should contain("255,0,0")
    svg.should contain("route-glow")
    svg.should contain("photo-map-route")
    svg.should_not contain("<polyline")
  end

  it "renders dot photo elements with class instead of inline style" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: [
        Map::DotElement.new(x: 100, y: 200, color: "rgb(255,0,0)", photo_url: "/photos/test.jpg").as(Map::PhotoElement),
      ],
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<rect")
    svg.should contain("rgb(255,0,0)")
    svg.should contain("class='photo-dot'")
    svg.should_not contain("stroke-width:1")
  end

  it "renders grid photo elements with border" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: [
        Map::GridPhotoElement.new(x: 0, y: 0, size: 200, image_src: "/img/photo.jpg", link_url: "/post.html").as(Map::PhotoElement),
      ],
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("photo-map-photo")
    svg.should contain("/img/photo.jpg")
    svg.should contain("/post.html")
    svg.should contain("class='photo-border'")
  end

  it "renders assigned photo elements with curved pointers" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: [
        Map::AssignedPhotoElement.new(
          point_x: 100, point_y: 200,
          corner_x: 50, corner_y: 150,
          center_x: 75, center_y: 175,
          image_size: 120,
          image_src: "/img.jpg",
          href_url: "/photo.jpg"
        ).as(Map::PhotoElement),
      ],
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<path class='photo-pointer'")
    svg.should contain("class='route-point'")
    svg.should contain("r='4'")
    svg.should_not contain("<polyline")
  end

  it "renders animated routes with <animate> tags" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: [
        Map::RoutePolyline.new(
          points: [{100, 200}, {150, 250}],
          color_rgb: "0,0,255",
          animated: true
        ),
        Map::RoutePolyline.new(
          points: [{200, 300}, {250, 350}],
          color_rgb: "0,255,0",
          animated: true
        ),
      ],
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    svg = Map::Renderer::SvgRenderer.render(result)
    svg.should contain("<animate")
    svg.should contain("route_0")
    svg.should contain("route_1")
    svg.should contain("opacity=\"0\"")
  end
end
