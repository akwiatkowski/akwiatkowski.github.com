class Commands::Tools::FetchMapTiles
  # Tiles are stored in full env and symlinked from other envs
  TILES_PATH = "env/full/public/local/tiles"

  def initialize(
    @zooms : Array(Int32) = [15],
    @overwrite : Bool = false,
  )
  end

  def run
    @zooms.each do |zoom|
      puts "=== Downloading tiles at zoom #{zoom} ==="
      m = Map::Downloader.new(
        lat_from: 49.20723805555556,
        lat_to: 54.703875000000004,
        lon_from: 14.110069444444443,
        lon_to: 23.88176388888889,
        zoom: zoom,
        overwrite: @overwrite,
      )
      m.make_it_so
    end
    puts "\nDone!"
  end
end
