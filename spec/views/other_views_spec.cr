require "../spec_helper"

describe "Base Views" do
  describe BaseView do
    it "exists" do
      BaseView.should_not be_nil
    end
  end

  describe PageView do
    it "exists" do
      PageView.should_not be_nil
    end
  end

  describe WidePageView do
    it "exists" do
      WidePageView.should_not be_nil
    end
  end

  describe WiderPageView do
    it "exists" do
      WiderPageView.should_not be_nil
    end
  end

  describe WidestPageView do
    it "exists" do
      WidestPageView.should_not be_nil
    end
  end

  describe MarkdownPageView do
    it "exists" do
      MarkdownPageView.should_not be_nil
    end
  end
end

describe ModelView do
  describe ModelView::TownsIndexView do
    it "exists" do
      ModelView::TownsIndexView.should_not be_nil
    end
  end

end

describe PostView do
  describe PostView::ArticleView do
    it "exists" do
      PostView::ArticleView.should_not be_nil
    end
  end
end

describe "Standalone Views" do
  describe PoisView do
    it "exists" do
      PoisView.should_not be_nil
    end
  end

  describe PostGalleryStatsView do
    it "exists" do
      PostGalleryStatsView.should_not be_nil
    end
  end
end

describe PortfolioView do
  it "exists" do
    PortfolioView.should_not be_nil
  end
end

describe RenderContext do
  it "exists" do
    RenderContext.should_not be_nil
  end
end
