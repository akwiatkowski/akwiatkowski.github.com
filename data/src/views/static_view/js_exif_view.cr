module StaticView
  class JsExifView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
    end

    def content
      data = Hash(String, String).new
      return load_html("photos/exif_stats", data)
    end
  end
end
