require "../data/src/services/map/downloader"
require "../data/src/commands/tools/fetch_map_tiles"

zooms = [15]
overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::Tools::FetchMapTiles.new(zooms: zooms, overwrite: overwrite)
command.run
