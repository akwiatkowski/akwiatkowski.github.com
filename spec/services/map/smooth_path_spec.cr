require "../../spec_helper"

describe Map::SmoothPath do
  describe ".to_path" do
    it "returns empty string for empty points" do
      Map::SmoothPath.to_path(Array(Tuple(Int32, Int32)).new).should eq ""
    end

    it "returns M command for single point" do
      result = Map::SmoothPath.to_path([{100, 200}])
      result.should eq "M 100,200"
    end

    it "returns M + L for two points" do
      result = Map::SmoothPath.to_path([{100, 200}, {300, 400}])
      result.should eq "M 100,200 L 300,400"
    end

    it "returns smooth cubic bezier for three points" do
      result = Map::SmoothPath.to_path([{0, 0}, {100, 100}, {200, 0}])
      result.should start_with("M 0,0 C")
      result.should contain("200,0")
      result.should_not contain("L ")
    end

    it "returns smooth cubic bezier for five points" do
      points = [{0, 0}, {50, 100}, {100, 50}, {150, 100}, {200, 0}]
      result = Map::SmoothPath.to_path(points)
      result.should start_with("M 0,0 C")
      # Should end at last point
      result.should end_with("200,0")
      # Should have 4 cubic segments for 5 points
      result.scan(/C /).size.should eq 4
    end

    it "passes through all input points" do
      points = [{10, 20}, {30, 40}, {50, 60}]
      result = Map::SmoothPath.to_path(points)
      result.should contain("10,20")
      result.should contain("30,40")
      result.should contain("50,60")
    end
  end

  describe ".pointer_path" do
    it "returns M + Q path" do
      result = Map::SmoothPath.pointer_path(0, 0, 100, 0)
      result.should start_with("M 0,0 Q")
      result.should end_with("100,0")
    end

    it "produces a curved control point (not on the line)" do
      result = Map::SmoothPath.pointer_path(0, 0, 100, 0)
      # Control point should be offset perpendicular (non-zero y)
      # For horizontal line, perpendicular is vertical
      # Q ctrl_x,ctrl_y target
      match = result.match(/Q (\d+),(-?\d+)/)
      match.should_not be_nil
      ctrl_y = match.not_nil![2].to_i
      ctrl_y.should_not eq 0
    end

    it "works with diagonal lines" do
      result = Map::SmoothPath.pointer_path(0, 0, 100, 100)
      result.should start_with("M 0,0 Q")
      result.should end_with("100,100")
    end
  end
end
