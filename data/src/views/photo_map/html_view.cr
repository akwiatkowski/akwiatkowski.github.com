require "../../services/map/base"

class PhotoMap::HtmlView < WidePageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @svg_url : String,
    @subtitle : String = ""
  )
  end

  # a bit internal at this moment
  def add_to_sitemap?
    return false
  end

  getter :subtitle

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  # w/o header image
  def content
    return "<embed src='#{@svg_url}' />"
  end

  # because of absolute positioning we don't want copyright footer here
  def footer
    return ""
  end
end
