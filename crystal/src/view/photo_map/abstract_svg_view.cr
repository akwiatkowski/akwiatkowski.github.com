require "../../service/map/base"

class PhotoMap::AbstractSvgView < Tremolite::Views::AbstractView
  Log = ::Log.for(self)

  def initialize(
    @context : RenderContext,
    @url : String,
    @tile : Map::MapTile = Map::MapTile::Ump,
    @zoom : Int32 = Map::DEFAULT_ZOOM,
  )
  end

  # a bit internal at this moment
  def add_to_sitemap?
    return false
  end

  getter :url, :zoom, :context

  def output
    to_svg
  end

  def to_svg
    return @map.to_svg
  end

  # New pipeline-based SVG rendering
  def render_via_pipeline(config : Map::MapConfig, map_context : Map::MapContext) : String
    pipeline = Map::MapPipeline.new(config: config, context: map_context)
    result = pipeline.compute
    Map::Renderer::SvgRenderer.render(result)
  end
end
