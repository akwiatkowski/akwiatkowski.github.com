module StaticView
  class JsTimelineView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
    end

    # Timeline uses Leaflet for map in modal and timeline.js for the main functionality
    def additional_bundles : Array(String)
      ["leaflet", "timeline-js"]
    end

    def add_to_sitemap?
      true
    end

    def content
      data = Hash(String, String).new
      return load_html("photos/timeline", data)
    end
  end
end
