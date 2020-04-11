require "./spec_helper"
describe CoordRange do
  describe "#overlap_other" do
    it "returns false" do
      cr1 = CoordRange.new(
        lat_from: 0.0,
        lat_to: 1.0,
        lon_from: 0.0,
        lon_to: 1.0
      )

      cr2 = CoordRange.new(
        lat_from: 2.0,
        lat_to: 3.0,
        lon_from: 2.0,
        lon_to: 3.0
      )

      cr1.overlap_other(cr2).should eq false
    end
  end
end
