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
end
