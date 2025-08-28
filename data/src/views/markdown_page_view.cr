require "./page_view"

class MarkdownPageView < PageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @file : String,
    @image_url : String,
    @title : String,
    @subtitle : String,
  )
    @data_path = @blog.data_path.as(String)
    @pages_path = @blog.pages_path.as(String)
    @path = File.join([@pages_path, "#{file}.md"])
  end

  getter :image_url, :title, :subtitle

  def inner_html
    return @blog.markdown_wrapper.to_html(File.read(@path))
  end
end
