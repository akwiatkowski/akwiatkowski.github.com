require "../base_view"

module StaticView
  class MapView < BaseView
    URL = "/mapa.html"

    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = URL,
    )
      super(context: context, url: @url)
      meta = context.page_meta("map")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
    end

    getter :image_url, :title

    # Map view uses OpenLayers instead of Leaflet
    def additional_bundles : Array(String)
      ["openlayers"]
    end

    def content
      data = Hash(String, String).new
      data["header_img"] = image_url
      load_html("map", data)
    end

    def add_to_sitemap?
      true
    end
  end
end
