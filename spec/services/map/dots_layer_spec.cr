require "../../spec_helper"

# Replicate the exact algorithm from DotsLayer#photo_entity_to_color for testing
module DotsColorTest
  def self.compute_color(day_of_year : Int32) : {Int32, Int32, Int32}
    phase = (day_of_year.to_f / 365.to_f) * 2.0 * Math::PI

    blue = 255.0 * ((Math.cos(phase) + 1.0) / 2.0)
    green = 255.0 * ((Math.sin(phase) + 1.0) / 2.0)
    red = 0.0
    if day_of_year >= 150 && day_of_year < 350
      red_phase = ((day_of_year - 150).to_f / (350.0 - 150.0)) * Math::PI
      red = 255.0 * (Math.sin(red_phase))
    end

    blue = blue.clamp(0.0, 255.0)
    green = green.clamp(0.0, 255.0)
    red = red.clamp(0.0, 255.0)

    {red.to_i, green.to_i, blue.to_i}
  end
end

describe "DotsLayer color algorithm" do
  it "produces high blue for winter (day ~1)" do
    red, green, blue = DotsColorTest.compute_color(1)
    blue.should be > 200
    red.should eq 0
  end

  it "produces high green for spring (day ~90)" do
    red, green, blue = DotsColorTest.compute_color(90)
    green.should be > 200
  end

  it "produces some red for summer (day ~200)" do
    red, green, blue = DotsColorTest.compute_color(200)
    red.should be > 50
  end

  it "produces peak red for autumn (day ~250)" do
    red, green, blue = DotsColorTest.compute_color(250)
    red.should be > 200
  end

  it "all RGB values are clamped 0-255 for all days" do
    (1..365).each do |day|
      red, green, blue = DotsColorTest.compute_color(day)
      red.should be >= 0
      red.should be <= 255
      green.should be >= 0
      green.should be <= 255
      blue.should be >= 0
      blue.should be <= 255
    end
  end
end
