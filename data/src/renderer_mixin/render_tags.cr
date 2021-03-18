module RendererMixin::RenderTags
  def render_tags_pages
    tags_to_render.each do |tag|
      validator.validate_object(tag)
      render_tag_page(tag)
    end
    Log.info { "Tags rendered" }
  end

  def tags_to_render
    return blog.data_manager.not_nil!.tags.not_nil!
  end

  def render_tag_page(tag)
    write_output(PostListView::TagListView.new(blog: @blog, tag: tag))
    write_output(PostListView::TagMasonryView.new(blog: @blog, tag: tag))
  end
end
