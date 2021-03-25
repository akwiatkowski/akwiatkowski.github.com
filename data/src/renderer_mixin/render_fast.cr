require "../views/post_list_view/home_masonry_view"
require "../views/static_view/map_view"

module RendererMixin::RenderFast
  def render_home
    write_output(
      PostListView::HomeMasonryView.new(
        blog: blog,
        url: "/"
      )
    )
  end

  def render_map
    write_output(
      StaticView::MapView.new(
        blog: blog,
        url: "/map"
      )
    )
  end
end
