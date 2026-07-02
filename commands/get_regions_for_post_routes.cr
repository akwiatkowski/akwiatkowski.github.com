require "log"
require "../crystal/src/service/area_matcher/all"
require "../crystal/src/commands/tools/test_region_matching"

command = Commands::Tools::TestRegionMatching.new
command.run
