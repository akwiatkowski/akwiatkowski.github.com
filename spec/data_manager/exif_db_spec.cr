require "../spec_helper"

describe ExifDb do
  describe "#initialize" do
    it "creates with cache_path, data_path, and photo_tags" do
      db = ExifDb.new(
        cache_path: "/tmp/test_exif_cache",
        data_path: "/tmp/test_data",
        photo_tags: Array(PhotoTagEntity).new
      )
      db.exif_db_file_parent_path.should eq("/tmp/test_exif_cache/exifs")
    end
  end

  describe "#exif_db_file_path" do
    it "returns correct path for post slug" do
      db = ExifDb.new(
        cache_path: "/tmp/cache",
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )
      db.exif_db_file_path("test-post").should eq("/tmp/cache/exifs/test-post.yml")
    end
  end

  describe "#published_photo_entities" do
    it "returns empty array for unknown post slug" do
      db = ExifDb.new(
        cache_path: "/tmp/cache",
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )
      db.published_photo_entities("nonexistent").should be_empty
    end
  end

  describe "#uploaded_photo_entities" do
    it "returns empty array for unknown post slug" do
      db = ExifDb.new(
        cache_path: "/tmp/cache",
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )
      db.uploaded_photo_entities("nonexistent").should be_empty
    end
  end

  describe "#all_flatten_photo_entities" do
    it "returns empty array when no photos loaded" do
      db = ExifDb.new(
        cache_path: "/tmp/cache",
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )
      db.all_flatten_photo_entities.should be_empty
    end
  end

  describe "#load_or_initialize_exif_for_post" do
    it "initializes empty exif array for new post slug" do
      dir = "/tmp/test_exif_db_#{Random.rand(100000)}"
      db = ExifDb.new(
        cache_path: dir,
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )

      db.load_or_initialize_exif_for_post("new-post")
      # After init, save_cache should write (dirty=true for new posts)
      db.save_cache("new-post")
      File.exists?(db.exif_db_file_path("new-post")).should be_true
    ensure
      if dir && Dir.exists?(dir)
        Dir.glob(File.join(dir, "**", "*")).sort.reverse.each { |f| File.directory?(f) ? Dir.delete(f) : File.delete(f) }
        Dir.delete(dir)
      end
    end

    it "does not re-initialize if already loaded" do
      dir = "/tmp/test_exif_db_#{Random.rand(100000)}"
      db = ExifDb.new(
        cache_path: dir,
        data_path: "/tmp/data",
        photo_tags: Array(PhotoTagEntity).new
      )

      db.load_or_initialize_exif_for_post("post-a")
      db.save_cache("post-a")
      File.exists?(db.exif_db_file_path("post-a")).should be_true

      # Second call should be a no-op (already loaded)
      db.load_or_initialize_exif_for_post("post-a")
    ensure
      if dir && Dir.exists?(dir)
        Dir.glob(File.join(dir, "**", "*")).sort.reverse.each { |f| File.directory?(f) ? Dir.delete(f) : File.delete(f) }
        Dir.delete(dir)
      end
    end
  end
end
