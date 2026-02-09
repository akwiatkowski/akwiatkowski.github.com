require "../spec_helper"

describe PhotoCoordQuantCache do
  describe "#initialize" do
    it "creates with empty cache when no cache file exists" do
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")
      cache.cache.should be_empty
    end
  end

  describe "#key_for_coord" do
    it "quantizes coordinates to QUANT resolution" do
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")

      key = cache.key_for_coord(lat: 52.15_f32, lon: 16.93_f32)
      # QUANT = 0.2, so 52.15 rounds to 52.2, 16.93 rounds to 16.8 or 17.0
      key[:lat].should eq(CoordQuant.round(value: 52.15_f32, quant: 0.2))
      key[:lon].should eq(CoordQuant.round(value: 16.93_f32, quant: 0.2))
    end

    it "produces same key for nearby coordinates" do
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")

      key1 = cache.key_for_coord(lat: 52.05_f32, lon: 16.85_f32)
      key2 = cache.key_for_coord(lat: 52.09_f32, lon: 16.89_f32)
      key1.should eq(key2)
    end

    it "produces different keys for distant coordinates" do
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")

      key1 = cache.key_for_coord(lat: 52.0_f32, lon: 16.8_f32)
      key2 = cache.key_for_coord(lat: 53.0_f32, lon: 18.0_f32)
      key1.should_not eq(key2)
    end
  end

  describe "#additional_info_for" do
    it "returns closest town name and distance" do
      towns = [
        AreaEntity.new(slug: "poznan", name: "Poznań", area_type: AreaType::Town,
          bbox: AreaMatcher::BBox.new(south: 52.3, north: 52.5, west: 16.8, east: 17.0)),
      ]
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir", all_towns: towns)

      info = cache.additional_info_for(lat: 52.4_f32, lon: 16.9_f32)
      info[:closest_town_name].should eq("Poznań")
      info[:closest_town_distance].should be > 0.0_f32
    end

    it "returns nil name when no towns available" do
      cache = PhotoCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")

      info = cache.additional_info_for(lat: 52.0_f32, lon: 17.0_f32)
      info[:closest_town_name].should be_nil
      info[:closest_town_distance].should eq(0.0_f32)
    end
  end
end
