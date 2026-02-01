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
    view = ModelView::TownsIndexView.new(blog: @blog, url: "/gminy.html")
    write_output(view)
  end

  def towns_to_render
    return blog.data_manager.not_nil!.towns.not_nil!
  end

  def render_town_page(town)
    write_output(PostListView::TownDynamicView.new(blog: blog, town: town))
  end
end
