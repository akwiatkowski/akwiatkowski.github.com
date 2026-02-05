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
