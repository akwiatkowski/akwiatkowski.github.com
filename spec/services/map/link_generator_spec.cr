require "../../spec_helper"

describe Map::LinkGenerator do
  describe ".url_photomap_main" do
    it "returns /mapa_zdjec" do
      Map::LinkGenerator.url_photomap_main.should eq "/mapa_zdjec"
    end
  end

  describe ".url_photomap_for_area_big" do
    it "returns correct path for Town" do
      area = AreaEntity.new(slug: "pobiedziska", name: "Pobiedziska", area_type: AreaType::Town)
      Map::LinkGenerator.url_photomap_for_area_big(area: area).should eq "/mapa_zdjec/gmina/pobiedziska_duzy.svg"
    end

    it "returns correct path for County" do
      area = AreaEntity.new(slug: "poznan", name: "Poznan", area_type: AreaType::County)
      Map::LinkGenerator.url_photomap_for_area_big(area: area).should eq "/mapa_zdjec/powiat/poznan_duzy.svg"
    end

    it "returns correct path for Voivodeship" do
      area = AreaEntity.new(slug: "wielkopolskie", name: "Wielkopolskie", area_type: AreaType::Voivodeship)
      Map::LinkGenerator.url_photomap_for_area_big(area: area).should eq "/mapa_zdjec/wojewodztwo/wielkopolskie_duzy.svg"
    end

    it "returns correct path for MesoRegion" do
      area = AreaEntity.new(slug: "pojezierze", name: "Pojezierze", area_type: AreaType::MesoRegion)
      Map::LinkGenerator.url_photomap_for_area_big(area: area).should eq "/mapa_zdjec/region/pojezierze_duzy.svg"
    end

    it "returns correct path for MacroRegion" do
      area = AreaEntity.new(slug: "nizina", name: "Nizina", area_type: AreaType::MacroRegion)
      Map::LinkGenerator.url_photomap_for_area_big(area: area).should eq "/mapa_zdjec/obszar/nizina_duzy.svg"
    end
  end

  describe ".url_photomap_for_area_small" do
    it "returns correct path for Town" do
      area = AreaEntity.new(slug: "pobiedziska", name: "Pobiedziska", area_type: AreaType::Town)
      Map::LinkGenerator.url_photomap_for_area_small(area: area).should eq "/mapa_zdjec/gmina/pobiedziska_maly.svg"
    end

    it "returns correct path for Voivodeship" do
      area = AreaEntity.new(slug: "wielkopolskie", name: "Wielkopolskie", area_type: AreaType::Voivodeship)
      Map::LinkGenerator.url_photomap_for_area_small(area: area).should eq "/mapa_zdjec/wojewodztwo/wielkopolskie_maly.svg"
    end
  end

  describe ".url_photomap_for_idea" do
    it "returns correct path" do
      Map::LinkGenerator.url_photomap_for_idea(slug: "my-idea").should eq "/mapa_zdjec/pomysl/my-idea.svg"
    end
  end

  describe ".url_photomap_for_main" do
    it "returns correct path" do
      Map::LinkGenerator.url_photomap_for_main(slug: "overall").should eq "/mapa_zdjec/globalne/overall.svg"
    end
  end

  describe ".url_photomap_for_tag" do
    it "returns correct path" do
      Map::LinkGenerator.url_photomap_for_tag(slug: "winter").should eq "/mapa_zdjec/tag/winter.svg"
    end
  end
end
