module DynamicView
  class MountainRangePlannerView < BaseView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("planner")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
    end

    # a bit internal at this moment
    def add_to_sitemap?
      return false
    end

    getter :image_url, :title

    def content
      data = Hash(String, String).new
      data["header_img"] = image_url
      load_html("planner", data)
    end
  end
end
