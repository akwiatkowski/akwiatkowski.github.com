require "../crystal/src/framework/tremolite"
require "../crystal/src/blog"
require "../crystal/src/service/area_matcher/all"
require "../crystal/src/commands/pipeline/assign_photos_to_areas"

overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::Pipeline::AssignPhotosToAreas.new(overwrite: overwrite)
command.run
