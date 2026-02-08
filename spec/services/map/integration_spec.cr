require "../../spec_helper"

# Integration tests that run the full pipeline with minimal data
# and verify SVG output structure
describe "Map Pipeline Integration" do
  describe "blank map (routes only)" do
    it "produces SVG with tiles and no photo elements" do
      config = Map::MapConfig.new(
        type: Map::MapType::Blank,
        routes_type: Map::MapRoutesType::None,
        zoom: 8,
      )
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute

      result.tiles.size.should be > 0
      result.photo_elements.size.should eq 0
      result.route_polylines.size.should eq 0

      svg = Map::Renderer::SvgRenderer.render(result)
      svg.should contain("<svg")
      svg.should contain("photo-map-tiles")
      svg.scan(/<image href/).size.should be > 0
    end
  end

  describe "pipeline produces valid ViewBox" do
    it "viewBox has positive dimensions" do
      config = Map::MapConfig.new(zoom: 10)
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute

      result.view_box.width.should be > 0
      result.view_box.height.should be > 0
      result.map_width.should be > 0
      result.map_height.should be > 0
    end
  end

  describe "autozoom" do
    it "auto-selects zoom within valid range" do
      config = Map::MapConfig.new(
        autozoom_width: 700,
        zoom: 9,
      )
      # Need some route data to have a coord range
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute

      result.zoom.should be >= Map::VALID_ZOOMS.min
      result.zoom.should be <= Map::VALID_ZOOMS.max
    end
  end

  describe "custom_width" do
    it "passes custom_width to MapResult" do
      config = Map::MapConfig.new(custom_width: 730)
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute

      result.custom_width.should eq 730

      svg = Map::Renderer::SvgRenderer.render(result)
      svg.should contain("viewBox='0 0 730")
    end
  end

  describe "SVG renderer output format" do
    it "has outer and inner SVG elements with correct structure" do
      config = Map::MapConfig.new(zoom: 8)
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute
      svg = Map::Renderer::SvgRenderer.render(result)

      # Should have exactly 2 top-level SVG opens before tile content
      svg.should contain("preserveAspectRatio='xMinYMin meet'")
      svg.should contain("class='photo-map-tiles'")
    end
  end

  describe "LeafletJsonRenderer" do
    it "produces valid JSON with required fields" do
      config = Map::MapConfig.new(zoom: 10)
      context = Map::MapContext.new
      pipeline = Map::MapPipeline.new(config: config, context: context)
      result = pipeline.compute

      json_str = Map::Renderer::LeafletJsonRenderer.render(result)
      parsed = JSON.parse(json_str)
      parsed["zoom"].as_i.should eq 10
      parsed["center"].as_a.size.should eq 2
      parsed["bounds"].as_a.size.should eq 2
      parsed["routes"].as_a.should be_a(JSON::Any::Type)
      parsed["photos"].as_a.should be_a(JSON::Any::Type)
      parsed["tile_url"].as_s.should contain("tiles")
    end
  end

  describe "MapResult data structures" do
    it "TileInfo stores pixel position and URL" do
      tile = Map::TileInfo.new(pixel_x: 256, pixel_y: 512, url: "/tiles/ump/10/571/337.png")
      tile.pixel_x.should eq 256
      tile.pixel_y.should eq 512
      tile.url.should contain("571")
    end

    it "RoutePolyline stores points and color" do
      polyline = Map::RoutePolyline.new(
        points: [{100, 200}, {150, 250}],
        color_rgb: "255,0,0"
      )
      polyline.points.size.should eq 2
      polyline.color_rgb.should eq "255,0,0"
      polyline.animated.should be_false
    end

    it "DotElement stores position and color" do
      dot = Map::DotElement.new(x: 50, y: 100, color: "rgb(255,0,0)", photo_url: "/photo.jpg")
      dot.x.should eq 50
      dot.y.should eq 100
    end

    it "GridPhotoElement stores grid cell info" do
      grid = Map::GridPhotoElement.new(x: 0, y: 0, size: 200, image_src: "/img.jpg", link_url: "/post.html")
      grid.size.should eq 200
    end

    it "AssignedPhotoElement stores point and corner positions" do
      assigned = Map::AssignedPhotoElement.new(
        point_x: 100, point_y: 200,
        corner_x: 50, corner_y: 150,
        center_x: 75, center_y: 175,
        image_size: 120,
        image_src: "/img.jpg",
        href_url: "/photo.jpg"
      )
      assigned.point_x.should eq 100
      assigned.corner_x.should eq 50
      assigned.image_size.should eq 120
    end
  end
end
