require "./spec_helper"

describe AreaType do
  describe "#url_prefix" do
    it "returns Polish URL prefix for Town" do
      AreaType::Town.url_prefix.should eq "/gminy/"
    end

    it "returns Polish URL prefix for County" do
      AreaType::County.url_prefix.should eq "/powiaty/"
    end

    it "returns Polish URL prefix for Voivodeship" do
      AreaType::Voivodeship.url_prefix.should eq "/wojewodztwa/"
    end

    it "returns Polish URL prefix for MesoRegion" do
      AreaType::MesoRegion.url_prefix.should eq "/regiony/"
    end

    it "returns Polish URL prefix for MacroRegion" do
      AreaType::MacroRegion.url_prefix.should eq "/obszary/"
    end
  end

  describe "#url_type" do
    it "returns type name without slashes for Town" do
      AreaType::Town.url_type.should eq "gminy"
    end

    it "returns type name without slashes for MesoRegion" do
      AreaType::MesoRegion.url_type.should eq "regiony"
    end
  end

  describe "#polish_name" do
    it "returns singular Polish name" do
      AreaType::Town.polish_name.should eq "gmina"
      AreaType::Voivodeship.polish_name.should eq "województwo"
    end
  end

  describe "#polish_name_plural" do
    it "returns plural Polish name" do
      AreaType::Town.polish_name_plural.should eq "gminy"
      AreaType::Voivodeship.polish_name_plural.should eq "województwa"
    end
  end
end

describe AreaEntity do
  describe "#initialize" do
    it "creates entity with basic attributes" do
      entity = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town,
        code: "3021123",
        voivodeship_slug: "wielkopolskie"
      )

      entity.slug.should eq "pobiedziska"
      entity.name.should eq "Pobiedziska"
      entity.area_type.should eq AreaType::Town
      entity.code.should eq "3021123"
      entity.voivodeship_slug.should eq "wielkopolskie"
    end
  end

  describe "#show_url" do
    it "returns correct show URL for town" do
      entity = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town
      )

      entity.show_url.should eq "/gminy/pobiedziska.html"
    end

    it "returns correct show URL for meso region" do
      entity = AreaEntity.new(
        slug: "pojezierze-gnieznienskie",
        name: "Pojezierze Gnieźnieńskie",
        area_type: AreaType::MesoRegion
      )

      entity.show_url.should eq "/regiony/pojezierze-gnieznienskie.html"
    end
  end

  describe "#post_list_url" do
    it "returns correct post list URL" do
      entity = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town
      )

      entity.post_list_url.should eq "/wpisy_dla/gminy/pobiedziska.html"
    end
  end

  describe "#gallery_url" do
    it "returns correct gallery URL" do
      entity = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town
      )

      entity.gallery_url.should eq "/galeria/gminy/pobiedziska.html"
    end
  end

  describe "#center" do
    it "returns nil when bbox is nil" do
      entity = AreaEntity.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town
      )

      entity.center.should be_nil
    end

    it "returns center point when bbox exists" do
      bbox = AreaMatcher::BBox.new(
        south: 52.0,
        north: 53.0,
        west: 17.0,
        east: 18.0
      )

      entity = AreaEntity.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        bbox: bbox
      )

      center = entity.center.not_nil!
      center[0].should eq 52.5  # lat
      center[1].should eq 17.5  # lon
    end
  end

  describe "#bbox_contains?" do
    it "returns false when bbox is nil" do
      entity = AreaEntity.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town
      )

      entity.bbox_contains?(52.5, 17.5).should be_false
    end

    it "returns true when point is inside bbox" do
      bbox = AreaMatcher::BBox.new(
        south: 52.0,
        north: 53.0,
        west: 17.0,
        east: 18.0
      )

      entity = AreaEntity.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        bbox: bbox
      )

      entity.bbox_contains?(52.5, 17.5).should be_true
    end

    it "returns false when point is outside bbox" do
      bbox = AreaMatcher::BBox.new(
        south: 52.0,
        north: 53.0,
        west: 17.0,
        east: 18.0
      )

      entity = AreaEntity.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        bbox: bbox
      )

      entity.bbox_contains?(50.0, 15.0).should be_false
    end
  end
end

describe AreaAssociation do
  describe "#initialize" do
    it "creates association with distance data" do
      assoc = AreaAssociation.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town,
        distance_meters: 5000.0,
        distance_percent: 25.0
      )

      assoc.slug.should eq "pobiedziska"
      assoc.distance_meters.should eq 5000.0
      assoc.distance_percent.should eq 25.0
    end
  end

  describe "#above_threshold?" do
    it "returns true when above default threshold (1%)" do
      assoc = AreaAssociation.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        distance_meters: 1000.0,
        distance_percent: 5.0
      )

      assoc.above_threshold?.should be_true
    end

    it "returns false when below default threshold (1%)" do
      assoc = AreaAssociation.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        distance_meters: 100.0,
        distance_percent: 0.5
      )

      assoc.above_threshold?.should be_false
    end

    it "uses custom threshold when provided" do
      assoc = AreaAssociation.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        distance_meters: 1000.0,
        distance_percent: 5.0
      )

      assoc.above_threshold?(10.0).should be_false
      assoc.above_threshold?(3.0).should be_true
    end
  end

  describe "#distance_km" do
    it "converts meters to kilometers" do
      assoc = AreaAssociation.new(
        slug: "test",
        name: "Test",
        area_type: AreaType::Town,
        distance_meters: 5000.0,
        distance_percent: 25.0
      )

      assoc.distance_km.should eq 5.0
    end
  end
end
