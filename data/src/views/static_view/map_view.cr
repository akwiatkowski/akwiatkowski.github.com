require "../base_view"

module StaticView
  class MapView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
      @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
    end

    getter :image_url

    def title
      @blog.data_manager.not_nil!["map.title"]
    end

    def content
      data = Hash(String, String).new
      data["header_img"] = image_url
      load_html("map", data)
    end
  end
end
