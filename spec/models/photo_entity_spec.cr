require "../spec_helper"

# Helper to build photo tags for tests
private def make_photo_tags
  [
    PhotoTagEntity.new("good", "dobre", "Dobre", 3),
    PhotoTagEntity.new("best", "najlepsze", "Najlepsze", 5),
    PhotoTagEntity.new("cat", "koty", "Koty", 2),
    PhotoTagEntity.new("timeline", "timeline", "Timeline", 1),
  ]
end

private def make_post_time
  Time.local(2023, 7, 18, location: Time::Location::UTC)
end

private def make_photo_entity(
  desc = "Widok na jezioro",
  param_string = "",
  image_filename = "DSC00123.jpg",
  tags = Array(String).new,
  is_gallery = true,
  is_header = false,
  is_timeline = false,
  is_map = false,
)
  PhotoEntity.new(
    photo_tags: make_photo_tags,
    post_slug: "2023-07-18-wycieczka",
    post_url: "/2023/07/18-wycieczka.html",
    post_time: make_post_time,
    post_title: "Wycieczka nad jezioro",
    image_filename: image_filename,
    param_string: param_string,
    desc: desc,
    tags: tags,
    is_gallery: is_gallery,
    is_header: is_header,
    is_timeline: is_timeline,
    is_map: is_map,
  )
end

