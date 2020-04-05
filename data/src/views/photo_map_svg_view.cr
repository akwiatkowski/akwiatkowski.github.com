require "../services/map/base"

class PhotoMapSvgView < Tremolite::Views::AbstractView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @post_slugs : Array(String) = Array(String).new,
    @subtitle : String = "",
    # size of small quant - one image per quant
    @quant_width = 0.10,
    # pixel width of @quant_width
    @quant_css_width = 100,
    # append towns on map
    @append_towns = true
  )
  end

  getter :url

  def output
    to_svg
  end

  def to_svg
    m = Map::Base.new(
      blog: @blog,
      post_slugs: @post_slugs,
    )

    return m.to_svg
  end
end
