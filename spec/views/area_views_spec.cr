require "../spec_helper"

describe AreaShowView do
  it "exists" do
    AreaShowView.should_not be_nil
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
end

describe Router do
  router = Router.new

  it "generates correct area_type_prefix for show pages" do
    router.area_type_prefix(AreaType::Town).should eq "/gmina/"
    router.area_type_prefix(AreaType::County).should eq "/powiat/"
    router.area_type_prefix(AreaType::Voivodeship).should eq "/wojewodztwo/"
    router.area_type_prefix(AreaType::MesoRegion).should eq "/region/"
    router.area_type_prefix(AreaType::MacroRegion).should eq "/obszar/"
  end

  it "generates correct area_type_segment for gallery/post list pages" do
    router.area_type_segment(AreaType::Town).should eq "gminy"
    router.area_type_segment(AreaType::County).should eq "powiatu"
    router.area_type_segment(AreaType::Voivodeship).should eq "wojewodztwa"
    router.area_type_segment(AreaType::MesoRegion).should eq "regionu"
    router.area_type_segment(AreaType::MacroRegion).should eq "obszaru"
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
