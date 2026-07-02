require "./const"

# Lightweight data container for map generation (not RenderContext)
struct Map::MapContext
  getter posts : Array(Tremolite::Post)
  getter photos : Array(PhotoEntity)
  getter routes : Array(PostRouteObject)
  getter route_colors : RouteColors

  def initialize(
    @posts = Array(Tremolite::Post).new,
    @photos = Array(PhotoEntity).new,
    @routes = Array(PostRouteObject).new,
    @route_colors = RouteColors.new("data/config"),
  )
  end

  # Create from RenderContext with optional post slug filtering
  def self.from_render_context(
    ctx : RenderContext,
    post_slugs : Array(String)? = nil,
    photo_entities : Array(PhotoEntity)? = nil,
  ) : MapContext
    all_photos = photo_entities || ctx.exif_db.all_flatten_photo_entities

    if post_slugs && post_slugs.size > 0
      filtered_photos = all_photos.select { |pe| post_slugs.includes?(pe.post_slug) }
      filtered_posts = ctx.posts.select { |p| post_slugs.includes?(p.slug) }
    else
      filtered_photos = all_photos
      filtered_posts = ctx.posts
    end

    new(
      posts: filtered_posts,
      photos: filtered_photos,
      routes: Array(PostRouteObject).new,
      route_colors: ctx.route_colors,
    )
  end

  # Create for standalone routes (ideas, commands)
  def self.for_routes(
    routes : Array(PostRouteObject),
    route_colors : RouteColors,
  ) : MapContext
    new(
      routes: routes,
      route_colors: route_colors,
    )
  end
end
