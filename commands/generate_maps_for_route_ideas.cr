require "../../tremolite/src/tremolite"
require "../data/src/blog"

require "../data/src/services/map/base"

generator = Tools::GenerateMapsForIdeas.new
generator.make_it_so
