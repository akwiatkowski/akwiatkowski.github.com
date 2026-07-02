require "../../service/map/base"

# Consolidated view for all global maps (grid, dots, grid+routes, animated)
# Replaces: GlobalGridMapSvgView, GlobalDotsMapSvgView,
#           GlobalGridAndRoutesMapSvgView, GlobalAnimatedRoutesMapSvgView
class PhotoMap::GlobalMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @url : String,
    @config : Map::MapConfig,
    @tile : Map::MapTile = Map::MapTile::Ump,
  )
    @zoom = @config.zoom

    @map = Map::Base.new(
      posts: context.posts,
      route_colors: context.route_colors,
      photo_size: @config.photo_size,
      tile: @tile,
      zoom: @zoom,
      type: @config.type,
      photo_entities: photo_entities,
      photo_link_to: @config.photo_link_to,
      routes_type: @config.routes_type,
      dot_radius: @config.dot_radius,
    )
  end

  def photo_entities
    if @config.type == Map::MapType::Blank
      return Array(PhotoEntity).new
    end
    return context.exif_db.all_flatten_photo_entities.not_nil!
  end
end
