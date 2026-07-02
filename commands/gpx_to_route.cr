require "../crystal/src/tremolite/tremolite"
require "../crystal/src/blog"
require "../crystal/src/commands/pipeline/gpx_to_route"

# Usage: crystal run commands/gpx_to_route.cr -- <input.gpx> <output-slug> [env]
# Produces env/<env>/data/routes/<output-slug>.json (compacted + private-stripped).

input = ARGV[0]?
slug = ARGV[1]?
env = ARGV[2]? || "full"

unless input && slug
  abort "usage: crystal run commands/gpx_to_route.cr -- <input.gpx> <output-slug> [env]"
end

Commands::Pipeline::GpxToRoute.new.run(input_gpx: input, output_slug: slug, env: env)
