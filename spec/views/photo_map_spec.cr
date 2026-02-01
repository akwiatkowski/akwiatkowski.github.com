require "../spec_helper"

describe PhotoMap do
  describe PhotoMap::IndexView do
    it "exists" do
      PhotoMap::IndexView.should_not be_nil
    end
  end

  describe PhotoMap::GlobalDotsMapSvgView do
    it "exists" do
      PhotoMap::GlobalDotsMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::GlobalGridMapSvgView do
    it "exists" do
      PhotoMap::GlobalGridMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::GlobalGridAndRoutesMapSvgView do
    it "exists" do
      PhotoMap::GlobalGridAndRoutesMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::GlobalAnimatedRoutesMapSvgView do
    it "exists" do
      PhotoMap::GlobalAnimatedRoutesMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::PostRouteMapSvgView do
    it "exists" do
      PhotoMap::PostRouteMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::PostBigMapSvgView do
    it "exists" do
      PhotoMap::PostBigMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::MultiplePostsGridAndRoutesMapSvgView do
    it "exists" do
      PhotoMap::MultiplePostsGridAndRoutesMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::MultiplePhotoEntitiesGridMapSvgView do
    it "exists" do
      PhotoMap::MultiplePhotoEntitiesGridMapSvgView.should_not be_nil
    end
  end

  describe PhotoMap::IdeaRouteMapSvgView do
    it "exists" do
      PhotoMap::IdeaRouteMapSvgView.should_not be_nil
    end
  end
end
