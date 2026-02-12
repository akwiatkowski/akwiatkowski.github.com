module StaticView
  class JsExifView < BaseView
    Log = ::Log.for(self)

    URL = "/statystyki_exif.html"

    def initialize(context : RenderContext, @url : String = URL)
      super(context: context, url: @url)
    end

    def page_css : Array(String)
      ["exif_stats"]
    end

    def add_to_sitemap?
      true
    end

    def content
      data = Hash(String, String).new
      return load_html("photos/exif_stats", data)
    end
  end
end
