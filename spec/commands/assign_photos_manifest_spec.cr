require "../spec_helper"
require "file_utils"
require "log"
require "../../crystal/src/service/area_matcher/all"
require "../../crystal/src/commands/pipeline/assign_photos_to_areas"

# Test manifest and cache I/O without loading GEOS
describe Commands::Pipeline::AssignPhotosToAreas do
  describe "#read_manifest" do
    it "returns empty set for missing file" do
      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_manifest("/nonexistent/path/manifest.txt")
      result.should be_empty
      result.should be_a Set(String)
    end

    it "reads photo IDs from manifest file" do
      path = File.tempname("manifest_test", ".txt")
      File.write(path, "2021-07-18-pagorki/DSC_1234.jpg\n2021-07-24-w-trakcie/DSC_5678.jpg\n")

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_manifest(path)
      result.size.should eq 2
      result.includes?("2021-07-18-pagorki/DSC_1234.jpg").should be_true
      result.includes?("2021-07-24-w-trakcie/DSC_5678.jpg").should be_true

      File.delete(path)
    end

    it "ignores empty lines in manifest" do
      path = File.tempname("manifest_test", ".txt")
      File.write(path, "photo1/a.jpg\n\nphoto2/b.jpg\n\n")

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_manifest(path)
      result.size.should eq 2

      File.delete(path)
    end
  end

  describe "#read_cache_file" do
    it "reads entries from YAML cache file" do
      path = File.tempname("cache_test", ".yml")
      yaml_content = <<-YAML
      ---
      - filename: DSC_1234.jpg
        post_slug: 2021-07-18-pagorki
      - filename: DSC_5678.jpg
        post_slug: 2021-07-24-w-trakcie
      YAML
      File.write(path, yaml_content)

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_cache_file(path)
      result.size.should eq 2
      result[0].should eq({"DSC_1234.jpg", "2021-07-18-pagorki"})
      result[1].should eq({"DSC_5678.jpg", "2021-07-24-w-trakcie"})

      File.delete(path)
    end

    it "returns empty array for empty YAML cache" do
      path = File.tempname("cache_test", ".yml")
      File.write(path, "--- []\n")

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_cache_file(path)
      result.should be_empty

      File.delete(path)
    end

    it "skips entries with missing fields" do
      path = File.tempname("cache_test", ".yml")
      yaml_content = <<-YAML
      ---
      - filename: DSC_1234.jpg
      - post_slug: 2021-07-18-pagorki
      - filename: DSC_5678.jpg
        post_slug: 2021-07-24-w-trakcie
      YAML
      File.write(path, yaml_content)

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      result = cmd.read_cache_file(path)
      result.size.should eq 1
      result[0].should eq({"DSC_5678.jpg", "2021-07-24-w-trakcie"})

      File.delete(path)
    end
  end

  describe "#write_cache_file" do
    it "writes entries as YAML" do
      path = File.tempname("cache_test", ".yml")
      entries = [
        {"DSC_1234.jpg", "2021-07-18-pagorki"},
        {"DSC_5678.jpg", "2021-07-24-w-trakcie"},
      ]

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      cmd.write_cache_file(path, entries)

      # Read back and verify
      result = cmd.read_cache_file(path)
      result.size.should eq 2
      result[0].should eq({"DSC_1234.jpg", "2021-07-18-pagorki"})
      result[1].should eq({"DSC_5678.jpg", "2021-07-24-w-trakcie"})

      File.delete(path)
    end

    it "writes empty array as valid YAML" do
      path = File.tempname("cache_test", ".yml")
      entries = [] of {String, String}

      cmd = Commands::Pipeline::AssignPhotosToAreas.allocate
      cmd.write_cache_file(path, entries)

      result = cmd.read_cache_file(path)
      result.should be_empty

      File.delete(path)
    end
  end

  describe "AREA_TYPES" do
    it "contains all 5 area types" do
      Commands::Pipeline::AssignPhotosToAreas::AREA_TYPES.size.should eq 5
    end

    it "matches AreaType directory names" do
      expected = ["towns", "counties", "voivodeships", "meso_regions", "macro_regions"]
      Commands::Pipeline::AssignPhotosToAreas::AREA_TYPES.should eq expected
    end
  end
end
