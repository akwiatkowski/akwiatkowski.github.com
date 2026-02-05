require "./spec_helper"

describe Router do
  router = Router.new

  describe "Area URL Building Blocks" do
    describe "#area_type_prefix" do
      it "returns nominative prefix for all area types" do
        router.area_type_prefix(AreaType::Town).should eq "/gmina/"
        router.area_type_prefix(AreaType::County).should eq "/powiat/"
        router.area_type_prefix(AreaType::Voivodeship).should eq "/wojewodztwo/"
        router.area_type_prefix(AreaType::MesoRegion).should eq "/region/"
        router.area_type_prefix(AreaType::MacroRegion).should eq "/obszar/"
      end
    end

    describe "#area_type_segment" do
      it "returns genitive segment for all area types" do
        router.area_type_segment(AreaType::Town).should eq "gminy"
        router.area_type_segment(AreaType::County).should eq "powiatu"
        router.area_type_segment(AreaType::Voivodeship).should eq "wojewodztwa"
        router.area_type_segment(AreaType::MesoRegion).should eq "regionu"
        router.area_type_segment(AreaType::MacroRegion).should eq "obszaru"
      end
    end
  end

  describe "Area URLs" do
    area = AreaEntity.new(
      slug: "pobiedziska",
      name: "Pobiedziska",
      area_type: AreaType::Town
    )

    voivodeship = AreaEntity.new(
      slug: "wielkopolskie",
      name: "Wielkopolskie",
      area_type: AreaType::Voivodeship
    )

    describe "#area_show_url" do
      it "returns nominative URL for town" do
        router.area_show_url(area).should eq "/gmina/pobiedziska.html"
      end

      it "returns nominative URL for voivodeship" do
        router.area_show_url(voivodeship).should eq "/wojewodztwo/wielkopolskie.html"
      end

      it "works with AreaType and slug" do
        router.area_show_url(AreaType::Town, "pobiedziska").should eq "/gmina/pobiedziska.html"
      end
    end

    describe "#area_post_list_url" do
      it "returns genitive URL for town" do
        router.area_post_list_url(area).should eq "/wpisy-dla/gminy/pobiedziska.html"
      end

      it "returns genitive URL for voivodeship" do
        router.area_post_list_url(voivodeship).should eq "/wpisy-dla/wojewodztwa/wielkopolskie.html"
      end
    end

    describe "#area_gallery_url" do
      it "returns gallery URL for town" do
        router.area_gallery_url(area).should eq "/galeria/gminy/pobiedziska.html"
      end

      it "returns gallery URL for voivodeship" do
        router.area_gallery_url(voivodeship).should eq "/galeria/wojewodztwa/wielkopolskie.html"
      end
    end

    describe "#area_link_url" do
      it "returns show URL by default (AREA_LINK_TARGET=Show)" do
        # Default is Show, so link_url should equal show_url
        router.area_link_url(area).should eq router.area_show_url(area)
      end
    end
  end

  describe "Tag URLs" do
    it "#tag_show_url returns /tag/<slug>.html" do
      router.tag_show_url("rowery").should eq "/tag/rowery.html"
    end

    it "#tag_gallery_url returns /galeria/tag/<slug>.html" do
      router.tag_gallery_url("rowery").should eq "/galeria/tag/rowery.html"
    end

    it "#tag_post_list_url returns /wpisy-dla/tag/<slug>.html" do
      router.tag_post_list_url("rowery").should eq "/wpisy-dla/tag/rowery.html"
    end
  end

  describe "Static URLs" do
    it "#home_url returns /" do
      router.home_url.should eq "/"
    end

    it "#map_url returns /map.html" do
      router.map_url.should eq "/map.html"
    end

    it "#summary_url returns /summary.html" do
      router.summary_url.should eq "/summary.html"
    end

    it "#year_report_url returns /year-<year>.html" do
      router.year_report_url(2024).should eq "/year-2024.html"
    end
  end

  describe "Feed URLs" do
    it "#rss_url returns /feed.rss" do
      router.rss_url.should eq "/feed.rss"
    end

    it "#atom_url returns /feed.atom" do
      router.atom_url.should eq "/feed.atom"
    end

    it "#sitemap_url returns /sitemap.xml" do
      router.sitemap_url.should eq "/sitemap.xml"
    end

    it "#payload_url returns /payload.json" do
      router.payload_url.should eq "/payload.json"
    end
  end

  describe "Index URLs" do
    it "#tags_index_url returns /tagi.html" do
      router.tags_index_url.should eq "/tagi.html"
    end

    it "#towns_index_url returns /gminy.html" do
      router.towns_index_url.should eq "/gminy.html"
    end

    it "#voivodeships_index_url returns /wojewodztwa.html" do
      router.voivodeships_index_url.should eq "/wojewodztwa.html"
    end

    it "#lands_index_url returns /krainy.html" do
      router.lands_index_url.should eq "/krainy.html"
    end
  end

  describe "Legacy URLs" do
    it "#town_view_url delegates to area_show_url" do
      router.town_view_url("pobiedziska").should eq "/gmina/pobiedziska.html"
    end

    it "#voivodeship_view_url delegates to area_show_url" do
      router.voivodeship_view_url("wielkopolskie").should eq "/wojewodztwo/wielkopolskie.html"
    end

    it "#land_view_url delegates to area_show_url (MesoRegion)" do
      router.land_view_url("pojezierze-wielkopolskie").should eq "/region/pojezierze-wielkopolskie.html"
    end
  end
end
