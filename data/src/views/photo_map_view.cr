require "../services/map/base"

class PhotoMapView < WidePageView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    # size of small quant - one image per quant
    @quant_width = 0.10,
    # pixel width of @quant_width
    @quant_css_width = 100,
    # append towns on map
    @append_towns = true
  )
  end

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  # w/o header image
  def content
    return inner_html
  end

  # because of absolute positioning we don't want copyright footer here
  def footer
    return ""
  end

  def inner_html
    m = Map::Base.new(
      blog: @blog,
    )

    return m.to_s
  end
end
