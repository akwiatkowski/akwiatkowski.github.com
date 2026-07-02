module StaticView
  class PhotoMapView < BaseView
    Log = ::Log.for(self)

    URL = "/mapa_zdjec.html"

    def initialize(context : RenderContext, @url : String = URL)
      super(context: context, url: @url)
    end

    # Photo map page uses React for UI and Leaflet for map
    def additional_bundles : Array(String)
      ["leaflet", "react-runtime"]
    end

    def title
      "Mapa zdjęć"
    end

    def add_to_sitemap?
      true
    end

    def content
      data = Hash(String, String).new
      return load_html("map/panoramio", data)
    end
  end
end
