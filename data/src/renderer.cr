require "./renderer_mixin/accessors"

require "./renderer_mixin/render_tags"
require "./renderer_mixin/render_towns"
require "./renderer_mixin/render_voivodeships"
require "./renderer_mixin/render_lands"

require "./renderer_mixin/render_fast"
require "./renderer_mixin/render_special"
require "./renderer_mixin/render_overalls"
require "./renderer_mixin/render_todo"

require "./renderer_mixin/render_photo_maps"
require "./renderer_mixin/render_photo_related"

require "./renderer_mixin/render_post_related"
require "./renderer_mixin/render_post_and_photo_related"
###

require "./views/photo_map_html_view"
require "./views/photo_map_svg_view"
require "./views/land_view"
require "./views/post_gallery_view"
require "./views/post_gallery_stats_view"
require "./views/markdown_page_view"
require "./views/todos_view"
require "./views/pois_view"

class Tremolite::Renderer
  include RendererMixin::Accessors

  include RendererMixin::RenderTags
  include RendererMixin::RenderTowns
  include RendererMixin::RenderVoivodeships
  include RendererMixin::RenderLands

  include RendererMixin::RenderFast
  include RendererMixin::RenderSpecial
  include RendererMixin::RenderOveralls
  include RendererMixin::RenderTodo

  include RendererMixin::RenderPhotoMaps

  include RendererMixin::RenderPhotoRelated
  include RendererMixin::RenderPostRelated
  include RendererMixin::RenderPostRelated

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
      posts = @blog.post_collection.posts.select { |post| post.trip? }
      bicycle_posts = posts.select { |post| post.bicycle? }
      hike_posts = posts.select { |post| post.hike? }

      bicycle_km = bicycle_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum
      hike_km = hike_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_hours = posts.map { |post| post.time_spent }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_km = bicycle_km + hike_km

      s = @blog.data_manager.not_nil!["site.desc"].to_s
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
    @blog.mod_watcher.not_nil!.all_mod_watchers
  end

  # TODO add because it's probably missing
  private def copy_post_photos
    command = "rsync -av #{blog.data_path}/images/ #{blog.public_path}/images/"
    `#{command}`
  end
end
