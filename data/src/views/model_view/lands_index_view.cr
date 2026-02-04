require "../page_view"

# ##############################################################################
# PHASE6_DEPRECATED - DO NOT REMOVE
# ##############################################################################
# This view uses LandEntity which is deprecated.
# TODO: Migrate to use AreaEntity with AreaType::MesoRegion
# Registration commented out in view_registry/views/index_views.cr
# ##############################################################################

module ModelView
  class LandsIndexView < PageView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("lands")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
      @subtitle = meta[:subtitle].as(String)
    end

    def add_to_sitemap?
      true
    end

    getter :image_url, :title, :subtitle

    def inner_html
      s = "<ol>"

      context.lands.each do |land|
        s += land_element(land)
      end

      return s
    end

    def land_element(land)
      s = "<li><a href=\"#{land.view_url}\">#{land.name}</a>"
      s += "</li>\n"
      return s
    end
  end
end
