require "../../service/map/base"

# Consolidated view for area maps (voivodeships, filtered posts, tagged photos)
# Replaces: MultiplePostsGridAndRoutesMapSvgView, MultiplePhotoEntitiesGridMapSvgView
class PhotoMap::AreaMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @url : String,
    @config : Map::MapConfig,
    @post_slugs : Array(String) = Array(String).new,
    @photo_entities_override : Array(PhotoEntity)? = nil,
    @tile : Map::MapTile = Map::MapTile::Ump,
  )
    @zoom = @config.zoom

    @map = Map::Base.new(
      posts: context.posts,
      route_colors: context.route_colors,
      photo_size: @config.photo_size,
      tile: @tile,
      zoom: @zoom,
      post_slugs: @post_slugs,
      fixed_coord_range: @config.fixed_coord_range,
      type: @config.type,
      photo_entities: resolved_photo_entities,
      photo_link_to: @config.photo_link_to,
      routes_type: @config.routes_type,
    )
  end

  private def resolved_photo_entities
    if pe = @photo_entities_override
      return pe
    end

    all = context.exif_db.all_flatten_photo_entities.not_nil!
    if @post_slugs.size > 0
      all.select { |pe| @post_slugs.includes?(pe.post_slug) }
    else
      all
    end
  end
end
