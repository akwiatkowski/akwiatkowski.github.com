require "../page_view"

module DynamicView
  class SummaryView < PageView
    Log = ::Log.for(self)

    getter :image_url, :title, :subtitle

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("summary")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
      @subtitle = meta[:subtitle].as(String)
    end

    # not so important for SEO
    def add_to_sitemap?
      return false
    end

    def inner_html
      posts_string = ""

      context.posts.each do |post|
        data = Hash(String, String).new
        data["post.url"] = post.url
        data["post.date"] = post.date
        data["post.title"] = post.title
        data["post.subtitle"] = post.subtitle
        posts_string += load_html("summary_item", data)
        posts_string += "\n"
      end

      data = Hash(String, String).new
      data["summary.content"] = posts_string
      load_html("summary", data)
    end
  end
end
