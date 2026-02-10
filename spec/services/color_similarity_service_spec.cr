require "../spec_helper"

private def make_color_entry(post_slug : String, filename : String, avg_rgb : Array(Int32))
  PhotoAnalysisEntity.new(
    image_filename: filename,
    post_slug: post_slug,
    ahash: "0000000000000000",
    dhash: "0000000000000000",
    phash: "0000000000000000",
    avg_rgb: avg_rgb,
    top5_rgb: [avg_rgb],
  )
end

private def make_color_photo_lookup(pairs : Array(Tuple(String, String)))
  lookup = Hash(String, PhotoEntity).new
  photo_tags = [] of PhotoTagEntity
  pairs.each do |slug, fname|
    pe = PhotoEntity.new(
      photo_tags: photo_tags,
      post_slug: slug,
      post_url: "/#{slug}",
      post_time: Time.local,
      post_title: slug,
      image_filename: fname,
      param_string: "",
    )
    lookup["#{slug}/#{fname}"] = pe
  end
  lookup
end

describe ColorSimilarityService do
  describe "#find_groups" do
    it "returns empty when no entries" do
      service = ColorSimilarityService.new(
        entries: [] of PhotoAnalysisEntity,
        photo_lookup: Hash(String, PhotoEntity).new,
      )
      service.find_groups.should be_empty
    end

    it "returns empty when entries have no matching PhotoEntity" do
      entries = [
        make_color_entry("post1", "a.jpg", [100, 100, 100]),
        make_color_entry("post1", "b.jpg", [100, 100, 100]),
      ]
      service = ColorSimilarityService.new(
        entries: entries,
        photo_lookup: Hash(String, PhotoEntity).new,
      )
      service.find_groups.should be_empty
    end

    it "groups identical colors together" do
      entries = [
        make_color_entry("post1", "a.jpg", [100, 150, 200]),
        make_color_entry("post2", "b.jpg", [100, 150, 200]),
        make_color_entry("post3", "c.jpg", [10, 20, 30]),
      ]
      lookup = make_color_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}, {"post3", "c.jpg"}])

      service = ColorSimilarityService.new(entries: entries, photo_lookup: lookup)
      groups = service.find_groups

      groups.size.should eq(1)
      groups[0].size.should eq(2)
      filenames = groups[0].map(&.image_filename).sort
      filenames.should eq(["a.jpg", "b.jpg"])
    end

    it "does not group distant colors" do
      entries = [
        make_color_entry("post1", "a.jpg", [0, 0, 0]),
        make_color_entry("post2", "b.jpg", [255, 255, 255]),
      ]
      lookup = make_color_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}])

      service = ColorSimilarityService.new(entries: entries, photo_lookup: lookup)
      service.find_groups.should be_empty
    end

    it "groups nearby colors within threshold" do
      # Distance between [100,100,100] and [110,110,110] = sqrt(300) ≈ 17.3
      entries = [
        make_color_entry("post1", "a.jpg", [100, 100, 100]),
        make_color_entry("post2", "b.jpg", [110, 110, 110]),
      ]
      lookup = make_color_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}])

      service = ColorSimilarityService.new(entries: entries, photo_lookup: lookup, max_distance: 20.0)
      service.find_groups.size.should eq(1)
    end

    it "respects custom max_distance" do
      # Distance between [100,100,100] and [110,110,110] = sqrt(300) ≈ 17.3
      entries = [
        make_color_entry("post1", "a.jpg", [100, 100, 100]),
        make_color_entry("post2", "b.jpg", [110, 110, 110]),
      ]
      lookup = make_color_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}])

      # threshold 10 — too strict
      strict = ColorSimilarityService.new(entries: entries, photo_lookup: lookup, max_distance: 10.0)
      strict.find_groups.should be_empty

      # threshold 20 — groups them
      relaxed = ColorSimilarityService.new(entries: entries, photo_lookup: lookup, max_distance: 20.0)
      relaxed.find_groups.size.should eq(1)
    end
  end
end
