require "../crystal/src/framework/tremolite"
require "../crystal/src/blog"
require "../crystal/src/service/area_matcher/all"
require "../crystal/src/commands/pipeline/generate_areas_for_posts"

overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

command = Commands::Pipeline::GenerateAreasForPosts.new(overwrite: overwrite)
command.run
