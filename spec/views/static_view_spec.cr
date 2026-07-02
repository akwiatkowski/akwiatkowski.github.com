require "../spec_helper"

describe StaticView do
  describe StaticView::RouteMapView do
    it "exists" do
      StaticView::RouteMapView.should_not be_nil
    end

    it "has URL /mapa_tras.html" do
      StaticView::RouteMapView::URL.should eq "/mapa_tras.html"
    end
  end

  describe StaticView::PhotoMapView do
    it "exists" do
      StaticView::PhotoMapView.should_not be_nil
    end

    it "has URL /mapa_zdjec.html" do
      StaticView::PhotoMapView::URL.should eq "/mapa_zdjec.html"
    end
  end

  describe StaticView::TripIdeasView do
    it "exists" do
      StaticView::TripIdeasView.should_not be_nil
    end

    it "has URL /pomysly_tras.html" do
      StaticView::TripIdeasView::URL.should eq "/pomysly_tras.html"
    end
  end

  describe StaticView::JsTimelineView do
    it "exists" do
      StaticView::JsTimelineView.should_not be_nil
    end

    it "has URL /linia_czasu.html" do
      StaticView::JsTimelineView::URL.should eq "/linia_czasu.html"
    end
  end

  describe StaticView::JsExifView do
    it "exists" do
      StaticView::JsExifView.should_not be_nil
    end

    it "has URL /statystyki_exif.html" do
      StaticView::JsExifView::URL.should eq "/statystyki_exif.html"
    end
  end

  describe StaticView::PhotoPlannerView do
    it "exists" do
      StaticView::PhotoPlannerView.should_not be_nil
    end

    it "has URL /pomysly_dla_zdjec.html" do
      StaticView::PhotoPlannerView::URL.should eq "/pomysly_dla_zdjec.html"
    end
  end
end
