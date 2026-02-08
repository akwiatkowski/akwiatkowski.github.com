require "../../spec_helper"

describe Map::Crop::RasterCrop do
  describe "#blank?" do
    it "returns true when no points have been added" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.blank?.should be_true
    end

    it "returns false after adding a point" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(100, 200, :test)
      crop.blank?.should be_false
    end
  end

  describe "#mark_point!" do
    it "adds points correctly" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(50, 100, :test)
      crop.mark_point!(150, 200, :test)
      crop.x_min.should eq 50
      crop.x_max.should eq 150
      crop.y_min.should eq 100
      crop.y_max.should eq 200
    end
  end

  describe "#photo" do
    it "adds point when PhotoCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoCrop)
      crop.photo(100, 200)
      crop.blank?.should be_false
    end

    it "adds point when PhotoAndRouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.photo(100, 200)
      crop.blank?.should be_false
    end

    it "does not add point when RouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::RouteCrop)
      crop.photo(100, 200)
      crop.blank?.should be_true
    end
  end

  describe "#route" do
    it "adds point when RouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::RouteCrop)
      crop.route(100, 200)
      crop.blank?.should be_false
    end

    it "adds point when PhotoAndRouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.route(100, 200)
      crop.blank?.should be_false
    end

    it "does not add point when PhotoCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoCrop)
      crop.route(100, 200)
      crop.blank?.should be_true
    end
  end

  describe "#square_photo" do
    it "marks two diagonal corners" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.square_photo(x: 100, y: 150, size: 50)
      crop.x_min.should eq 100
      crop.y_min.should eq 150
      crop.x_max.should eq 150
      crop.y_max.should eq 200
    end
  end

  describe "#assigned_photo_photo" do
    it "marks two corners" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.assigned_photo_photo(x1: 50, y1: 60, x2: 150, y2: 160)
      crop.x_min.should eq 50
      crop.x_max.should eq 150
      # Note: assigned_photo_photo uses y2 for both points
      crop.y_min.should eq 160
      crop.y_max.should eq 160
    end
  end

  describe "#photo_dot" do
    it "marks single point" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.photo_dot(75, 125)
      crop.x_min.should eq 75
      crop.x_max.should eq 75
      crop.y_min.should eq 125
      crop.y_max.should eq 125
    end
  end

  describe "defaults when blank" do
    it "returns 0/400 for x_min/x_max" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.x_min.should eq 0
      crop.x_max.should eq 400
    end

    it "returns 0/300 for y_min/y_max" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.y_min.should eq 0
      crop.y_max.should eq 300
    end
  end

  describe "#crop_x and #crop_y" do
    it "returns min - CROP_PADDING, clamped to 0" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      # Use a wide spread so increase_margin_for_small_maps is a no-op
      crop.mark_point!(200, 200, :test)
      crop.mark_point!(600, 600, :test)
      crop.crop_x.should eq(200 - Map::Crop::RasterCrop::CROP_PADDING)
      crop.crop_y.should eq(200 - Map::Crop::RasterCrop::CROP_PADDING)
    end

    it "clamps to 0 when point is near edge" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(10, 10, :test)
      crop.mark_point!(500, 500, :test)
      crop.crop_x.should eq 0
      crop.crop_y.should eq 0
    end
  end

  describe "#crop_x_max and #crop_y_max" do
    it "returns max + CROP_PADDING, clamped to map dimensions" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      # Wide spread so margin increase doesn't apply
      crop.mark_point!(100, 100, :test)
      crop.mark_point!(600, 600, :test)
      crop.crop_x_max(1000).should eq(600 + Map::Crop::RasterCrop::CROP_PADDING)
      crop.crop_y_max(1000).should eq(600 + Map::Crop::RasterCrop::CROP_PADDING)
    end

    it "clamps to map dimensions when point is near far edge" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(100, 100, :test)
      crop.mark_point!(480, 480, :test)
      crop.crop_x_max(500).should eq 500
      crop.crop_y_max(500).should eq 500
    end
  end

  describe "#cropped_width and #cropped_height" do
    it "returns crop_max - crop_min" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(200, 200, :test)
      crop.mark_point!(400, 400, :test)
      crop.cropped_width(1000).should eq(crop.crop_x_max(1000) - crop.crop_x)
      crop.cropped_height(1000).should eq(crop.crop_y_max(1000) - crop.crop_y)
    end

    it "returns full map dimensions when blank" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.cropped_width(1000).should eq 1000
      crop.cropped_height(800).should eq 800
    end
  end

  describe "#increase_margin_for_small_maps" do
    it "adds margin when axis < MIN_AXIS_RASTER_SIZE" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(400, 400, :test)
      crop.mark_point!(450, 450, :test) # only 50px span
      crop.increase_margin_for_small_maps
      # After margin increase, span should be at least MIN_AXIS_RASTER_SIZE
      crop.uncropped_width.should be >= Map::Crop::RasterCrop::MIN_AXIS_RASTER_SIZE
    end

    it "is idempotent (no-op on second call)" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(400, 400, :test)
      crop.mark_point!(420, 420, :test)
      crop.increase_margin_for_small_maps
      w1 = crop.uncropped_width
      crop.increase_margin_for_small_maps
      crop.uncropped_width.should eq w1
    end

    it "is no-op when content is large enough" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.mark_point!(100, 100, :test)
      crop.mark_point!(600, 600, :test) # 500px span, > MIN_AXIS_RASTER_SIZE
      original_width = crop.uncropped_width
      crop.increase_margin_for_small_maps
      crop.uncropped_width.should eq original_width
    end
  end

  describe "#photo_can_enlarge?" do
    it "returns true for PhotoCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoCrop)
      crop.photo_can_enlarge?.should be_true
    end

    it "returns true for PhotoAndRouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.photo_can_enlarge?.should be_true
    end

    it "returns false for RouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::RouteCrop)
      crop.photo_can_enlarge?.should be_false
    end
  end

  describe "#route_can_enlarge?" do
    it "returns true for RouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::RouteCrop)
      crop.route_can_enlarge?.should be_true
    end

    it "returns true for PhotoAndRouteCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoAndRouteCrop)
      crop.route_can_enlarge?.should be_true
    end

    it "returns false for PhotoCrop" do
      crop = Map::Crop::RasterCrop.new(type: Map::CoordCropType::PhotoCrop)
      crop.route_can_enlarge?.should be_false
    end
  end
end
