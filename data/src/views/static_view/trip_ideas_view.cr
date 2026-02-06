module StaticView
  class TripIdeasView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
    end

    # Trip ideas page uses React and Leaflet for interactive features
    def additional_bundles : Array(String)
      ["leaflet", "react-runtime"]
    end

    def page_css : Array(String)
      ["ideas"]
    end

    def add_to_sitemap?
      true
    end

    def content
      data = Hash(String, String).new
      return load_html("ideas/ideas", data)
    end
  end
end