describe PhotoEntity do
  describe "construction with desc" do
    it "sets desc and nameless=false" do
      pe = make_photo_entity(desc: "Piękny widok")
      pe.desc.should eq "Piękny widok"
      pe.nameless.should be_false
    end
  end

  describe "construction without desc" do
    it "uses image_filename as desc and sets nameless=true" do
      pe = PhotoEntity.new(
        photo_tags: make_photo_tags,
        post_slug: "2023-07-18-wycieczka",
        post_url: "/2023/07/18-wycieczka.html",
        post_time: make_post_time,
        post_title: "Wycieczka",
        image_filename: "DSC00123.jpg",
        param_string: "",
      )
      pe.desc.should eq "DSC00123.jpg"
      pe.nameless.should be_true
    end
  end

  describe "post fields" do
    it "stores post_slug, post_url, post_time, post_title" do
      pe = make_photo_entity
      pe.post_slug.should eq "2023-07-18-wycieczka"
      pe.post_url.should eq "/2023/07/18-wycieczka.html"
      pe.post_time.should eq make_post_time
      pe.post_title.should eq "Wycieczka nad jezioro"
    end
  end

  describe "points calculation" do
    it "returns 0 for no tags" do
      pe = make_photo_entity(tags: [] of String)
      pe.points.should eq 0
    end

    it "sums points for one tag" do
      pe = make_photo_entity(tags: ["good"])
      pe.points.should eq 3
    end

    it "sums points for two tags" do
      pe = make_photo_entity(tags: ["good", "best"])
      pe.points.should eq 8
    end
  end

  describe "#is_good?" do
    it "returns true when has 'good' tag" do
      pe = make_photo_entity(tags: ["good"])
      pe.is_good?.should be_true
    end

    it "returns false without 'good' tag" do
      pe = make_photo_entity(tags: ["best"])
      pe.is_good?.should be_false
    end
  end

  describe "#is_best?" do
    it "returns true when has 'best' tag" do
      pe = make_photo_entity(tags: ["best"])
      pe.is_best?.should be_true
    end

    it "returns false without 'best' tag" do
      pe = make_photo_entity(tags: ["good"])
      pe.is_best?.should be_false
    end
  end

  describe "#is_at_least_good?" do
    it "returns true for 'good'" do
      pe = make_photo_entity(tags: ["good"])
      pe.is_at_least_good?.should be_true
    end

    it "returns true for 'best'" do
      pe = make_photo_entity(tags: ["best"])
      pe.is_at_least_good?.should be_true
    end

    it "returns false for neither" do
      pe = make_photo_entity(tags: ["cat"])
      pe.is_at_least_good?.should be_false
    end
  end

  describe "#has_tag?" do
    it "returns true for present tag" do
      pe = make_photo_entity(tags: ["good", "cat"])
      pe.has_tag?("cat").should be_true
    end

    it "returns false for absent tag" do
      pe = make_photo_entity(tags: ["good"])
      pe.has_tag?("best").should be_false
    end
  end

  describe "#update_desc_and_params" do
    it "updates desc and re-parses param_string" do
      pe = make_photo_entity(desc: "Original", param_string: "")
      pe.update_desc_and_params("Updated", "tag:good,nogallery")
      pe.desc.should eq "Updated"
      pe.nameless.should be_false
      pe.is_gallery.should be_false
      pe.tags.should contain("good")
    end
  end

  describe "param_string parsing" do
    it "sets is_gallery=false for nogallery" do
      pe = make_photo_entity(param_string: "nogallery")
      pe.is_gallery.should be_false
    end

    it "sets is_timeline=false for notimeline" do
      pe = make_photo_entity(is_timeline: true, param_string: "notimeline")
      pe.is_timeline.should be_false
    end

    it "sets is_timeline=true for timeline" do
      pe = make_photo_entity(param_string: "timeline")
      pe.is_timeline.should be_true
    end

    it "sets is_map=true for map" do
      pe = make_photo_entity(param_string: "map")
      pe.is_map.should be_true
    end

    it "extracts tags from param_string" do
      pe = make_photo_entity(param_string: "tag:good,tag:best")
      pe.tags.should contain("good")
      pe.tags.should contain("best")
    end

    it "accumulates param tags with constructor tags" do
      pe = make_photo_entity(tags: ["cat"], param_string: "tag:good")
      pe.tags.should contain("cat")
      pe.tags.should contain("good")
    end
  end

  describe "image path generation" do
    it "generates card_image_src" do
      pe = make_photo_entity
      pe.card_image_src.should contain("card")
      pe.card_image_src.should contain("DSC00123")
      pe.card_image_src.should contain("2023")
    end

    it "generates thumbnail_image_src" do
      pe = make_photo_entity
      pe.thumbnail_image_src.should contain("thumbnail")
      pe.thumbnail_image_src.should contain("DSC00123")
    end

    it "generates article_image_src" do
      pe = make_photo_entity
      pe.article_image_src.should contain("article")
      pe.article_image_src.should contain("DSC00123")
    end

    it "generates grid_image_src" do
      pe = make_photo_entity
      pe.grid_image_src.should contain("grid")
      pe.grid_image_src.should contain("DSC00123")
    end

    it "generates full_image_src with year and slug" do
      pe = make_photo_entity
      pe.full_image_src.should eq "/images/2023/2023-07-18-wycieczka/DSC00123.jpg"
    end

    it "generates full_image_sanitized without special characters" do
      pe = make_photo_entity
      pe.full_image_sanitized.should_not contain("/")
      pe.full_image_sanitized.should_not contain(".")
    end
  end

  describe "time fields" do
    it "sets time from post_time" do
      pe = make_photo_entity
      pe.time.should eq make_post_time
    end

    it "calculates day_of_year" do
      pe = make_photo_entity
      pe.day_of_year.should eq make_post_time.day_of_year
    end

    it "calculates float_of_year" do
      pe = make_photo_entity
      expected = make_post_time.day_of_year.to_f / 365.0
      pe.float_of_year.should be_close(expected, 0.001)
    end
  end

  describe "exif" do
    it "initializes ExifEntity with post_slug and image_filename" do
      pe = make_photo_entity
      pe.exif.should_not be_nil
      pe.exif.post_slug.should eq "2023-07-18-wycieczka"
      pe.exif.image_filename.should eq "DSC00123.jpg"
    end

    it "allows setting exif properties" do
      pe = make_photo_entity
      pe.exif.lat = 52.4
      pe.exif.lon = 16.9
      pe.exif.lat.should eq 52.4
      pe.exif.lon.should eq 16.9
    end

    it "allows setting exif time" do
      pe = make_photo_entity
      exif_time = Time.local(2023, 7, 18, 14, 30, 0, location: Time::Location::UTC)
      pe.exif.time = exif_time
      pe.exif.time.should eq exif_time
    end
  end

  describe "<=>" do
    it "compares by exif time when both have it" do
      pe1 = make_photo_entity(image_filename: "A.jpg")
      pe2 = make_photo_entity(image_filename: "B.jpg")
      pe1.exif.time = Time.local(2023, 7, 18, 10, 0, 0, location: Time::Location::UTC)
      pe2.exif.time = Time.local(2023, 7, 18, 14, 0, 0, location: Time::Location::UTC)
      (pe1 <=> pe2).should eq -1
    end

    it "falls back to filename comparison" do
      pe1 = make_photo_entity(image_filename: "A.jpg")
      pe2 = make_photo_entity(image_filename: "B.jpg")
      (pe1 <=> pe2).should eq -1
    end
  end

  describe "header photo entity simulation" do
    it "creates a valid header photo entity with all fields accessible" do
      pe = PhotoEntity.new(
        photo_tags: make_photo_tags,
        post_slug: "2023-07-18-wycieczka",
        post_url: "/2023/07/18-wycieczka.html",
        post_time: make_post_time,
        post_title: "Wycieczka nad jezioro",
        image_filename: "header.jpg",
        param_string: "",
        desc: "Wycieczka nad jezioro",
        is_gallery: true,
        is_header: true,
        is_timeline: false,
      )

      # Core identity
      pe.is_header.should be_true
      pe.desc.should eq "Wycieczka nad jezioro"
      pe.nameless.should be_false
      pe.image_filename.should eq "header.jpg"

      # Post reference fields
      pe.post_slug.should eq "2023-07-18-wycieczka"
      pe.post_url.should eq "/2023/07/18-wycieczka.html"
      pe.post_time.should eq make_post_time
      pe.post_title.should eq "Wycieczka nad jezioro"

      # Image paths
      pe.card_image_src.should_not be_empty
      pe.thumbnail_image_src.should_not be_empty
      pe.article_image_src.should_not be_empty
      pe.grid_image_src.should_not be_empty
      pe.full_image_src.should eq "/images/2023/2023-07-18-wycieczka/header.jpg"
      pe.full_image_sanitized.should_not be_empty

      # Time fields
      pe.time.should eq make_post_time
      pe.day_of_year.should eq make_post_time.day_of_year
      pe.float_of_year.should be_close(make_post_time.day_of_year.to_f / 365.0, 0.001)

      # Exif data access
      pe.exif.should_not be_nil
      pe.exif.post_slug.should eq "2023-07-18-wycieczka"
      pe.exif.image_filename.should eq "header.jpg"

      # Exif can be populated
      pe.exif.lat = 52.4064
      pe.exif.lon = 16.9252
      pe.exif.camera = "ILCE-7M3"
      pe.exif.lens = "FE 85mm F1.8"
      pe.exif.time = Time.local(2023, 7, 18, 15, 30, 0, location: Time::Location::UTC)
      pe.exif.lat.should eq 52.4064
      pe.exif.lon.should eq 16.9252
      pe.exif.camera.should eq "ILCE-7M3"
      pe.exif.time.should_not be_nil

      # hash_for_partial works with exif data
      hash = pe.hash_for_partial
      hash["post.url"].should eq "/2023/07/18-wycieczka.html"
      hash["img.src"].should eq pe.article_image_src
      hash["img.alt"].should eq "Wycieczka nad jezioro"
      hash["post.title"].should eq "Wycieczka nad jezioro"
      hash["img.lat"].should eq "52.4064"
      hash["img.lon"].should eq "16.9252"

      # update_desc_and_params works on header photo
      pe.update_desc_and_params("Updated header", "tag:good")
      pe.desc.should eq "Updated header"
      pe.tags.should contain("good")
      pe.points.should eq 0 # points not recalculated by update_desc_and_params
    end
  end

  describe "#factor_for_gallery_fill" do
    it "returns higher factor for photos with more tags" do
      pe1 = make_photo_entity(tags: ["good"], param_string: "")
      pe2 = make_photo_entity(tags: ["good", "best"], param_string: "")
      # Both need exif time set
      now = Time.local(location: Time::Location::UTC)
      pe1.exif.time = now - 365.days
      pe2.exif.time = now - 365.days
      pe2.factor_for_gallery_fill.should be > pe1.factor_for_gallery_fill
    end
  end
end
