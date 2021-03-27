module DynamicView
  class MountainRangePlannerView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
      @image_url = @blog.data_manager.not_nil!["planner.backgrounds"].as(String)
    end

    # a bit internal at this moment
    def add_to_sitemap?
      return false
    end

    getter :image_url

    def title
      @blog.data_manager.not_nil!["planner.title"].as(String)
    end

    def content
      data = Hash(String, String).new
      data["header_img"] = image_url
      load_html("planner", data)
    end
  end
end
