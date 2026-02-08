require "../../spec_helper"

describe Map::PhotoSelection do
  describe ".day_of_year_to_color" do
    it "returns rgb color string" do
      color = Map::PhotoSelection.day_of_year_to_color(180)
      color.should match(/^rgb\(\d+,\d+,\d+\)$/)
    end

    it "produces seasonal variation" do
      winter = Map::PhotoSelection.day_of_year_to_color(1)
      summer = Map::PhotoSelection.day_of_year_to_color(180)
      winter.should_not eq summer
    end

    it "matches DotsColorTest algorithm" do
      (1..365).each do |day|
        color = Map::PhotoSelection.day_of_year_to_color(day)
        red, green, blue = DotsColorTest.compute_color(day)
        color.should eq "rgb(#{red},#{green},#{blue})"
      end
    end
  end
end
