require "../spec_helper"

describe PhotoTagEntity do
  describe "YAML constructor" do
    it "parses from YAML::Any" do
      yaml = YAML.parse(%(
        slug: good
        slug_pl: dobre
        title: Dobre zdjęcia
        subtitle: Najlepsze kadry
        points: 3
      ))
      tag = PhotoTagEntity.new(yaml)
      tag.slug.should eq "good"
      tag.slug_pl.should eq "dobre"
      tag.title.should eq "Dobre zdjęcia"
      tag.subtitle.should eq "Najlepsze kadry"
      tag.points.should eq 3
    end
  end

  describe "direct constructor" do
    it "creates a tag with all fields" do
      tag = PhotoTagEntity.new("best", "najlepsze", "Najlepsze", 5, subtitle: "Top")
      tag.slug.should eq "best"
      tag.slug_pl.should eq "najlepsze"
      tag.title.should eq "Najlepsze"
      tag.points.should eq 5
      tag.subtitle.should eq "Top"
    end

    it "defaults subtitle to nil" do
      tag = PhotoTagEntity.new("good", "dobre", "Dobre", 3)
      tag.subtitle.should be_nil
    end
  end

  describe "#view_url" do
    it "generates gallery URL from slug_pl" do
      tag = PhotoTagEntity.new("best", "najlepsze", "Najlepsze", 5)
      tag.view_url.should eq "/galeria/tag/najlepsze.html"
    end
  end
end
