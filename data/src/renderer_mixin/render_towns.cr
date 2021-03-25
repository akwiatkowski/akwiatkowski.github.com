require "../views/post_list_view/town_list_view"
require "../views/post_list_view/town_masonry_view"

module RendererMixin::RenderTowns
  def render_towns_pages
    towns_to_render.each do |town|
      validator.validate_object(town)
      render_town_page(town)
    end
    Log.info { "Towns rendered" }
  end

  def towns_to_render
    return blog.data_manager.not_nil!.towns.not_nil!
  end

  def render_town_page(town)
    write_output(PostListView::TownListView.new(blog: blog, town: town))
    write_output(PostListView::TownMasonryView.new(blog: blog, town: town))
  end
end
