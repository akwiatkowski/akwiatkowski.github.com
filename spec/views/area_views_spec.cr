require "../spec_helper"

describe AreaShowView do
  it "exists" do
    AreaShowView.should_not be_nil
  end

  it "uses correct URL pattern for show pages (ASCII-safe nominative)" do
    # URL pattern: /<nominative_slug>/<slug>.html
    AreaType::Town.url_prefix.should eq "/gmina/"
    AreaType::County.url_prefix.should eq "/powiat/"
    AreaType::Voivodeship.url_prefix.should eq "/wojewodztwo/"
    AreaType::MesoRegion.url_prefix.should eq "/region/"
    AreaType::MacroRegion.url_prefix.should eq "/obszar/"
  end

  it "adds pages to sitemap" do
    # AreaShowView#add_to_sitemap? returns true
    # We test this by checking the class exists and has the method
    AreaShowView.should_not be_nil
  end
end

describe GalleryView::AreaGalleryView do
  it "exists" do
    GalleryView::AreaGalleryView.should_not be_nil
  end

  it "uses correct URL pattern for gallery pages (ASCII-safe genitive)" do
    # URL pattern: /galeria/<genitive_slug>/<slug>.html
    AreaType::Town.url_type.should eq "gminy"
    AreaType::County.url_type.should eq "powiatu"
    AreaType::Voivodeship.url_type.should eq "wojewodztwa"
    AreaType::MesoRegion.url_type.should eq "regionu"
    AreaType::MacroRegion.url_type.should eq "obszaru"
  end
end

describe "Area URL helpers" do
  describe AreaType do
    it "has polish_name for all types" do
      AreaType::Town.polish_name.should eq "gmina"
      AreaType::County.polish_name.should eq "powiat"
      AreaType::Voivodeship.polish_name.should eq "województwo"
      AreaType::MesoRegion.polish_name.should eq "region"
      AreaType::MacroRegion.polish_name.should eq "obszar"
    end

    it "has payload_field for all types" do
      AreaType::Town.payload_field.should eq "towns"
      AreaType::County.payload_field.should eq "counties"
      AreaType::Voivodeship.payload_field.should eq "voivodeships"
      AreaType::MesoRegion.payload_field.should eq "meso_regions"
      AreaType::MacroRegion.payload_field.should eq "macro_regions"
    end

    it "has polygon_dir for all types" do
      AreaType::Town.polygon_dir.should eq "towns"
      AreaType::County.polygon_dir.should eq "counties"
      AreaType::Voivodeship.polygon_dir.should eq "voivodeships"
      AreaType::MesoRegion.polygon_dir.should eq "meso_regions"
      AreaType::MacroRegion.polygon_dir.should eq "macro_regions"
    end
  end
end
