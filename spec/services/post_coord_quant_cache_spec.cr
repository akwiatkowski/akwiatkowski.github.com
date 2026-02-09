require "../spec_helper"

describe PostCoordQuantCache do
  describe "#initialize" do
    it "creates with empty cache when no cache file exists" do
      cache = PostCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")
      cache.cache_file_path.should eq("/tmp/nonexistent_test_dir/post_coord_quant.yml")
    end
  end

  describe "#get" do
    it "returns nil for unknown slug" do
      cache = PostCoordQuantCache.new(cache_path: "/tmp/nonexistent_test_dir")
      cache.get("nonexistent-post").should be_nil
    end
  end
end
