require "../spec_helper"

describe CoordQuant do
  describe ".round" do
    it "rounds to default quant resolution" do
      result = CoordQuant.round(value: 52.123_f32)
      # DEFAULT_QUANT_RESOLUTION = 0.05
      result.should eq(52.1_f32)
    end

    it "rounds to custom quant resolution" do
      result = CoordQuant.round(value: 52.15_f32, quant: 0.2)
      result.should eq(52.2_f32)
    end

    it "rounds negative values" do
      result = CoordQuant.round(value: -0.15_f32, quant: 0.2)
      result.should eq(-0.2_f32)
    end

    it "rounds zero" do
      result = CoordQuant.round(value: 0.0_f32, quant: 0.2)
      result.should eq(0.0_f32)
    end
  end

  describe "#initialize" do
    it "quantizes lat and lon" do
      cq = CoordQuant.new(lat: 52.123_f32, lon: 16.987_f32, quant: 0.2)
      cq.lat.should eq(CoordQuant.round(value: 52.123_f32, quant: 0.2))
      cq.lon.should eq(CoordQuant.round(value: 16.987_f32, quant: 0.2))
    end
  end

  describe "#<=>" do
    it "sorts by lat first, then lon" do
      a = CoordQuant.new(lat: 52.0, lon: 16.0)
      b = CoordQuant.new(lat: 53.0, lon: 15.0)
      (a <=> b).should eq(-1)
    end

    it "sorts by lon when lat is equal" do
      a = CoordQuant.new(lat: 52.0, lon: 16.0)
      b = CoordQuant.new(lat: 52.0, lon: 17.0)
      (a <=> b).should eq(-1)
    end
  end
end

describe CoordSet do
  describe ".compare" do
    it "returns full overlap for identical sets" do
      quants = [CoordQuant.new(lat: 52.0, lon: 16.0), CoordQuant.new(lat: 53.0, lon: 17.0)]
      result = CoordSet.compare(set: quants, other_set: quants)
      result[:common_size].should eq(2)
      result[:common_factor].should eq(100)
      result[:not_common_size].should eq(0)
    end

    it "returns zero overlap for disjoint sets" do
      set1 = [CoordQuant.new(lat: 52.0, lon: 16.0)]
      set2 = [CoordQuant.new(lat: 54.0, lon: 18.0)]
      result = CoordSet.compare(set: set1, other_set: set2)
      result[:common_size].should eq(0)
      result[:common_factor].should eq(0)
    end

    it "returns partial overlap" do
      shared = CoordQuant.new(lat: 52.0, lon: 16.0)
      set1 = [shared, CoordQuant.new(lat: 53.0, lon: 17.0)]
      set2 = [shared, CoordQuant.new(lat: 54.0, lon: 18.0)]
      result = CoordSet.compare(set: set1, other_set: set2)
      result[:common_size].should eq(1)
      result[:not_common_size].should eq(1)
      result[:common_factor].should eq(50)
    end

    it "handles empty sets without division by zero" do
      result = CoordSet.compare(set: [] of CoordQuant, other_set: [] of CoordQuant)
      result[:common_size].should eq(0)
      result[:common_factor].should eq(0)
    end
  end
end
