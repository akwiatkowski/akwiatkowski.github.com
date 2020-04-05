require "../services/map/base"

class PhotoMapSvgView < Tremolite::Views::AbstractView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @post_slugs : Array(String) = Array(String).new,
    @quant_size : Int32? = nil,
    @coord_range : Map::CoordRange?= nil,
    @subtitle : String = "",
    # append towns on map
    @append_towns = true
  )
  end

  getter :url

  def output
    to_svg
  end

  def to_svg
    # TODO check if it's possible to compact method params
    if @quant_size
      m = Map::Base.new(
        blog: @blog,
        post_slugs: @post_slugs,
        quant_size: @quant_size.not_nil!,
        coord_range: @coord_range,
      )
    else
      m = Map::Base.new(
        blog: @blog,
        post_slugs: @post_slugs,
        coord_range: @coord_range,
      )
    end

    return m.to_svg
  end
end
