require "log"
require "../data/src/services/area_matcher/all"
require "../data/src/commands/tools/test_region_matching"

command = Commands::Tools::TestRegionMatching.new
command.run
