# Views required for per-post rendering and registry
require "./views/page_view"
require "./views/area_show_view"
require "./views/home_page_view"
require "./views/portfolio_view"
require "./views/new_more_view"
require "./views/post_view/article_view"
require "./views/photo_map/all"
require "./views/gallery_view/all"
require "./views/post_gallery_stats_view"
require "./views/markdown_page_view"
require "./views/pois_view"
require "./views/post_list_view/all"
require "./views/static_view/all"
require "./views/debug_view/all"
require "./views/dynamic_view/all"
require "./views/special_view/all"
require "./views/model_view/all"

class Tremolite::Renderer
  # Late-bound dependencies for custom renderer
  property all_posts : Array(Tremolite::Post)?
  property data_manager : Tremolite::DataManager?
  property mod_watcher : Tremolite::ModWatcher?

  def dev_render
    # do nothing
  end

  def copy_assets_and_photos
    copy_assets
    copy_post_photos
  end

  # overall site desc string
  @site_desc : String?

  def site_desc
    unless @site_desc
      posts = (@all_posts || [] of Tremolite::Post).select { |post| post.trip? }
      bicycle_posts = posts.select { |post| post.bicycle? }
      hike_posts = posts.select { |post| post.hike? }

      bicycle_km = bicycle_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum
      hike_km = hike_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_hours = posts.map { |post| post.time_spent }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_km = bicycle_km + hike_km

      s = @data_manager.not_nil!["site.desc"].to_s
      {
        "total_km"    => total_km.to_i,
        "total_hours" => total_hours.to_i,
        "bicycle_km"  => bicycle_km.to_i,
        "hike_km"     => hike_km.to_i,
      }.each do |key, value|
        s = s.gsub("{{#{key}}}", value.to_s)
      end

      @site_desc = s
    end

    return @site_desc.to_s
  end

  private def clear
    # because there are some not rendered content in public and we
    # cannot allow to be removed
    raise Exception.new("`clear` is disabled")
  end

  # return Array(String) of all ModWatcher keys, posts, ...
  # to decide which renderers to run
  def all_mod_watchers
    @mod_watcher.not_nil!.all_mod_watchers
  end

  # Public interface for RenderContext to render views
  # This wraps the private write_output method from the base renderer
  def render_view(view)
    write_output(view)
  end

  # TODO add because it's probably missing
  private def copy_post_photos
    command = "rsync --mkpath -av #{@data_path}/images/ #{@output_path}/images/"
    `#{command}`
  end
end
