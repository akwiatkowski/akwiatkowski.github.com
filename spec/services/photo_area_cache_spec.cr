require "../spec_helper"
require "file_utils"

private def make_temp_cache(entries : Hash(String, String)) : String
  tmp_dir = File.tempname("photo_cache_test")
  Dir.mkdir_p(tmp_dir)

  entries.each do |relative_path, content|
    full_path = File.join(tmp_dir, relative_path)
    Dir.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  tmp_dir
end

describe PhotoAreaCache do
  describe "#photos_for_area" do
    it "returns empty array for missing cache file" do
      cache_dir = make_temp_cache({} of String => String)

      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)
      area = AreaEntity.new(
        slug: "nonexistent",
        name: "Nonexistent",
        area_type: AreaType::Town,
      )

      result = cache.photos_for_area(area)
      result.should be_empty

      FileUtils.rm_rf(cache_dir)
    end

    it "returns empty array for empty cache file" do
      cache_dir = make_temp_cache({
        "towns/test-town.yml" => "--- []\n",
      })

      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)
      area = AreaEntity.new(
        slug: "test-town",
        name: "Test Town",
        area_type: AreaType::Town,
      )

      result = cache.photos_for_area(area)
      result.should be_empty

      FileUtils.rm_rf(cache_dir)
    end

    it "skips entries not found in lookup" do
      yaml_content = <<-YAML
      ---
      - filename: DSC_1234.jpg
        post_slug: 2021-07-18-pagorki
      - filename: DSC_5678.jpg
        post_slug: 2021-07-24-w-trakcie
      YAML

      cache_dir = make_temp_cache({
        "towns/pobiedziska.yml" => yaml_content,
      })

      # Empty lookup means all entries are skipped
      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)
      area = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town,
      )

      result = cache.photos_for_area(area)
      result.should be_empty

      FileUtils.rm_rf(cache_dir)
    end

    it "uses correct subdirectory for each area type" do
      yaml_content = "--- []\n"

      cache_dir = make_temp_cache({
        "towns/a.yml"         => yaml_content,
        "counties/b.yml"      => yaml_content,
        "voivodeships/c.yml"  => yaml_content,
        "meso_regions/d.yml"  => yaml_content,
        "macro_regions/e.yml" => yaml_content,
      })

      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)

      [
        {AreaType::Town, "a"},
        {AreaType::County, "b"},
        {AreaType::Voivodeship, "c"},
        {AreaType::MesoRegion, "d"},
        {AreaType::MacroRegion, "e"},
      ].each do |area_type, slug|
        area = AreaEntity.new(slug: slug, name: slug, area_type: area_type)
        cache.photos_for_area(area).should be_empty
      end

      FileUtils.rm_rf(cache_dir)
    end
  end

  describe "#top_photos_for_area" do
    it "returns empty array for missing cache" do
      cache_dir = make_temp_cache({} of String => String)

      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)
      area = AreaEntity.new(slug: "x", name: "X", area_type: AreaType::Town)

      result = cache.top_photos_for_area(area, 10)
      result.should be_empty

      FileUtils.rm_rf(cache_dir)
    end
  end

  describe "#available?" do
    it "returns true when cache directory exists" do
      cache_dir = make_temp_cache({} of String => String)
      cache = PhotoAreaCache.new(cache_dir, {} of String => PhotoEntity)
      cache.available?.should be_true
      FileUtils.rm_rf(cache_dir)
    end

    it "returns false when cache directory doesn't exist" do
      cache = PhotoAreaCache.new("/nonexistent/path/photo_cache_test", {} of String => PhotoEntity)
      cache.available?.should be_false
    end
  end
end
