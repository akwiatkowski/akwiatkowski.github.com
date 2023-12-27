require "../../services/map/base"

class PhotoMap::MultiplePhotoEntitiesGridMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @photo_size : Int32,
    @url : String,
    @photo_entities : Array(PhotoEntity),
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM
  )
    @map = Map::Base.new(
      blog: @blog,
      photo_size: @photo_size,
      tile: @tile,
      zoom: @zoom,

      # just for this kind of map
      type: Map::MapType::PhotoGrid,
      only_in_poland: true,
      photo_entities: @photo_entities,
      render_routes: false,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPhoto,
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
