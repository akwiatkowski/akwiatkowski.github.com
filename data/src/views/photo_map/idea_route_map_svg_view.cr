require "../../services/map/base"

# small route like from strava
class PhotoMap::IdeaRouteMapSvgView < PhotoMap::AbstractSvgView
  Log = ::Log.for(self)

  # width of html content
  IDEA_ROUTE_SVG_WIDTH = POST_ROUTE_SVG_WIDTH

  def initialize(
    @blog : Tremolite::Blog,
    @idea : IdeaEntity,
    @tile : Map::MapTile = Map::MapTile::Ump,
  )
    @url = @idea.photo_map_url
    @zoom = 9
  end

  def map
    return Map::Main.new(
      routes: routes,
      autozoom_width: 700,
      zoom: 9
    )
  end

  def routes
    return @idea.routes(
      blog: @blog,
      type: "bicycle"
    )
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
    return map.to_svg
  end
end
