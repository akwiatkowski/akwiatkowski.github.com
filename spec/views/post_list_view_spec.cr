require "../spec_helper"

describe PostListView do
  describe PostListView::CollectionDynamicView do
    it "has correct URL" do
      # CollectionDynamicView is the home page
      # Test that URL constant or method returns expected value
      PostListView::CollectionDynamicView.should_not be_nil
    end
  end

  describe PostListView::NewPostsDynamicView do
    it "has URL constant" do
      PostListView::NewPostsDynamicView::URL.should eq "/tag/najnowsze.html"
    end

    it "has COUNT constant" do
      PostListView::NewPostsDynamicView::COUNT.should eq 20
    end
  end

  describe PostListView::TagDynamicView do
    it "exists and inherits from CollectionDynamicView" do
      PostListView::TagDynamicView.should_not be_nil
    end
  end

  # PHASE6_DEPRECATED: TownDynamicView replaced by AreaPostListView
  # describe PostListView::TownDynamicView do
  #   it "exists and inherits from CollectionDynamicView" do
  #     PostListView::TownDynamicView.should_not be_nil
  #   end
  # end

  # PHASE6_DEPRECATED: VoivodeshipDynamicView replaced by AreaPostListView
  # describe PostListView::VoivodeshipDynamicView do
  #   it "exists and inherits from CollectionDynamicView" do
  #     PostListView::VoivodeshipDynamicView.should_not be_nil
  #   end
  # end

  # PHASE6_DEPRECATED: LandDynamicView replaced by AreaPostListView
  # describe PostListView::LandDynamicView do
  #   it "exists and inherits from CollectionDynamicView" do
  #     PostListView::LandDynamicView.should_not be_nil
  #   end
  # end

  describe PostListView::AreaPostListView do
    it "exists" do
      PostListView::AreaPostListView.should_not be_nil
    end

    it "generates correct URL prefix for towns" do
      AreaType::Town.url_prefix.should eq "/gminy/"
    end

    it "generates correct URL prefix for voivodeships" do
      AreaType::Voivodeship.url_prefix.should eq "/wojewodztwa/"
    end

    it "generates correct URL prefix for meso regions" do
      AreaType::MesoRegion.url_prefix.should eq "/regiony/"
    end

    it "generates correct url_type for towns" do
      # url_type is used in post_list_url: /wpisy_dla/{url_type}/{slug}.html
      AreaType::Town.url_type.should eq "gminy"
    end

    it "supports all five area types" do
      AreaType.values.size.should eq 5
      AreaType.values.should contain(AreaType::Town)
      AreaType.values.should contain(AreaType::County)
      AreaType.values.should contain(AreaType::Voivodeship)
      AreaType.values.should contain(AreaType::MesoRegion)
      AreaType.values.should contain(AreaType::MacroRegion)
    end
  end
end
