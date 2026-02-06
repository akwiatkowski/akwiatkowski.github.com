require "../spec_helper"

describe StaticView do
  describe StaticView::RouteMapView do
    it "exists" do
      StaticView::RouteMapView.should_not be_nil
    end
  end

  describe StaticView::TripIdeasView do
    it "exists" do
      StaticView::TripIdeasView.should_not be_nil
    end
  end

  describe StaticView::JsTimelineView do
    it "exists" do
      StaticView::JsTimelineView.should_not be_nil
    end
  end

  describe StaticView::PhotoMapView do
    it "exists" do
      StaticView::PhotoMapView.should_not be_nil
    end
  end

  describe StaticView::JsExifView do
    it "exists" do
      StaticView::JsExifView.should_not be_nil
    end
  end

  describe StaticView::PhotoPlannerView do
    it "exists" do
      StaticView::PhotoPlannerView.should_not be_nil
    end
  end

  describe StaticView::MoreView do
    it "exists" do
      StaticView::MoreView.should_not be_nil
    end
  end
end
