require "../crystal/src/tremolite/tremolite"
require "../crystal/src/blog"

require "../crystal/src/services/map/base"

generator = Tools::GenerateMapsForIdeas.new
generator.make_it_so
