require "../../services/map/base"

class PhotoMap::MultiplePhotoEntitiesGridMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @photo_size : Int32,
    @url : String,
    @photo_entities : Array(PhotoEntity),
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
  )
    @map = Map::Base.new(
      posts: context.posts,
      photo_size: @photo_size,
      tile: @tile,
      zoom: @zoom,

      # just for this kind of map
      type: Map::MapType::PhotoGrid,
      photo_entities: @photo_entities,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPhoto,
      routes_type: Map::MapRoutesType::None,
    )
  end
end
