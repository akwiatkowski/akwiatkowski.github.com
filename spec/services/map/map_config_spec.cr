require "../../spec_helper"

describe Map::MapConfig do
  describe ".post_route" do
    it "creates config for post route map" do
      config = Map::MapConfig.post_route(zoom: 10)
      config.type.should eq Map::MapType::PhotoDots
      config.routes_type.should eq Map::MapRoutesType::Static
      config.coord_crop_type.should eq Map::CoordCropType::RouteCrop
      config.photo_link_to.should eq Map::MapPhotoLinkTo::LinkToPhoto
      config.custom_width.should eq 730
    end
  end

  describe ".post_big" do
    it "creates config for post big map" do
      config = Map::MapConfig.post_big(zoom: 12)
      config.type.should eq Map::MapType::PhotosAssignedToRoute
      config.photo_link_to.should eq Map::MapPhotoLinkTo::LinkToPhoto
      config.coord_crop_type.should eq Map::CoordCropType::RouteCrop
      config.zoom.should eq 12
    end
  end

  describe ".global_grid" do
    it "creates config for global grid map" do
      config = Map::MapConfig.global_grid(zoom: 8, photo_size: 160)
      config.type.should eq Map::MapType::PhotoGrid
      config.routes_type.should eq Map::MapRoutesType::None
      config.photo_link_to.should eq Map::MapPhotoLinkTo::LinkToPost
      config.photo_size.should eq 160
    end
  end

  describe ".global_dots" do
    it "creates config for global dots map" do
      config = Map::MapConfig.global_dots(zoom: 8, dot_radius: 10)
      config.type.should eq Map::MapType::PhotoDots
      config.routes_type.should eq Map::MapRoutesType::None
      config.dot_radius.should eq 10
    end
  end

  describe ".global_grid_and_routes" do
    it "creates config with grid and routes" do
      config = Map::MapConfig.global_grid_and_routes(zoom: 10, photo_size: 200)
      config.type.should eq Map::MapType::PhotoGrid
      config.routes_type.should eq Map::MapRoutesType::Static
    end
  end

  describe ".global_animated" do
    it "creates config for animated routes" do
      config = Map::MapConfig.global_animated(zoom: 8)
      config.type.should eq Map::MapType::Blank
      config.routes_type.should eq Map::MapRoutesType::Animated
    end
  end

  describe ".idea_route" do
    it "creates config for idea route with autozoom" do
      config = Map::MapConfig.idea_route(autozoom_width: 700)
      config.type.should eq Map::MapType::Blank
      config.routes_type.should eq Map::MapRoutesType::Static
      config.autozoom_width.should eq 700
    end
  end

  describe ".area_grid" do
    it "creates config for area grid with fixed coord range" do
      range = CoordRange.new(lat_from: 51.0, lat_to: 53.0, lon_from: 16.0, lon_to: 18.0)
      config = Map::MapConfig.area_grid(zoom: 10, photo_size: 100, fixed_coord_range: range)
      config.type.should eq Map::MapType::PhotoGrid
      config.fixed_coord_range.should_not be_nil
    end
  end

  describe ".tag_grid" do
    it "creates config for tagged photo grid" do
      config = Map::MapConfig.tag_grid(zoom: 8, photo_size: 80)
      config.type.should eq Map::MapType::PhotoGrid
      config.photo_link_to.should eq Map::MapPhotoLinkTo::LinkToPhoto
      config.routes_type.should eq Map::MapRoutesType::None
    end
  end

  describe "default constructor" do
    it "creates Blank map with defaults" do
      config = Map::MapConfig.new
      config.type.should eq Map::MapType::Blank
      config.tile.should eq Map::MapTile::Ump
      config.zoom.should eq Map::DEFAULT_ZOOM
    end
  end
end
