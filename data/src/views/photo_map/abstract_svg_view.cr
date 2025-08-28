require "../../services/map/base"

class PhotoMap::AbstractSvgView < Tremolite::Views::AbstractView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
  )
  end

  # a bit internal at this moment
  def add_to_sitemap?
    return false
  end

  getter :url, :zoom

  def output
    to_svg
  end

  def to_svg
    return @map.to_svg
  end
end
