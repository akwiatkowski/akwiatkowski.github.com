require "../crystal/src/framework/tremolite"
require "../crystal/src/blog"
require "../crystal/src/commands/pipeline/gpx_rectify"

command = Commands::Pipeline::GpxRectify.new
command.run
