require "../crystal/src/tremolite/tremolite"
require "../crystal/src/blog"
require "../crystal/src/commands/tools/list_missing_routes"

command = Commands::Tools::ListMissingRoutes.new
command.run
