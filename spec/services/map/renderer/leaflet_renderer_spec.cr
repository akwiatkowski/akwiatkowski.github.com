require "json"
require "../../../spec_helper"

describe Map::Renderer::LeafletJsonRenderer do
  it "produces valid JSON" do
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
    json_str = Map::Renderer::LeafletJsonRenderer.render(result)
    parsed = JSON.parse(json_str)
    parsed.should_not be_nil
  end

  it "contains bounds, zoom, and center" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: Array(Map::PhotoElement).new,
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.23,
      center_lon: 21.01,
      zoom: 10,
    )
    parsed = JSON.parse(Map::Renderer::LeafletJsonRenderer.render(result))
    parsed["zoom"].as_i.should eq 10
    parsed["center"][0].as_f.should be_close(52.23, 0.01)
    parsed["center"][1].as_f.should be_close(21.01, 0.01)
    parsed["bounds"].as_a.size.should eq 2
  end

  it "contains routes array with points and colors" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: [
        Map::RoutePolyline.new(
          points: [{100, 200}, {150, 250}],
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
    parsed = JSON.parse(Map::Renderer::LeafletJsonRenderer.render(result))
    routes = parsed["routes"].as_a
    routes.size.should eq 1
    routes[0]["color"].as_s.should contain("255,0,0")
    routes[0]["points"].as_a.size.should eq 2
  end

  it "contains photos array with type" do
    result = Map::MapResult.new(
      tiles: Array(Map::TileInfo).new,
      tile_source: Map::MapTile::Ump,
      route_polylines: Array(Map::RoutePolyline).new,
      photo_elements: [
        Map::DotElement.new(x: 100, y: 200, color: "rgb(255,0,0)", photo_url: "/photo.jpg").as(Map::PhotoElement),
      ],
      view_box: Map::ViewBox.new(x: 0, y: 0, width: 500, height: 400),
      map_width: 500,
      map_height: 400,
      center_lat: 52.0,
      center_lon: 20.0,
      zoom: 10,
    )
    parsed = JSON.parse(Map::Renderer::LeafletJsonRenderer.render(result))
    photos = parsed["photos"].as_a
    photos.size.should eq 1
    photos[0]["type"].as_s.should eq "dot"
    photos[0]["photo_url"].as_s.should eq "/photo.jpg"
  end
end
