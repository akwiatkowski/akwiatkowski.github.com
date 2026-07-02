require "../spec_helper"

describe NavStatsCacheObject do
  describe "#initialize" do
    it "creates with zero values" do
      stats = NavStatsCacheObject.new
      stats.bicycle_distance.should eq(0)
      stats.hike_distance.should eq(0)
      stats.train_distance.should eq(0)
      stats.self_distance.should eq(0)
    end
  end

  describe NavStatsCacheObject::EntityNavTuple do
    it "creates with name, url, count, slug, type" do
      tuple = NavStatsCacheObject::EntityNavTuple.new(
        name: "Poznań",
        url: "/gmina/poznan.html",
        count: 5,
        slug: "poznan",
        type: "town"
      )

      tuple.name.should eq("Poznań")
      tuple.url.should eq("/gmina/poznan.html")
      tuple.count.should eq(5)
      tuple.slug.should eq("poznan")
      tuple.type.should eq("town")
    end

    it "generates html_id from type and slug" do
      tuple = NavStatsCacheObject::EntityNavTuple.new(
        name: "Poznań", url: "/", count: 1, slug: "poznan", type: "town"
      )
      tuple.html_id.should eq("nav-post-count-town-poznan")
    end
  end
end

describe NavStatsCache do
  describe "#initialize" do
    it "creates with empty stats when no cache file exists" do
      cache = NavStatsCache.new(cache_path: "/tmp/nonexistent_nav_test_dir")
      cache.stats.bicycle_distance.should eq(0)
      cache.stats.voivodeships_nav.should be_empty
    end

    it "sets correct cache file path" do
      cache = NavStatsCache.new(cache_path: "/tmp/test_cache")
      cache.cache_file_path.should eq("/tmp/test_cache/nav_stats.yml")
    end
  end

  describe "#to_hash" do
    it "generates nav stats hash with formatted strings" do
      cache = NavStatsCache.new(cache_path: "/tmp/nonexistent_nav_test_dir")
      h = cache.to_hash

      h.has_key?("nav-stats-short").should be_true
      h.has_key?("nav-stats-bicycle").should be_true
      h.has_key?("nav-stats-hike").should be_true
      h.has_key?("nav-stats-train").should be_true
      h.has_key?("current_year").should be_true
      h["current_year"].should eq(Time.local.year.to_s)
    end

    it "formats distance with thousands separator" do
      cache = NavStatsCache.new(cache_path: "/tmp/nonexistent_nav_test_dir")
      cache.stats.self_distance = 12345
      h = cache.to_hash

      h["nav-stats-short"].should eq("12 345 km")
    end
  end
end
