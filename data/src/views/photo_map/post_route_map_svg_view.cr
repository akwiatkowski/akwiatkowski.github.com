require "../../services/map/base"

# small route like from strava
class PhotoMap::PostRouteMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  # width of html content
  POST_ROUTE_SVG_WIDTH = 730

  def initialize(
    @blog : Tremolite::Blog,
    @post : Tremolite::Post,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump
    # TODO: suggested dimension here
  )
    @zoom = default_or_autozoom

    @map = Map::Main.new(
      posts: [@post],
      photos: photo_entities,

      type: Map::MapType::PhotoDots,
      photo_link_to: Map::MapPhotoLinkTo::LinkToPhoto,
      coord_crop_type: Map::CoordCropType::RouteCrop,

      routes_type: Map::MapRoutesType::Static,
      # coord_range: coord_range,

      zoom: @zoom,
      custom_width: POST_ROUTE_SVG_WIDTH,
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

  # zoom set in markdown has highest priority
  def default_or_autozoom
    if @post.default_map_zoom
      return @post.default_map_zoom.not_nil!
    else
      autozoom
    end
  end

  def autozoom
    # TODO: add dimensions and sort otder (in some cases it's better to have smaller map)
    return Map::TilesLayer.ideal_zoom(
      coord_range: coord_range.not_nil!,
      min_diagonal: 700,
      max_diagonal: 1600,
      biggest: false
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
