require "../spec_helper"

describe PhotoAnalysisEntity do
  describe "#initialize" do
    it "creates with all fields" do
      entity = PhotoAnalysisEntity.new(
        image_filename: "DSC_1234.jpg",
        post_slug: "2021-07-18-pagorki",
        ahash: "7d7777c1c1c30100",
        dhash: "e5cb4e8e8c6c6c6c",
        phash: "c1c2c3c4c5c6c7c8",
        avg_rgb: [116, 115, 112],
        top5_rgb: [[196, 212, 211], [50, 80, 60], [140, 130, 120], [220, 210, 200], [30, 40, 50]]
      )

      entity.image_filename.should eq("DSC_1234.jpg")
      entity.post_slug.should eq("2021-07-18-pagorki")
      entity.ahash.should eq("7d7777c1c1c30100")
      entity.dhash.should eq("e5cb4e8e8c6c6c6c")
      entity.phash.should eq("c1c2c3c4c5c6c7c8")
      entity.avg_rgb.should eq([116, 115, 112])
      entity.top5_rgb.size.should eq(5)
      entity.top5_rgb.first.should eq([196, 212, 211])
    end
  end

  describe "YAML serialization" do
    it "round-trips through YAML" do
      entity = PhotoAnalysisEntity.new(
        image_filename: "test.jpg",
        post_slug: "2021-01-01-test",
        ahash: "aaaa",
        dhash: "bbbb",
        phash: "cccc",
        avg_rgb: [100, 200, 50],
        top5_rgb: [[10, 20, 30], [40, 50, 60]]
      )

      yaml_str = entity.to_yaml
      restored = PhotoAnalysisEntity.from_yaml(yaml_str)

      restored.image_filename.should eq("test.jpg")
      restored.post_slug.should eq("2021-01-01-test")
      restored.ahash.should eq("aaaa")
      restored.dhash.should eq("bbbb")
      restored.phash.should eq("cccc")
      restored.avg_rgb.should eq([100, 200, 50])
      restored.top5_rgb.should eq([[10, 20, 30], [40, 50, 60]])
    end

    it "round-trips array through YAML" do
      entities = [
        PhotoAnalysisEntity.new(
          image_filename: "a.jpg", post_slug: "2021-01-01-test",
          ahash: "aa", dhash: "bb", phash: "cc",
          avg_rgb: [1, 2, 3], top5_rgb: [[4, 5, 6]]
        ),
        PhotoAnalysisEntity.new(
          image_filename: "b.jpg", post_slug: "2021-01-01-test",
          ahash: "dd", dhash: "ee", phash: "ff",
          avg_rgb: [7, 8, 9], top5_rgb: [[10, 11, 12]]
        ),
      ]

      yaml_str = entities.to_yaml
      restored = Array(PhotoAnalysisEntity).from_yaml(yaml_str)

      restored.size.should eq(2)
      restored[0].image_filename.should eq("a.jpg")
      restored[1].image_filename.should eq("b.jpg")
    end
  end

  describe "JSON serialization" do
    it "serializes to JSON" do
      entity = PhotoAnalysisEntity.new(
        image_filename: "test.jpg",
        post_slug: "2021-01-01-test",
        ahash: "aaaa",
        dhash: "bbbb",
        phash: "cccc",
        avg_rgb: [100, 200, 50],
        top5_rgb: [[10, 20, 30]]
      )

      json_str = entity.to_json
      parsed = JSON.parse(json_str)

      parsed["image_filename"].as_s.should eq("test.jpg")
      parsed["ahash"].as_s.should eq("aaaa")
      parsed["avg_rgb"].as_a.map(&.as_i).should eq([100, 200, 50])
    end
  end
end
