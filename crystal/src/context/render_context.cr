# RenderContext provides a clean read-only interface for views to access data
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
#   ctx.posts              # => Array(Tremolite::Post)
#   ctx.site_title         # => String
#   ctx.title_for_page("home")  # => String
#
class RenderContext
  protected getter blog : Tremolite::Blog
  getter router : Router
  @asset_bundle_loader : AssetBundleLoader?
  @route_colors : RouteColors?
  @posts_for_area_cache : Hash(String, Array(Tremolite::Post))?
  @areas_with_posts_cache : Hash(AreaType, Array(AreaEntity))?
  @photo_selector : AreaPhotoSelector?
  @photo_area_cache : PhotoAreaCache?
  @photo_area_cache_initialized : Bool = false

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

  def posts_newest_first : Array(Tremolite::Post)
    blog.post_collection.posts_from_latest
  end

  def published_posts : Array(Tremolite::Post)
    posts.select(&.ready?)
  end

  # ============================================
  # Configuration (from data_manager)
  # ============================================

  protected def data_manager : Tremolite::DataManager
    blog.data_manager.not_nil!
  end

  # Common config values with typed accessors
  def site_title : String
    data_manager["site.title"].to_s
  end

  def site_url : String
    data_manager["site.url"].to_s
  end

  def site_desc : String
    blog.renderer.site_desc
  end

  def site_email : String
    data_manager["site.email"].to_s
  end

  def site_author : String
    data_manager["site.author"].to_s
  end

  def last_updated_at : Time
    blog.post_collection.last_updated_at
  end

  def years : Array(Int32)
    posts.map(&.time).map(&.year).uniq.select { |year| Time.local.year >= year }
  end

  # ============================================
  # Page Data Accessors
  # ============================================

  # Get title for a named page (e.g. "home", "about", "gallery")
  def title_for_page(name : String) : String
    data_manager["#{name}.title"].to_s
  end

  # Get subtitle for a named page
  def subtitle_for_page(name : String) : String
    data_manager["#{name}.subtitle"]?.try(&.to_s) || ""
  end

  # Get background image URL for a named page
  def background_for_page(name : String) : String
    data_manager["#{name}.backgrounds"].to_s
  end

  # Get gallery tag title (e.g. "gallery.rural.title")
  def gallery_tag_title(tag_slug : String) : String?
    data_manager["gallery.#{tag_slug}.title"]?.try(&.to_s)
  end

  # Returns title, subtitle, backgrounds for a page type
  # Usage: header = context.page_header("summary")
  #        header[:title], header[:subtitle], header[:backgrounds]
  def page_header(name : String)
    {
      title:       title_for_page(name),
      subtitle:    subtitle_for_page(name),
      backgrounds: background_for_page(name),
    }
  end

  # ============================================
  # Entity Data
  # ============================================

  def tags
    data_manager.tags.not_nil!
  end

  def train_stations
    data_manager.train_stations.not_nil!
  end

  def ideas
    data_manager.ideas.not_nil!
  end

  def photo_tags
    data_manager.photo_tags.not_nil!
  end

  # ============================================
  # Caches
  # ============================================

  def nav_stats_cache
    data_manager.nav_stats_cache.not_nil!
  end

  def exif_db
    data_manager.exif_db
  end

  def photo_analysis_cache
    data_manager.photo_analysis_cache
  end

  def photo_coord_quant_cache
    data_manager.photo_coord_quant_cache.not_nil!
  end

  def post_coord_quant_cache
    data_manager.post_coord_quant_cache.not_nil!
  end

  def area_data_loader
    data_manager.area_data_loader.not_nil!
  end

  # Get areas of a specific type
  def areas_of_type(type : AreaType) : Array(AreaEntity)
    area_data_loader.areas_of_type(type)
  end

  # Get areas that have posts associated (memoized)
  def areas_with_posts(type : AreaType) : Array(AreaEntity)
    cache = @areas_with_posts_cache ||= Hash(AreaType, Array(AreaEntity)).new
    cache[type] ||= areas_of_type(type).select { |area| posts_for_area(area).size > 0 }
  end

  # Get posts for an area entity (memoized by area_type:slug)
  def posts_for_area(area : AreaEntity) : Array(Tremolite::Post)
    cache = @posts_for_area_cache ||= Hash(String, Array(Tremolite::Post)).new
    key = "#{area.area_type}:#{area.slug}"
    cache[key] ||= posts.select { |post| post.was_in_area?(area) && post.ready? }
  end

  # Shared photo selector (built once, reused across all area views)
  def photo_selector : AreaPhotoSelector
    @photo_selector ||= AreaPhotoSelector.new(posts.flat_map { |p| p.published_photo_entities })
  end

  # Photo-to-area cache (polygon-based, from commands/assign_photos_to_areas.cr)
  # Returns nil if cache directory doesn't exist (command hasn't been run)
  def photo_area_cache : PhotoAreaCache?
    unless @photo_area_cache_initialized
      @photo_area_cache_initialized = true
      cache_dir = File.join(blog.cache_path, "photos_in_area")
      if Dir.exists?(cache_dir)
        lookup = PhotoAreaCache.build_lookup(posts)
        @photo_area_cache = PhotoAreaCache.new(cache_dir, lookup)
      end
    end
    @photo_area_cache
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
  # Rendering Infrastructure
  # ============================================

  def layout_path : String
    blog.layout_path
  end

  def config_path : String
    blog.config_path
  end

  def route_colors : RouteColors
    @route_colors ||= RouteColors.new(config_path)
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

  def markdown_renderer
    blog.markdown_wrapper
  end

  def photo_map_dictionary
    data_manager.photo_map_dictionary.not_nil!
  end

  def output_buffer
    blog.html_buffer
  end

  def logger
    Log
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
  def next_post(post : Tremolite::Post)
    blog.post_collection.next_to(post)
  end

  def prev_post(post : Tremolite::Post)
    blog.post_collection.prev_to(post)
  end

  # Get slugs of towns visited in self-propelled trips
  def visited_town_slugs_selfpropelled : Array(String)
    slugs = Set(String).new
    posts.each do |post|
      next unless post.self_propelled?
      post.town_slugs.each { |slug| slugs << slug }
    end
    slugs.to_a.sort
  end

  # Get AreaEntity towns that have been visited in self-propelled trips
  def visited_town_areas_selfpropelled : Array(AreaEntity)
    slugs = visited_town_slugs_selfpropelled
    areas_of_type(AreaType::Town).select { |area| slugs.includes?(area.slug) }
  end

  # Access the validator (read-only accessor, used by ArticleView)
  def validator
    blog.validator.not_nil!
  end
end
