require "../spec_helper"

describe SpecialView do
  describe SpecialView::RssGenerator do
    it "exists" do
      SpecialView::RssGenerator.should_not be_nil
    end
  end

  describe SpecialView::AtomGenerator do
    it "exists" do
      SpecialView::AtomGenerator.should_not be_nil
    end
  end

  describe SpecialView::PhotosJsonGenerator do
    it "exists" do
      SpecialView::PhotosJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::IdeasJsonGenerator do
    it "exists" do
      SpecialView::IdeasJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::TrainStationsJsonGenerator do
    it "exists" do
      SpecialView::TrainStationsJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::NavStatsJsonGenerator do
    it "exists" do
      SpecialView::NavStatsJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::RedirectView do
    it "exists" do
      SpecialView::RedirectView.should_not be_nil
    end
  end

  describe SpecialView::E2eJsonGenerator do
    it "exists" do
      SpecialView::E2eJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::HomePageJsonGenerator do
    it "exists" do
      SpecialView::HomePageJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::MapJsonGenerator do
    it "exists" do
      SpecialView::MapJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::PhotoGridJsonGenerator do
    it "exists" do
      SpecialView::PhotoGridJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::PhotosMapJsonGenerator do
    it "exists" do
      SpecialView::PhotosMapJsonGenerator.should_not be_nil
    end
  end

  describe SpecialView::TemporaryRedirectView do
    it "exists" do
      SpecialView::TemporaryRedirectView.should_not be_nil
    end
  end

  describe SpecialView::RouteColorsJsGenerator do
    it "exists" do
      SpecialView::RouteColorsJsGenerator.should_not be_nil
    end
  end
end
