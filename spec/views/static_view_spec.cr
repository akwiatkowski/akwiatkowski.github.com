require "../spec_helper"

describe StaticView do
  describe StaticView::MapView do
    it "exists" do
      StaticView::MapView.should_not be_nil
    end
  end

  describe StaticView::JsIdeasView do
    it "exists" do
      StaticView::JsIdeasView.should_not be_nil
    end
  end

  describe StaticView::JsTimelineView do
    it "exists" do
      StaticView::JsTimelineView.should_not be_nil
    end
  end

  describe StaticView::JsPanoramioView do
    it "exists" do
      StaticView::JsPanoramioView.should_not be_nil
    end
  end

  describe StaticView::JsExifView do
    it "exists" do
      StaticView::JsExifView.should_not be_nil
    end
  end

  describe StaticView::JsBicyclePlannerView do
    it "exists" do
      StaticView::JsBicyclePlannerView.should_not be_nil
    end
  end

  describe StaticView::MoreView do
    it "exists" do
      StaticView::MoreView.should_not be_nil
    end
  end
end
