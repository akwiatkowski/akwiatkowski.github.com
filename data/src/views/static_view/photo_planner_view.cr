module StaticView
  class PhotoPlannerView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
    end

    def additional_bundles : Array(String)
      ["leaflet"]
    end

    def page_css : Array(String)
      ["planner"]
    end

    def add_to_sitemap?
      true
    end

    def content
      data = Hash(String, String).new
      return load_html("planner/planner", data)
    end
  end
end
