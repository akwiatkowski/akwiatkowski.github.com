require "../spec_helper"

private def make_phash_entry(post_slug : String, filename : String, phash : String)
  PhotoAnalysisEntity.new(
    image_filename: filename,
    post_slug: post_slug,
    ahash: "0000000000000000",
    dhash: "0000000000000000",
    phash: phash,
    avg_rgb: [128, 128, 128],
    top5_rgb: [[128, 128, 128]],
  )
end

private def make_photo_lookup(pairs : Array(Tuple(String, String)))
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

describe PhotoSimilarityService do
  describe "#find_groups" do
    it "returns empty when no entries" do
      service = PhotoSimilarityService.new(
        entries: [] of PhotoAnalysisEntity,
        photo_lookup: Hash(String, PhotoEntity).new,
      )
      service.find_groups.should be_empty
    end

    it "returns empty when entries have no matching PhotoEntity" do
      entries = [
        make_phash_entry("post1", "a.jpg", "abcdef0123456789"),
        make_phash_entry("post1", "b.jpg", "abcdef0123456789"),
      ]
      service = PhotoSimilarityService.new(
        entries: entries,
        photo_lookup: Hash(String, PhotoEntity).new,
      )
      service.find_groups.should be_empty
    end

    it "groups identical hashes together" do
      entries = [
        make_phash_entry("post1", "a.jpg", "abcdef0123456789"),
        make_phash_entry("post2", "b.jpg", "abcdef0123456789"),
        make_phash_entry("post3", "c.jpg", "1111111111111111"),
      ]
      lookup = make_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}, {"post3", "c.jpg"}])

      service = PhotoSimilarityService.new(entries: entries, photo_lookup: lookup)
      groups = service.find_groups

      groups.size.should eq(1)
      groups[0].size.should eq(2)
      filenames = groups[0].map(&.image_filename).sort
      filenames.should eq(["a.jpg", "b.jpg"])
    end

    it "does not group distant hashes" do
      entries = [
        make_phash_entry("post1", "a.jpg", "0000000000000000"),
        make_phash_entry("post2", "b.jpg", "ffffffffffffffff"),
      ]
      lookup = make_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}])

      service = PhotoSimilarityService.new(entries: entries, photo_lookup: lookup)
      service.find_groups.should be_empty
    end

    it "respects custom threshold" do
      # Hashes differ by 1 bit
      entries = [
        make_phash_entry("post1", "a.jpg", "0000000000000000"),
        make_phash_entry("post2", "b.jpg", "0000000000000001"),
      ]
      lookup = make_photo_lookup([{"post1", "a.jpg"}, {"post2", "b.jpg"}])

      # threshold=0 should not group them (1 bit difference)
      strict = PhotoSimilarityService.new(entries: entries, photo_lookup: lookup, threshold: 0)
      strict.find_groups.should be_empty

      # threshold=1 should group them
      relaxed = PhotoSimilarityService.new(entries: entries, photo_lookup: lookup, threshold: 1)
      relaxed.find_groups.size.should eq(1)
    end
  end
end
