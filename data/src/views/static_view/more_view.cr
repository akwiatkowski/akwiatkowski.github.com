require "../markdown_page_view"

module StaticView
  class MoreView < MarkdownPageView
    URL = "/wiecej.html"

    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
    )
      @url = URL
      @file = "more"
      @image_url = @blog.data_manager.not_nil!["more.backgrounds"]
      @title = @blog.data_manager.not_nil!["more.title"]
      @subtitle = @blog.data_manager.not_nil!["more.subtitle"]
      @data_path = @blog.data_path.as(String)
      @pages_path = @blog.pages_path.as(String)
      @path = File.join([@pages_path, "#{@file}.md"])
    end
  end
end
