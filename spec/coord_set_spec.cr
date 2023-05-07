require "./spec_helper"
describe CoordSet do
  describe "#initialize" do
    it "can be created using array of arrays and round coords using 0.05 quant" do
      quant = 0.05
      input_array = [
        [50.2942272183, 16.8805720378],
        [50.2898094524, 16.8738824409],
        [50.2693644818, 16.8812623713],
        [50.258554928, 16.8597023562],
        [50.2331147622, 16.8417226709],
        [50.2081663627, 16.8323196005],
      ]
      input_set = CoordSet.new(
        coords_array: input_array,
        quant: quant
      )

      control_array = [
        [50.2, 16.85],
        [50.25, 16.85],
        [50.25, 16.9],
        [50.3, 16.85],
        [50.3, 16.9],
      ]
      control_set = CoordSet.new(
        coords_array: control_array,
        quant: quant
      )

      input_set.should eq control_set
    end

    it "can be created using array of arrays and round coords using 1.0 quant" do
      quant = 1.0
      input_array = [
        [50.2942272183, 16.8805720378],
        [50.2898094524, 16.8738824409],
        [50.2693644818, 16.8812623713],
        [50.258554928, 16.8597023562],
        [50.2331147622, 16.8417226709],
        [50.2081663627, 16.8323196005],
      ]
      input_set = CoordSet.new(
        coords_array: input_array,
        quant: quant
      )

      control_array = [
        [50.0, 17.0],
      ]
      control_set = CoordSet.new(
        coords_array: control_array,
        quant: quant
      )

      input_set.should eq control_set
    end
  end

  describe "#compare" do
    it "can be created using array of arrays and round coords using 1.0 quant" do
      quant = 0.5
      input_array = [
        [10.0, 10.0],
        [10.5, 10.0],
        [10.0, 10.5],
        [10.5, 10.5],
      ]
      input_set = CoordSet.new(
        coords_array: input_array,
        quant: quant
      )

      control_array = [
        [10.0, 10.0],
        [10.5, 10.0],
      ]
      control_set = CoordSet.new(
        coords_array: control_array,
        quant: quant
      )

      compare_result = input_set.compare(control_set)
      compare_result[:not_common_size].should eq 2
      compare_result[:common_size].should eq 2
      compare_result[:common_factor].should eq 50
    end
  end
end
