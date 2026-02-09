require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/commands/tools/list_missing_routes"

command = Commands::Tools::ListMissingRoutes.new
command.run
