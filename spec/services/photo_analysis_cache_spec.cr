require "../spec_helper"
require "file_utils"

describe PhotoAnalysisCache do
  describe "#initialize" do
    it "creates with empty state" do
      cache = PhotoAnalysisCache.new(
        cache_path: "/tmp/photo_analysis_test_#{rand(100000)}",
        data_path: "/tmp/nonexistent"
      )
      cache.entries_for("any-post").should be_empty
    end
  end

  describe "#cache_parent_path" do
    it "returns correct path" do
      cache = PhotoAnalysisCache.new(
        cache_path: "/tmp/test_cache",
        data_path: "/tmp/data"
      )
      cache.cache_parent_path.should eq("/tmp/test_cache/photo_analysis")
    end
  end

  describe "#cache_file_path" do
    it "returns correct path for post slug" do
      cache = PhotoAnalysisCache.new(
        cache_path: "/tmp/test_cache",
        data_path: "/tmp/data"
      )
      cache.cache_file_path("2021-07-18-pagorki").should eq("/tmp/test_cache/photo_analysis/2021-07-18-pagorki.yml")
    end
  end

  describe "YAML round-trip" do
    it "saves and loads cache entries" do
      tmp_dir = "/tmp/photo_analysis_roundtrip_#{rand(100000)}"

      # Create and populate cache
      cache1 = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")
      cache1.load_or_initialize("2021-01-01-test")

      # Manually add an entry to test save/load (simulating what process_photos would do)
      entity = PhotoAnalysisEntity.new(
        image_filename: "photo.jpg",
        post_slug: "2021-01-01-test",
        ahash: "aabb",
        dhash: "ccdd",
        phash: "eeff",
        avg_rgb: [100, 150, 200],
        top5_rgb: [[10, 20, 30], [40, 50, 60]]
      )

      # Write YAML directly to test load
      Dir.mkdir_p(cache1.cache_parent_path)
      File.open(cache1.cache_file_path("2021-01-01-test"), "w") do |f|
        [entity].to_yaml(f)
      end

      # Load in a fresh cache instance
      cache2 = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")
      cache2.load_or_initialize("2021-01-01-test")

      entries = cache2.entries_for("2021-01-01-test")
      entries.size.should eq(1)
      entries[0].image_filename.should eq("photo.jpg")
      entries[0].ahash.should eq("aabb")
      entries[0].avg_rgb.should eq([100, 150, 200])
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end
  end

  describe "#load_or_initialize" do
    it "creates empty entries for new post" do
      tmp_dir = "/tmp/photo_analysis_init_#{rand(100000)}"
      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")

      cache.load_or_initialize("2021-01-01-new")
      cache.entries_for("2021-01-01-new").should be_empty
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end

    it "does not reload if already initialized" do
      tmp_dir = "/tmp/photo_analysis_noreload_#{rand(100000)}"
      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")

      cache.load_or_initialize("2021-01-01-test")
      cache.entries_for("2021-01-01-test").should be_empty

      # Write a file after initialization
      entity = PhotoAnalysisEntity.new(
        image_filename: "late.jpg", post_slug: "2021-01-01-test",
        ahash: "aa", dhash: "bb", phash: "cc",
        avg_rgb: [1, 2, 3], top5_rgb: [[4, 5, 6]]
      )
      Dir.mkdir_p(cache.cache_parent_path)
      File.open(cache.cache_file_path("2021-01-01-test"), "w") do |f|
        [entity].to_yaml(f)
      end

      # Second call should not reload - still empty
      cache.load_or_initialize("2021-01-01-test")
      cache.entries_for("2021-01-01-test").should be_empty
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end
  end

  describe "#process_photos" do
    it "skips already-cached filenames" do
      tmp_dir = "/tmp/photo_analysis_skip_#{rand(100000)}"

      # Pre-populate cache file
      entity = PhotoAnalysisEntity.new(
        image_filename: "cached.jpg", post_slug: "2021-01-01-test",
        ahash: "aa", dhash: "bb", phash: "cc",
        avg_rgb: [1, 2, 3], top5_rgb: [[4, 5, 6]]
      )
      Dir.mkdir_p(File.join(tmp_dir, "photo_analysis"))
      File.open(File.join(tmp_dir, "photo_analysis", "2021-01-01-test.yml"), "w") do |f|
        [entity].to_yaml(f)
      end

      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp/nonexistent_data")
      # Should not error even though data_path doesn't exist - cached.jpg is already present
      cache.process_photos("2021-01-01-test", ["cached.jpg"])

      cache.entries_for("2021-01-01-test").size.should eq(1)
      cache.entries_for("2021-01-01-test")[0].image_filename.should eq("cached.jpg")
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end

    it "handles empty filename list" do
      tmp_dir = "/tmp/photo_analysis_empty_#{rand(100000)}"
      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")
      cache.process_photos("2021-01-01-test", [] of String)
      cache.entries_for("2021-01-01-test").should be_empty
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end
  end

  describe "#save_cache" do
    it "skips write when not dirty (loaded from existing file)" do
      tmp_dir = "/tmp/photo_analysis_clean_#{rand(100000)}"

      # Create a cache file
      entity = PhotoAnalysisEntity.new(
        image_filename: "existing.jpg", post_slug: "2021-01-01-test",
        ahash: "aa", dhash: "bb", phash: "cc",
        avg_rgb: [1, 2, 3], top5_rgb: [[4, 5, 6]]
      )
      Dir.mkdir_p(File.join(tmp_dir, "photo_analysis"))
      path = File.join(tmp_dir, "photo_analysis", "2021-01-01-test.yml")
      File.open(path, "w") do |f|
        [entity].to_yaml(f)
      end
      original_mtime = File.info(path).modification_time

      # Load and save without changes
      sleep(10.milliseconds) # ensure mtime would differ if written
      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")
      cache.load_or_initialize("2021-01-01-test")
      cache.save_cache("2021-01-01-test")

      # File should not have been rewritten
      File.info(path).modification_time.should eq(original_mtime)
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end

    it "writes when dirty (new post with no cache file)" do
      tmp_dir = "/tmp/photo_analysis_dirty_#{rand(100000)}"
      cache = PhotoAnalysisCache.new(cache_path: tmp_dir, data_path: "/tmp")

      cache.load_or_initialize("2021-01-01-new")
      cache.save_cache("2021-01-01-new")

      path = File.join(tmp_dir, "photo_analysis", "2021-01-01-new.yml")
      File.exists?(path).should be_true
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end
  end
end
