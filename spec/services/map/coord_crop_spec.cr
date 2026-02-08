require "../../spec_helper"

describe Map::Crop::CoordCrop do
  describe "#coord_range with fixed_coord_range" do
    it "uses fixed_coord_range when provided, ignoring additions" do
      fixed = CoordRange.new(
        lat_from: 51.0, lat_to: 52.0,
        lon_from: 16.0, lon_to: 17.0
      )
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoAndRouteCrop,
        fixed_coord_range: fixed
      )
      # Adding photos should not change the coord_range
      crop.photo(53.0, 20.0)
      range = crop.coord_range
      range.lat_to.should be <= 52.1
      range.lon_to.should be <= 17.1
    end
  end

  describe "#photo" do
    it "expands range when PhotoCrop" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoCrop,
        fixed_coord_range: nil
      )
      crop.photo(52.0, 20.0)
      crop.photo(53.0, 21.0)
      range = crop.coord_range
      # Should cover both points
      range.lat_from.should be <= 52.0
      range.lat_to.should be >= 53.0
    end

    it "expands range when PhotoAndRouteCrop" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoAndRouteCrop,
        fixed_coord_range: nil
      )
      crop.photo(52.0, 20.0)
      crop.photo(53.0, 21.0)
      range = crop.coord_range
      range.lat_from.should be <= 52.0
      range.lat_to.should be >= 53.0
    end

    it "does not expand range when RouteCrop" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::RouteCrop,
        fixed_coord_range: nil
      )
      crop.photo(52.0, 20.0)
      crop.photo_can_enlarge?.should be_false
    end
  end

  describe "#route" do
    it "expands range when RouteCrop" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::RouteCrop,
        fixed_coord_range: nil
      )
      crop.route(52.0, 20.0)
      crop.route(53.0, 21.0)
      range = crop.coord_range
      range.lat_from.should be <= 52.0
      range.lat_to.should be >= 53.0
    end

    it "does not expand range when PhotoCrop" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoCrop,
        fixed_coord_range: nil
      )
      crop.route(52.0, 20.0)
      crop.route_can_enlarge?.should be_false
    end
  end

  describe "#coord_range returns limit_to_poland" do
    it "clamps values to Poland bounds" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoAndRouteCrop,
        fixed_coord_range: nil
      )
      crop.photo(52.0, 20.0)
      range = crop.coord_range
      # Poland bounds are roughly 48.5-54.9 lat, 14-24 lon
      range.lat_from.should be >= 48.0
      range.lon_from.should be >= 13.0
    end
  end

  describe "PhotoAndRouteCrop" do
    it "allows both photo and route to expand range" do
      crop = Map::Crop::CoordCrop.new(
        type: Map::CoordCropType::PhotoAndRouteCrop,
        fixed_coord_range: nil
      )
      crop.photo(52.0, 20.0)
      crop.route(53.0, 21.0)
      range = crop.coord_range
      range.lat_from.should be <= 52.0
      range.lat_to.should be >= 53.0
      range.lon_from.should be <= 20.0
      range.lon_to.should be >= 21.0
    end
  end

  describe "#photo_can_enlarge?" do
    it "returns true for PhotoCrop" do
      crop = Map::Crop::CoordCrop.new(type: Map::CoordCropType::PhotoCrop, fixed_coord_range: nil)
      crop.photo_can_enlarge?.should be_true
    end

    it "returns false for RouteCrop" do
      crop = Map::Crop::CoordCrop.new(type: Map::CoordCropType::RouteCrop, fixed_coord_range: nil)
      crop.photo_can_enlarge?.should be_false
    end
  end

  describe "#route_can_enlarge?" do
    it "returns true for RouteCrop" do
      crop = Map::Crop::CoordCrop.new(type: Map::CoordCropType::RouteCrop, fixed_coord_range: nil)
      crop.route_can_enlarge?.should be_true
    end

    it "returns false for PhotoCrop" do
      crop = Map::Crop::CoordCrop.new(type: Map::CoordCropType::PhotoCrop, fixed_coord_range: nil)
      crop.route_can_enlarge?.should be_false
    end
  end
end
