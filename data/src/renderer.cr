require "./renderer_mixin/accessors"

require "./renderer_mixin/render_tags"
require "./renderer_mixin/render_towns"
require "./renderer_mixin/render_voivodeships"
require "./renderer_mixin/render_lands"

require "./renderer_mixin/render_fast"
require "./renderer_mixin/render_special"
require "./renderer_mixin/render_overalls"

require "./renderer_mixin/render_photo_maps"
require "./renderer_mixin/render_photo_related"

require "./renderer_mixin/render_post_related"

###

require "./views/page_view"
require "./views/wide_page_view"
require "./views/wider_page_view"

# TODO refactor views into categories and require category_view
# require "./views/post_list_view"

require "./views/portfolio_view"

require "./views/photo_map_html_view"
require "./views/photo_map_svg_view"
require "./views/planner_view"
require "./views/land_view"
require "./views/post_gallery_view"
require "./views/post_gallery_stats_view"
require "./views/markdown_page_view"
require "./views/todos_view"
require "./views/pois_view"
require "./views/towns_history_view"
require "./views/towns_timeline_view"
require "./views/exif_stats_view"

class Tremolite::Renderer
  include RendererMixin::Accessors

  include RendererMixin::RenderTags
  include RendererMixin::RenderTowns
  include RendererMixin::RenderVoivodeships
  include RendererMixin::RenderLands

  include RendererMixin::RenderFast
  include RendererMixin::RenderSpecial
  include RendererMixin::RenderOveralls

  include RendererMixin::RenderPhotoMaps

  include RendererMixin::RenderPhotoRelated
  include RendererMixin::RenderPostRelated

  def dev_render
    # do nothing
  end

  def copy_assets_and_photos
    copy_assets
    copy_post_photos
  end

  def render_fast_only_post_related
    Log.debug { "render_fast_only_post_related START" }

    render_all_special_views_post_related
    render_all_views_post_related

    render_posts_paginated_lists


    render_pois



    Log.debug { "render_fast_only_post_related DONE" }
  end

  def render_fast_post_and_yaml_related
    Log.debug { "render_fast_post_and_yaml_related START" }

    render_all_special_views_post_and_yaml_related
    render_all_views_post_and_yaml_related

    render_all_model_pages

    ###

    render_towns_history
    render_towns_timeline

    render_todo_routes

    render_towns_index
    render_lands_index

    Log.debug { "render_fast_post_and_yaml_related DONE" }
  end

  def render_post_galleries_for_post(post)
    view_gallery = PostGalleryView.new(blog: @blog, post: post)
    write_output(view_gallery)
    Log.debug { "render_post #{post.slug} PostGalleryView" }

    view_gallery_stats = PostGalleryStatsView.new(blog: @blog, post: post)
    write_output(view_gallery_stats)
    Log.debug { "render_post #{post.slug} PostGalleryStatsView" }
  end

  def render_fast_static_renders_TODO
    render_planner
  end

  def render_planner
    view = PlannerView.new(blog: @blog, url: "/planner")
    write_output(view)
  end

  def render_todo_routes
    todos_all = @blog.data_manager.not_nil!.todo_routes.not_nil!

    # all
    todos = todos_all.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/", prechecked: TodosView::FILTER_CHECKED_STANDARD)
    write_output(view)

    # close - within 150 minutes of train
    todos = todos_all.select { |t| t.close? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/close", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # full_day - 150-270 (2.5-4.5h) minutes of train
    todos = todos_all.select { |t| t.full_day? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/full_day", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # external - >270 (4.5h) minutes of train
    todos = todos_all.select { |t| t.external? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/external", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # touring - longer than 140km
    todos = todos_all.select { |t| t.touring? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/touring", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "from"
    todos = todos_all.sort { |a, b| a.from <=> b.from }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/from", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "transport_total_cost_minutes"
    todos = todos_all.sort { |a, b| a.transport_total_cost_minutes <=> b.transport_total_cost_minutes }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/transport_cost", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # by major town near
    major_towns = @blog.data_manager.not_nil!.transport_pois.not_nil!.select(&.major)
    major_towns.each do |major_town|
      todos = todos_all.select { |todo_route|
        (todo_route.from_poi && todo_route.from_poi.not_nil!.closest_major_name == major_town.name) ||
          (todo_route.to_poi && todo_route.to_poi.not_nil!.closest_major_name == major_town.name)
      }
      url = "/todos/town/#{major_town.name.downcase.gsub(/\s/, "_")}"
      view = TodosView.new(blog: @blog, todos: todos, url: url, prechecked: TodosView::FILTER_CHECKED_ALL)
      write_output(view)
    end

    # notes from markdown
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/todos/notes",
      file: "todo_notes",
      image_url: @blog.data_manager.not_nil!["todos.backgrounds"],
      title: @blog.data_manager.not_nil!["todos.title"],
      subtitle: @blog.data_manager.not_nil!["todos.subtitle"]
    )
    write_output(view)
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
