require "../../services/map/base"

class PhotoMap::MultiplePostsGridAndRoutesMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @photo_size : Int32,
    @url : String,
    @post_slugs : Array(String),
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
    @fixed_coord_range : CoordRange? = nil
  )
    @map = Map::Base.new(
      blog: @blog,
      photo_size: @photo_size,
      tile: @tile,
      zoom: @zoom,
      post_slugs: @post_slugs,
      fixed_coord_range: @fixed_coord_range,

      # just for this kind of map
      type: Map::MapType::PhotoGrid,
      photo_entities: photo_entities,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPost,
      routes_type: Map::MapRoutesType::Static,
    )
  end

  def photo_entities
    return @blog.data_manager.exif_db.all_flatten_photo_entities.not_nil!.select do |photo_entity|
      @post_slugs.includes?(photo_entity.post_slug)
    end
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
