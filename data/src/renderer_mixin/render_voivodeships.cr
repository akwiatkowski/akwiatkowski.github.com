require "../views/post_list_view/voivodeship_list_view"
require "../views/post_list_view/voivodeship_masonry_view"

module RendererMixin::RenderVoivodeships
  def render_voivodeships_pages
    voivodeships_to_render.each do |voivodeship|
      validator.validate_object(voivodeship)
      render_voivodeship_page(voivodeship)
    end
    Log.info { "Voivodeships rendered" }
  end

  def voivodeships_to_render
    return blog.data_manager.not_nil!.voivodeships.not_nil!
  end

  def render_voivodeship_page(voivodeship)
    write_output(PostListView::VoivodeshipListView.new(blog: blog, voivodeship: voivodeship))
    write_output(PostListView::VoivodeshipMasonryView.new(blog: blog, voivodeship: voivodeship))
  end
end
