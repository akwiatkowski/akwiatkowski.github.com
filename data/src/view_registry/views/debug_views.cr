# Debug Views
# ===========
#
# These views render debug/development pages showing
# internal data for troubleshooting.
#
# Current views:
# 1. Debug posts - /debug/posts.html (priority: 100)
# 2. Debug camera stuff - /debug/camera_stuff.html (priority: 101)
# 3. Debug missing EXIF - /debug/missing_exif.html (priority: 102)
#
# Dependencies vary:
# - Debug posts: [:posts]
# - Debug camera/EXIF: [:exifs]
#
# Priority: 100+ (lowest priority, runs last)
#
# Source: Extracted from render_post_related.cr and render_photo_related.cr
#
def register_debug_views(r : ViewRegistry)
  # ============================================
  # Debug: Posts
  # ============================================
  #
  # Debug view showing post metadata and status.
  #
  # URL: /debug/posts.html
  # View class: DynamicView::DebugPostView
  #
  # Original code (render_post_related.cr:132-138)
  #
  # Dependencies: [:posts]
  #
  r.register("Debug: posts", [:posts], priority: 100) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug posts page" }
    ctx.blog.renderer.render_debug_posts
  end

  # ============================================
  # Debug: Camera Stuff
  # ============================================
  #
  # Debug view showing camera/lens usage statistics.
  #
  # URL: /debug/camera_stuff.html
  # View class: DynamicView::DebugPostCameraStuffView
  #
  # Original code (render_photo_related.cr:346-349)
  #
  # Dependencies: [:exifs]
  #
  r.register("Debug: camera stuff", [:exifs], priority: 101) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug camera stuff page" }
    ctx.blog.renderer.render_debug_post_camera_stuff
  end

  # ============================================
  # Debug: Missing EXIF
  # ============================================
  #
  # Debug view showing photos with missing EXIF data.
  #
  # URL: /debug/missing_exif.html
  # View class: DynamicView::DebugPostMissingPhotosExifView
  #
  # Original code (render_photo_related.cr:351-354)
  #
  # Dependencies: [:exifs]
  #
  r.register("Debug: missing EXIF", [:exifs], priority: 102) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug missing EXIF page" }
    ctx.blog.renderer.render_debug_post_photos_missing_exif
  end
end
