require "../../services/map/base"

class PhotoMap::GlobalGridMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @photo_size : Int32,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
  )
    @map = Map::Base.new(
      posts: context.posts,
      route_colors: context.route_colors,
      photo_size: @photo_size,
      tile: @tile,
      zoom: @zoom,

      # just for this kind of map
      type: Map::MapType::PhotoGrid,
      photo_entities: photo_entities,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPost,
      routes_type: Map::MapRoutesType::None,
    )
  end

  def photo_entities
    return context.exif_db.all_flatten_photo_entities.not_nil!
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
