require "../../services/map/base"

class PhotoMap::PostBigMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @post : Tremolite::Post,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump
    # TODO: suggested dimension here
  )
    @zoom = autozoom

    @map = Map::Base.new(
      blog: @blog,
      photo_size: Map::DEFAULT_PHOTO_SIZE,
      tile: @tile,
      zoom: @zoom,

      # just for this kind of map
      post_slugs: [@post.slug],
      type: Map::MapType::PhotosAssignedToRoute,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPhoto,
      coord_crop_type: Map::CoordCropType::RouteCrop,

      photo_entities: photo_entities,

      routes_type: Map::MapRoutesType::Static,
      # TODO: unify autozoom
      # coord_range: coord_range,
    )
  end

  def photo_entities
    return @post.all_photo_entities_unsorted.not_nil!
  end

  # sometime I take photos from train and we want to have detailed
  # route map (big zoom) so we must remove photos taken from non route
  # places
  def coord_range
    PostRouteObject.array_to_coord_range(
      array: @post.detailed_routes.not_nil!,
    )
  end

  def autozoom
    # TODO: add dimensions and sort otder (in some cases it's better to have smaller map)
    return Map::TilesLayer.ideal_zoom(
      coord_range: coord_range.not_nil!,
      min_diagonal: 400,
      max_diagonal: 3500,
    ) || Map::DEFAULT_ZOOM
  end

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
