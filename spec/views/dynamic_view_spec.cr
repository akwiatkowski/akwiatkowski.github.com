require "../spec_helper"

describe DynamicView do
  describe DynamicView::SummaryView do
    it "exists" do
      DynamicView::SummaryView.should_not be_nil
    end
  end

  describe DynamicView::YearStatReportView do
    it "exists" do
      DynamicView::YearStatReportView.should_not be_nil
    end
  end

  describe DynamicView::BurnoutStatView do
    it "exists" do
      DynamicView::BurnoutStatView.should_not be_nil
    end
  end

  describe DynamicView::TownsHistoryView do
    it "exists" do
      DynamicView::TownsHistoryView.should_not be_nil
    end
  end

  describe DynamicView::TownsTimelineView do
    it "exists" do
      DynamicView::TownsTimelineView.should_not be_nil
    end
  end

  describe DynamicView::PortfolioView do
    it "exists" do
      DynamicView::PortfolioView.should_not be_nil
    end
  end

  describe DynamicView::ExifStatsView do
    it "exists" do
      DynamicView::ExifStatsView.should_not be_nil
    end
  end

  describe DynamicView::TimelinePhotoView do
    it "exists" do
      DynamicView::TimelinePhotoView.should_not be_nil
    end
  end

  describe DynamicView::MountainRangePlannerView do
    it "exists (deprecated but still present)" do
      DynamicView::MountainRangePlannerView.should_not be_nil
    end
  end

end

describe DebugView do
  describe DebugView::PostsView do
    it "exists" do
      DebugView::PostsView.should_not be_nil
    end
  end

  describe DebugView::TagStatsView do
    it "exists" do
      DebugView::TagStatsView.should_not be_nil
    end
  end

  describe DebugView::CameraStuffView do
    it "exists" do
      DebugView::CameraStuffView.should_not be_nil
    end
  end

  describe DebugView::MissingExifView do
    it "exists" do
      DebugView::MissingExifView.should_not be_nil
    end
  end
end
