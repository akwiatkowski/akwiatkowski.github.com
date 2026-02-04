module StaticView
  class JsPanoramioView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
    end

    # Panoramio page uses React for UI and Leaflet for map
    def additional_bundles : Array(String)
      ["leaflet", "react-runtime"]
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
