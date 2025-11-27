require "../views/post_list_view/town_list_view"
require "../views/post_list_view/town_masonry_view"

require "../views/model_view/towns_index_view"

module RendererMixin::RenderTowns
  def render_towns_pages
    towns_to_render.each do |town|
      validator.validate_object(town)
      render_town_page(town)
    end
    Log.info { "Towns rendered" }
  end

  def render_towns_index
    view = ModelView::TownsIndexView.new(blog: @blog, url: "/towns")
    write_output(view)
  end

  def towns_to_render
    return blog.data_manager.not_nil!.towns.not_nil!
  end

  def render_town_page(town)
    write_output(PostListView::TownDynamicView.new(blog: blog, town: town))
    # write_output(PostListView::TownListView.new(blog: blog, town: town)) # DEPRECATED
    # write_output(PostListView::TownMasonryView.new(blog: blog, town: town)) # DEPRECATED
  end
end
