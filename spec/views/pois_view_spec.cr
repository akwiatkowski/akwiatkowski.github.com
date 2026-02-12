require "../spec_helper"

describe PoisView do
  it "exists" do
    PoisView.should_not be_nil
  end

  it "has correct URL" do
    PoisView::URL.should eq "/pois.html"
  end
end
