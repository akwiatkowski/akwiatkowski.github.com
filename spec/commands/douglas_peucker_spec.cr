require "../spec_helper"
require "json"
require "yaml"
require "file_utils"
require "log"
require "../../crystal/src/services/area_matcher/all"
require "../../crystal/src/commands/pipeline/generate_polygon_json"

describe DouglasPeucker do
  describe ".simplify" do
    it "returns coords unchanged when 2 or fewer points" do
      coords = [[0.0, 0.0], [1.0, 1.0]]
      result = DouglasPeucker.simplify(coords, 0.01)
      result.should eq coords
    end

    it "returns single point unchanged" do
      coords = [[0.0, 0.0]]
      result = DouglasPeucker.simplify(coords, 0.01)
      result.should eq coords
    end

    it "simplifies collinear points to endpoints" do
      # Three points on a straight line
      coords = [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0]]
      result = DouglasPeucker.simplify(coords, 0.01)
      result.should eq [[0.0, 0.0], [1.0, 1.0]]
    end

    it "preserves points that deviate beyond tolerance" do
      # Triangle - middle point far from line
      coords = [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]]
      result = DouglasPeucker.simplify(coords, 0.01)
      result.size.should eq 3
    end

    it "removes points within tolerance" do
      # Middle point barely off the line
      coords = [[0.0, 0.0], [0.5, 0.001], [1.0, 0.0]]
      result = DouglasPeucker.simplify(coords, 0.01)
      result.should eq [[0.0, 0.0], [1.0, 0.0]]
    end

    it "handles larger polygon with mixed deviations" do
      # Square-ish polygon with extra points on edges
      coords = [
        [0.0, 0.0],
        [0.5, 0.0001], # nearly on edge, should be removed
        [1.0, 0.0],
        [1.0, 0.5],
        [1.0, 1.0],
        [0.0, 1.0],
        [0.0, 0.0],
      ]
      result = DouglasPeucker.simplify(coords, 0.001)
      # The near-collinear point should be removed
      result.size.should be < coords.size
    end
  end
end

describe Commands::Pipeline::GeneratePolygonJson do
  describe "AREA_TYPES" do
    it "maps all 5 area type names" do
      types = Commands::Pipeline::GeneratePolygonJson::AREA_TYPES
      types.keys.should eq ["towns", "counties", "voivodeships", "meso_regions", "macro_regions"]
    end
  end

  describe "OUTPUT_DIR" do
    it "points to data/config/polygons" do
      Commands::Pipeline::GeneratePolygonJson::OUTPUT_DIR.should eq "data/config/polygons"
    end
  end
end
