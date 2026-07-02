require "../../spec_helper"

describe Map::MapCoordRange do
  describe "#overlap_other" do
    it "returns false for non-overlapping rectangles" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 10, y_to: 10)
      r2 = Map::MapCoordRange.new(x_from: 20, y_from: 20, x_to: 30, y_to: 30)
      r1.overlap_other(r2).should be_false
    end

    it "returns false for non-overlapping reversed order" do
      r1 = Map::MapCoordRange.new(x_from: 20, y_from: 20, x_to: 30, y_to: 30)
      r2 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 10, y_to: 10)
      r1.overlap_other(r2).should be_false
    end

    it "returns true when one contains the other" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 100, y_to: 100)
      r2 = Map::MapCoordRange.new(x_from: 20, y_from: 20, x_to: 30, y_to: 30)
      r1.overlap_other(r2).should be_true
    end

    it "returns true for partial overlap" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 20, y_to: 20)
      r2 = Map::MapCoordRange.new(x_from: 10, y_from: 10, x_to: 30, y_to: 30)
      r1.overlap_other(r2).should be_true
    end

    it "returns true for touching edges" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 10, y_to: 10)
      r2 = Map::MapCoordRange.new(x_from: 10, y_from: 10, x_to: 20, y_to: 20)
      r1.overlap_other(r2).should be_true
    end

    it "returns false for X-only overlap (no Y)" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 20, y_to: 10)
      r2 = Map::MapCoordRange.new(x_from: 5, y_from: 20, x_to: 15, y_to: 30)
      r1.overlap_other(r2).should be_false
    end

    it "returns false for Y-only overlap (no X)" do
      r1 = Map::MapCoordRange.new(x_from: 0, y_from: 0, x_to: 10, y_to: 20)
      r2 = Map::MapCoordRange.new(x_from: 20, y_from: 5, x_to: 30, y_to: 15)
      r1.overlap_other(r2).should be_false
    end
  end

  describe "#x_center and #y_center" do
    it "returns midpoint" do
      r = Map::MapCoordRange.new(x_from: 10, y_from: 20, x_to: 30, y_to: 40)
      r.x_center.should eq 20
      r.y_center.should eq 30
    end
  end
end
