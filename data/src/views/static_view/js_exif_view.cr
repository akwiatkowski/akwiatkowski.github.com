module StaticView
  class JsExifView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
    end

    def add_to_sitemap?
      false # TODO: integrate it later when frontend is ready
    end

    def content
      data = Hash(String, String).new
      return load_html("photos/exif_stats", data)
    end
  end
end
