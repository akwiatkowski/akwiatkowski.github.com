require "./page_view"

class MarkdownPageView < PageView
  Log = ::Log.for(self)

  def initialize(
    context : RenderContext,
    @url : String,
    @file : String,
    @image_url : String,
    @title : String,
    @subtitle : String,
  )
    super(context: context, url: @url)
    @data_path = context.data_path.as(String)
    @pages_path = context.pages_path.as(String)
    @path = File.join([@pages_path, "#{@file}.md"])
  end

  def add_to_sitemap?
    true # TODO: ensure if it's ok
  end

  getter :image_url, :title, :subtitle

  def inner_html
    return context.markdown_renderer.to_html(File.read(@path))
  end
end
