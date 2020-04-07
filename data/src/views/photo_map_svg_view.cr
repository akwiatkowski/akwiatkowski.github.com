require "../services/map/base"

class PhotoMapSvgView < Tremolite::Views::AbstractView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @post_slugs : Array(String) = Array(String).new,
    @quant_size : Int32? = nil,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
    @coord_range : CoordRange? = nil,
    @subtitle : String = "",
    # append towns on map
    @append_towns = true,
    @do_not_crop_routes : Bool = false
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
        zoom: @zoom,
        do_not_crop_routes: @do_not_crop_routes,
      )
    else
      m = Map::Base.new(
        blog: @blog,
        post_slugs: @post_slugs,
        coord_range: @coord_range,
        zoom: @zoom,
        do_not_crop_routes: @do_not_crop_routes,
      )
    end

    return m.to_svg
  end
end
