require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/services/area_matcher/all"
require "../data/src/commands/pipeline/assign_photos_to_areas"

overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::Pipeline::AssignPhotosToAreas.new(overwrite: overwrite)
command.run
