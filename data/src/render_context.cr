# RenderContext provides a clean interface for views to access data
# without directly coupling to the Blog class internals.
#
# Benefits:
# - Typed accessors instead of hash lookups
# - Easier to mock for testing
# - Clear documentation of what views need
# - Reduces @blog.data_manager.not_nil! boilerplate
#
# Usage:
#   ctx = RenderContext.new(blog)
#   ctx.posts          # => Array(Tremolite::Post)
#   ctx.config["key"]  # => String (from data_manager)
#   ctx.site_title     # => String
#
class RenderContext
  getter blog : Tremolite::Blog

  def initialize(@blog : Tremolite::Blog)
  end

  # ============================================
  # Post Data
  # ============================================

  def posts : Array(Tremolite::Post)
    blog.post_collection.posts
  end

  def posts_from_latest : Array(Tremolite::Post)
    blog.post_collection.posts_from_latest
  end

  def ready_posts : Array(Tremolite::Post)
    posts.select(&.ready?)
  end

  # ============================================
  # Configuration (from data_manager)
  # ============================================

  def config : Tremolite::DataManager
    blog.data_manager.not_nil!
  end

  # Shortcut for config["key"]
  def [](key : String) : String
    config[key].to_s
  end

  def []?(key : String) : String?
    config[key]?.try(&.to_s)
  end

  # Common config values with typed accessors
  def site_title : String
    self["site.title"]
  end

  def site_url : String
    self["site.url"]
  end

  def site_desc : String
    blog.renderer.site_desc
  end

  def site_email : String
    self["site.email"]
  end

  def site_author : String
    self["site.author"]
  end

  def posts_descending : Array(Tremolite::Post)
    posts.sort { |a, b| b.time <=> a.time }
  end

  def last_updated_at : Time
    blog.post_collection.last_updated_at
  end

  def years : Array(Int32)
    posts.map(&.time).map(&.year).uniq.select { |year| Time.local.year >= year }
  end

  # ============================================
  # Entity Data
  # ============================================

  def voivodeships
    config.voivodeships.not_nil!
  end

  def towns
    config.towns.not_nil!
  end

  def lands
    config.lands.not_nil!
  end

  def tags
    config.tags.not_nil!
  end

  # ============================================
  # Caches
  # ============================================

  def nav_stats_cache
    config.nav_stats_cache.not_nil!
  end

  # ============================================
  # Rendering Infrastructure
  # ============================================

  def output_path : String
    blog.@output_path
  end

  def html_buffer
    blog.html_buffer
  end

  def logger
    blog.logger
  end

  # ============================================
  # Helpers for common patterns
  # ============================================

  # Get posts for a specific entity (town, tag, voivodeship, land)
  def posts_for(entity) : Array(Tremolite::Post)
    posts.select { |post| post.was_in?(entity) && post.ready? }
  end

  # Get posts for a specific year
  def posts_for_year(year : Int32) : Array(Tremolite::Post)
    posts.select { |post| post.time.year == year }
  end

  # Count posts for an entity (used in navigation)
  def post_count_for(entity) : Int32
    posts_for(entity).size
  end

  # ============================================
  # View Rendering
  # ============================================

  # Render a view through the blog's renderer
  # This provides a clean interface for registry blocks to output views
  def write_output(view)
    blog.renderer.render_view(view)
  end

  # Access the validator for entity validation
  def validator
    blog.validator.not_nil!
  end
end
