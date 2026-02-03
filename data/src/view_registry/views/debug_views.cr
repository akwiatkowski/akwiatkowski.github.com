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
# View classes used: DynamicView::DebugPostView,
# DebugPostCameraStuffView, DebugPostMissingPhotosExifView
# (loaded via renderer.cr)

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
  # Dependencies: [:posts]
  #
  r.register("Debug: posts", [:posts], priority: 100) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug posts page" }
    ctx.write_output(DynamicView::DebugPostView.new(context: ctx))
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
  # Dependencies: [:exifs]
  #
  r.register("Debug: camera stuff", [:exifs], priority: 101) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug camera stuff page" }
    ctx.write_output(DynamicView::DebugPostCameraStuffView.new(context: ctx))
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
  # Dependencies: [:exifs]
  #
  r.register("Debug: missing EXIF", [:exifs], priority: 102) do |ctx|
    ViewRegistry::Log.debug { "Rendering debug missing EXIF page" }
    ctx.write_output(DynamicView::DebugPostMissingPhotosExifView.new(context: ctx))
  end
end
