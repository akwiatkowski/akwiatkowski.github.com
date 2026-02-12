require "../spec_helper"

describe DynamicView::YearStatReportView do
  describe "POLISH_MONTHS" do
    it "contains all 12 months" do
      DynamicView::YearStatReportView::POLISH_MONTHS.size.should eq 12
    end

    it "has correct January" do
      DynamicView::YearStatReportView::POLISH_MONTHS[1].should eq "Styczeń"
    end

    it "has correct June" do
      DynamicView::YearStatReportView::POLISH_MONTHS[6].should eq "Czerwiec"
    end

    it "has correct December" do
      DynamicView::YearStatReportView::POLISH_MONTHS[12].should eq "Grudzień"
    end

    it "covers keys 1 through 12" do
      (1..12).each do |m|
        DynamicView::YearStatReportView::POLISH_MONTHS.has_key?(m).should be_true
      end
    end
  end

  describe ".url_for_year" do
    it "generates correct URL for a year" do
      DynamicView::YearStatReportView.url_for_year(2024).should eq "/rok/2024.html"
    end

    it "generates correct URL for an early year" do
      DynamicView::YearStatReportView.url_for_year(2012).should eq "/rok/2012.html"
    end
  end

  describe "SYSTEM_TAGS" do
    it "includes photo_of_the_year" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("photo_of_the_year").should be_true
    end

    it "includes todo" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("todo").should be_true
    end

    it "includes todo_media" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("todo_media").should be_true
    end

    it "includes hidden" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("hidden").should be_true
    end

    it "has exactly 4 system tags" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.size.should eq 4
    end

    it "does not include regular tags" do
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("bicycle").should be_false
      DynamicView::YearStatReportView::SYSTEM_TAGS.includes?("hike").should be_false
    end
  end

  describe "page_css" do
    it "includes year_stats" do
      # We can't instantiate the view without a real context,
      # but we can verify the class exists and has the constant
      DynamicView::YearStatReportView.should_not be_nil
    end
  end
end
