require "../crystal/src/framework/tremolite"
require "../crystal/src/blog"

require "../crystal/src/service/map/base"

generator = Tools::GenerateMapsForIdeas.new
generator.make_it_so
