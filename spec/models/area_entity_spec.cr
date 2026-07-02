require "../spec_helper"

describe AreaEntity do
  describe "#lat and #lon" do
    it "returns center coordinates from bbox" do
      area = AreaEntity.new(
        slug: "test-town",
        name: "Test Town",
        area_type: AreaType::Town,
        bbox: AreaMatcher::BBox.new(south: 52.0, north: 52.2, west: 16.8, east: 17.0)
      )

      area.lat.should eq(52.1)
      area.lon.should eq(16.9)
    end

    it "returns nil when no bbox" do
      area = AreaEntity.new(
        slug: "no-bbox",
        name: "No BBox",
        area_type: AreaType::Town
      )

      area.lat.should be_nil
      area.lon.should be_nil
    end
  end
end

describe PhotoCoordQuantCache do
  describe ".closest_town" do
    it "returns the nearest town by coordinates" do
      towns = [
        AreaEntity.new(slug: "far", name: "Far Town", area_type: AreaType::Town,
          bbox: AreaMatcher::BBox.new(south: 54.0, north: 54.2, west: 18.0, east: 18.2)),
        AreaEntity.new(slug: "close", name: "Close Town", area_type: AreaType::Town,
          bbox: AreaMatcher::BBox.new(south: 52.0, north: 52.2, west: 16.8, east: 17.0)),
      ]

      result = PhotoCoordQuantCache.closest_town(52.15_f32, 16.95_f32, towns)
      result.should_not be_nil
      result.not_nil!.slug.should eq("close")
    end

    it "returns nil when no towns have coordinates" do
      towns = [
        AreaEntity.new(slug: "no-bbox", name: "No BBox", area_type: AreaType::Town),
      ]

      result = PhotoCoordQuantCache.closest_town(52.0_f32, 17.0_f32, towns)
      result.should be_nil
    end

    it "returns nil for empty array" do
      result = PhotoCoordQuantCache.closest_town(52.0_f32, 17.0_f32, [] of AreaEntity)
      result.should be_nil
    end

    it "skips towns without bbox" do
      towns = [
        AreaEntity.new(slug: "no-bbox", name: "No BBox", area_type: AreaType::Town),
        AreaEntity.new(slug: "has-bbox", name: "Has BBox", area_type: AreaType::Town,
          bbox: AreaMatcher::BBox.new(south: 52.0, north: 52.2, west: 16.8, east: 17.0)),
      ]

      result = PhotoCoordQuantCache.closest_town(52.15_f32, 16.95_f32, towns)
      result.not_nil!.slug.should eq("has-bbox")
    end
  end
end

describe Tremolite::Validator do
  describe ".find_missing_towns" do
    it "returns no errors when all towns are known" do
      known_slugs = ["poznan", "gniezno", "wielkopolskie"]
      post_data = [
        {["poznan", "gniezno"], true, "2024-01-01-trip"},
      ]

      results = Tremolite::Validator.find_missing_towns(known_slugs, post_data)
      results[:errors].should be_empty
      results[:warnings].should be_empty
    end

    it "returns errors for unknown towns in self-propelled posts" do
      known_slugs = ["poznan"]
      post_data = [
        {["poznan", "unknown-town"], true, "2024-01-01-trip"},
      ]

      results = Tremolite::Validator.find_missing_towns(known_slugs, post_data)
      results[:errors].size.should eq(1)
      results[:errors].first.should contain("unknown-town")
      results[:warnings].should be_empty
    end

    it "returns warnings for unknown towns in non-self-propelled posts" do
      known_slugs = ["poznan"]
      post_data = [
        {["poznan", "unknown-town"], false, "2024-01-01-train"},
      ]

      results = Tremolite::Validator.find_missing_towns(known_slugs, post_data)
      results[:errors].should be_empty
      results[:warnings].size.should eq(1)
      results[:warnings].first.should contain("unknown-town")
    end

    it "handles posts with no town slugs" do
      known_slugs = ["poznan"]
      post_data = [
        {[] of String, true, "2024-01-01-trip"},
      ]

      results = Tremolite::Validator.find_missing_towns(known_slugs, post_data)
      results[:errors].should be_empty
      results[:warnings].should be_empty
    end

    it "handles empty known slugs" do
      known_slugs = [] of String
      post_data = [
        {["poznan"], true, "2024-01-01-trip"},
      ]

      results = Tremolite::Validator.find_missing_towns(known_slugs, post_data)
      results[:errors].size.should eq(1)
    end
  end
end
