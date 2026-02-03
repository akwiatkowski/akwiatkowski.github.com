require "../../services/map/base"

class PhotoMap::GlobalAnimatedRoutesMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
  )
    @map = Map::Base.new(
      posts: context.posts,
      tile: @tile,
      zoom: @zoom,

      # just for this kind of map
      type: Map::MapType::Blank,
      photo_entities: Array(PhotoEntity).new, # no photos for animated
      photo_link_to: Map::MapPhotoLinkTo::LinkToPost,
      routes_type: Map::MapRoutesType::Animated,
      photo_size: Map::DEFAULT_PHOTO_SIZE,
    )
  end
end
