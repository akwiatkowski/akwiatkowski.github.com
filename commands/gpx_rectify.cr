require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/commands/pipeline/gpx_rectify"

command = Commands::Pipeline::GpxRectify.new
command.run
