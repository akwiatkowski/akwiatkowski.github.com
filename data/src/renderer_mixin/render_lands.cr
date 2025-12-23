require "../views/post_list_view/all"
require "../views/model_view/lands_index_view"

module RendererMixin::RenderLands
  def render_lands_pages
    lands_to_render.each do |land|
      validator.validate_object(land)
      render_land_page(land)
    end
    Log.info { "Lands rendered" }
  end

  def render_lands_index
    view = ModelView::LandsIndexView.new(blog: @blog, url: "/krainy.html")
    write_output(view)
  end

  def lands_to_render
    return blog.data_manager.not_nil!.lands.not_nil!
  end

  def render_land_page(land)
    write_output(PostListView::LandDynamicView.new(blog: blog, land: land))
    # write_output(PostListView::LandListView.new(blog: blog, land: land)) # TODO: deprecated
    # write_output(PostListView::LandMasonryView.new(blog: blog, land: land)) # TODO: deprecated
  end
end
