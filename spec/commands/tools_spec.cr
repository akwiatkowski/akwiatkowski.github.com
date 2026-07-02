require "../spec_helper"
require "../../data/src/commands/tools/list_missing_routes"
require "../../data/src/commands/tools/fetch_map_tiles"

describe Commands::Tools::ListMissingRoutes do
  it "can be instantiated with default env" do
    cmd = Commands::Tools::ListMissingRoutes.new
    cmd.should be_a Commands::Tools::ListMissingRoutes
  end

  it "can be instantiated with custom env" do
    cmd = Commands::Tools::ListMissingRoutes.new(env: "dev")
    cmd.should be_a Commands::Tools::ListMissingRoutes
  end
end

describe Commands::Tools::FetchMapTiles do
  describe "TILES_PATH" do
    it "points to the shared input tiles store" do
      Commands::Tools::FetchMapTiles::TILES_PATH.should eq File.join(ENV["HOME"], "projects", "llm", "input", "tiles")
    end
  end

  it "can be instantiated with default params" do
    cmd = Commands::Tools::FetchMapTiles.new
    cmd.should be_a Commands::Tools::FetchMapTiles
  end

  it "can be instantiated with custom zooms" do
    cmd = Commands::Tools::FetchMapTiles.new(zooms: [10, 12])
    cmd.should be_a Commands::Tools::FetchMapTiles
  end
end
