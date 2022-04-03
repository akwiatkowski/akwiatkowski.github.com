require "../services/map/base"

class PhotoMapSvgView < Tremolite::Views::AbstractView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @post_slugs : Array(String) = Array(String).new,
    @quant_size : Int32? = nil,
    @dot_radius : Int32 = Map::DEFAULT_DOT_RADIUS,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
    @coord_range : CoordRange? = nil,
    @subtitle : String = "",
    # append towns on map
    @append_towns = true,
    @do_not_crop_routes : Bool = false,
    @photo_entities : Array(PhotoEntity)? = nil,
    @render_routes : Bool = true,
    @render_photos_out_of_route : Bool = false,
    @render_photo_dots : Bool = false,
    @photo_direct_link : Bool = false,
    @animated : Bool = false
  )
    @map = Map::Base.new(
      blog: @blog,
      post_slugs: @post_slugs,
      quant_size: @quant_size.not_nil!,
      dot_radius: @dot_radius,
      coord_range: @coord_range,
      zoom: @zoom,
      do_not_crop_routes: @do_not_crop_routes,
      photo_entities: @photo_entities,
      render_routes: @render_routes,
      render_photos_out_of_route: @render_photos_out_of_route,
      render_photo_dots: @render_photo_dots,
      photo_direct_link: @photo_direct_link,
      animated: @animated,
    )
  end

  getter :zoom

  # a bit internal at this moment
  def add_to_sitemap?
    return false
  end

  getter :url

  def output
    to_svg
  end

  def to_svg
    return @map.to_svg
  end
end
