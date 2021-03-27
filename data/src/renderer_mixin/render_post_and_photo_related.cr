module RendererMixin::RenderPostRelated
  def render_post_galleries_for_post(post)
    view_gallery = PostGalleryView.new(blog: @blog, post: post)
    write_output(view_gallery)
    Log.debug { "render_post #{post.slug} PostGalleryView" }

    view_gallery_stats = PostGalleryStatsView.new(blog: @blog, post: post)
    write_output(view_gallery_stats)
    Log.debug { "render_post #{post.slug} PostGalleryStatsView" }
  end
end
