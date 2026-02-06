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
  getter router : Router
  @asset_bundle_loader : AssetBundleLoader?

  def initialize(@blog : Tremolite::Blog)
    @router = Router.new
  end

  # Asset bundle loader for the new asset system
  def asset_bundle_loader : AssetBundleLoader?
    @asset_bundle_loader ||= begin
      config_path = File.join(blog.data_path, "config", "asset_bundles.yml")
      if File.exists?(config_path)
        AssetBundleLoader.new(config_path)
      else
        nil
      end
    end
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

  def train_stations
    config.train_stations.not_nil!
  end

  def ideas
    config.ideas.not_nil!
  end

  def portfolios
    config.portfolios.not_nil!
  end

  def photo_tags
    config.photo_tags.not_nil!
  end

  # ============================================
  # Caches
  # ============================================

  def nav_stats_cache
    config.nav_stats_cache.not_nil!
  end

  def exif_db
    config.exif_db
  end

  def photo_coord_quant_cache
    config.photo_coord_quant_cache.not_nil!
  end

  def post_coord_quant_cache
    config.post_coord_quant_cache.not_nil!
  end

  # PHASE6_DEPRECATED: TownPhotoCache replaced by AreaPhotoSelector
  # def town_photo_cache
  #   config.town_photo_cache.not_nil!
  # end

  def area_data_loader
    config.area_data_loader.not_nil!
  end

  # Get areas of a specific type
  def areas_of_type(type : AreaType) : Array(AreaEntity)
    area_data_loader.areas_of_type(type)
  end

  # Get areas that have posts associated
  def areas_with_posts(type : AreaType) : Array(AreaEntity)
    areas_of_type(type).select { |area| posts_for_area(area).size > 0 }
  end

  # Get posts for an area entity
  def posts_for_area(area : AreaEntity) : Array(Tremolite::Post)
    posts.select { |post| post.was_in_area?(area) && post.ready? }
  end

  # Get all external (foreign) areas
  def external_areas : Array(AreaEntity)
    area_data_loader.external_areas
  end

  # Get external areas that have posts associated
  def external_areas_with_posts : Array(AreaEntity)
    external_areas.select { |area| posts_for_external_area(area).size > 0 }
  end

  # Get posts for an external area entity
  def posts_for_external_area(area : AreaEntity) : Array(Tremolite::Post)
    posts.select { |post| post.foreign_slugs.includes?(area.slug) && post.ready? }
  end

  # Get country name for plain text fallback
  def country_name(slug : String) : String?
    area_data_loader.country_name(slug)
  end

  # ============================================
  # Page Metadata
  # ============================================

  # Returns title, subtitle, backgrounds for a page type
  # Usage: meta = context.page_meta("summary")
  #        meta[:title], meta[:subtitle], meta[:backgrounds]
  def page_meta(name : String)
    {
      title:       config["#{name}.title"].to_s,
      subtitle:    config["#{name}.subtitle"]?.try(&.to_s) || "",
      backgrounds: config["#{name}.backgrounds"].to_s,
    }
  end

  # ============================================
  # Rendering Infrastructure
  # ============================================

  def layout_path : String
    blog.layout_path
  end

  def data_path : String
    blog.data_path
  end

  def pages_path : String
    blog.pages_path
  end

  def output_path : String
    blog.@output_path
  end

  def markdown_wrapper
    blog.markdown_wrapper
  end

  def photo_map_dictionary
    config.photo_map_dictionary.not_nil!
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

  # Post navigation
  def next_to(post : Tremolite::Post)
    blog.post_collection.next_to(post)
  end

  def prev_to(post : Tremolite::Post)
    blog.post_collection.prev_to(post)
  end

  # DEPRECATED: Use visited_town_slugs_selfpropelled or visited_town_areas_selfpropelled
  # Towns already visited (for ideas)
  def towns_already_visited_only_selfpropelled
    config.towns_already_visited_only_selfpropelled
  end

  # Get slugs of towns visited in self-propelled trips
  def visited_town_slugs_selfpropelled : Array(String)
    config.visited_town_slugs_selfpropelled
  end

  # Get AreaEntity towns that have been visited in self-propelled trips
  def visited_town_areas_selfpropelled : Array(AreaEntity)
    config.visited_town_areas_selfpropelled
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
