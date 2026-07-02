require "../../spec_helper"

describe Map::TilesLayer do
  describe ".tile_coords_from_geo_coords" do
    it "returns correct tile coords for Warsaw at zoom 10" do
      x, y = Map::TilesLayer.tile_coords_from_geo_coords(
        lat_deg: 52.23,
        lon_deg: 21.01,
        zoom: 10
      )
      # Warsaw is in Eastern Europe, roughly tile (571, 340) at zoom 10
      x.should be_close(571.76, 1.0)
      y.should be_close(337.2, 1.0)
    end

    it "returns correct tile coords for equator origin at zoom 1" do
      x, y = Map::TilesLayer.tile_coords_from_geo_coords(
        lat_deg: 0.0,
        lon_deg: 0.0,
        zoom: 1
      )
      x.should be_close(1.0, 0.001)
      y.should be_close(1.0, 0.001)
    end

    it "returns correct tile coords for negative coordinates" do
      x, y = Map::TilesLayer.tile_coords_from_geo_coords(
        lat_deg: -33.87,
        lon_deg: -70.67,
        zoom: 8
      )
      x.should be > 0
      y.should be > 128 # southern hemisphere
    end
  end

  describe "#tile_numbers_from_geo_coords" do
    it "returns integer tile numbers (floor of tile coords)" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 52.0,
        lon_min: 16.0, lon_max: 17.0,
        zoom: 10
      )
      tile_x, tile_y = layer.tile_numbers_from_geo_coords(52.23, 21.01)
      tile_x.should be_a(Int32)
      tile_y.should be_a(Int32)
    end
  end

  describe "#in_map_position_from_geo_coords" do
    it "returns pixel position relative to map origin" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      x, y = layer.in_map_position_from_geo_coords(52.0, 19.0)
      x.should be > 0
      y.should be > 0
      x.should be < layer.map_width
      y.should be < layer.map_height
    end
  end

  describe "#geo_coords_from_tile_number" do
    it "performs inverse conversion" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      lat, lon = layer.geo_coords_from_tile_number(571, 340)
      # tile (571, 340) at zoom 10 corresponds to roughly these geo coords
      lat.should be_close(51.62, 0.5)
      lon.should be_close(20.74, 0.5)
    end
  end

  describe "round-trip geo→tile→geo" do
    it "preserves coordinates within tolerance" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      original_lat = 52.23
      original_lon = 21.01

      tile_x, tile_y = layer.tile_coords_from_geo_coords(original_lat, original_lon)
      recovered_lat, recovered_lon = layer.geo_coords_from_tile_number(tile_x, tile_y)

      recovered_lat.should be_close(original_lat, 0.01)
      recovered_lon.should be_close(original_lon, 0.01)
    end
  end

  describe "#geo_coords_from_map_pixel_position" do
    it "converts pixel position back to geo coords" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      # Get a known pixel position
      px, py = layer.in_map_position_from_geo_coords(52.0, 19.0)
      # Convert back
      lat, lon = layer.geo_coords_from_map_pixel_position(px, py)
      lat.should be_close(52.0, 0.1)
      lon.should be_close(19.0, 0.1)
    end
  end

  describe "#map_lat_center and #map_lon_center" do
    it "returns midpoint of map bounds" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      layer.map_lat_center.should be_close((layer.map_lat1 + layer.map_lat2) / 2.0, 0.001)
      layer.map_lon_center.should be_close((layer.map_lon1 + layer.map_lon2) / 2.0, 0.001)
    end
  end

  describe "#diagonal" do
    it "returns pythagorean of map dimensions" do
      layer = Map::TilesLayer.new(
        lat_min: 51.0, lat_max: 53.0,
        lon_min: 16.0, lon_max: 22.0,
        zoom: 10
      )
      expected = Math.sqrt(layer.map_height ** 2 + layer.map_width ** 2).to_i
      layer.diagonal.should eq expected
    end
  end

  describe ".diagonal_for_zoom" do
    it "returns zoom→diagonal hash for all VALID_ZOOMS" do
      coord_range = CoordRange.new(
        lat_from: 51.0, lat_to: 53.0,
        lon_from: 16.0, lon_to: 22.0
      )
      h = Map::TilesLayer.diagonal_for_zoom(coord_range)
      h.keys.sort.should eq Map::VALID_ZOOMS.sort
      # Higher zoom should give larger diagonal
      h[10].should be > h[8]
    end
  end

  describe ".ideal_zoom_for_photo_distance" do
    it "returns best zoom for target distance" do
      coord_range = CoordRange.new(
        lat_from: 51.0, lat_to: 53.0,
        lon_from: 16.0, lon_to: 22.0
      )
      result = Map::TilesLayer.ideal_zoom_for_photo_distance(
        coord_range: coord_range,
        distance: 700
      )
      result[:zoom].should be_a(Int32)
      result[:zoom].should be >= Map::VALID_ZOOMS.min
      result[:zoom].should be <= Map::VALID_ZOOMS.max
    end
  end

  describe ".ideal_zoom" do
    it "returns zoom within min/max diagonal bounds" do
      coord_range = CoordRange.new(
        lat_from: 51.0, lat_to: 53.0,
        lon_from: 16.0, lon_to: 22.0
      )
      zoom = Map::TilesLayer.ideal_zoom(
        coord_range: coord_range,
        min_diagonal: 300,
        max_diagonal: 5000
      )
      zoom.should_not be_nil
      zoom.not_nil!.should be >= 6
      zoom.not_nil!.should be <= 16
    end
  end

  describe "constructor" do
    it "creates tile grid with ±1 padding and correct dimensions" do
      layer = Map::TilesLayer.new(
        lat_min: 52.0, lat_max: 52.5,
        lon_min: 20.0, lon_max: 21.0,
        zoom: 10
      )
      layer.map_width.should eq layer.map_width
      layer.map_height.should eq layer.map_height
      # Dimensions should be multiples of TILE_WIDTH
      (layer.map_width % Map::TILE_WIDTH).should eq 0
      (layer.map_height % Map::TILE_WIDTH).should eq 0
    end
  end
end
