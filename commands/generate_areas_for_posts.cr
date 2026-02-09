require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/services/area_matcher/all"
require "../data/src/commands/pipeline/generate_areas_for_posts"

overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::Pipeline::GenerateAreasForPosts.new(overwrite: overwrite)
command.run
