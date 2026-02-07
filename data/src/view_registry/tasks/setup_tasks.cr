# Setup Tasks
# ===========
#
# These tasks run at the very beginning of the render process.
# They prepare the environment before any views are rendered.
#
# Current tasks:
# 1. Dev render - development/testing hooks (priority: 1)
# 2. Copy assets - rsync assets and photos to output (priority: 2)
#
# These tasks have NO dependencies (empty array) because they
# should ALWAYS run regardless of what changed.
#
# Priority: 1-2 (runs before everything else)
#
# Source: Extracted from Blog#render in data/src/blog.cr:162-169
#
def register_setup_tasks(r : ViewRegistry)
  # ============================================
  # Task: Dev Render
  # ============================================
  #
  # Calls renderer.dev_render which is a hook for development/testing.
  # In production this is usually empty.
  #
  # Original code (blog.cr:162):
  #   renderer.dev_render
  #
  # Dependencies: none (always runs)
  # Priority: 1 (first thing to run)
  #
  r.task("Setup: dev render", [] of Symbol, priority: 1) do |ctx|
    ViewRegistry::Log.debug { "Running dev_render hook" }
    ctx.dev_render
  end

  # ============================================
  # Task: Copy Assets and Photos
  # ============================================
  #
  # Uses rsync to copy static assets and photos to output directory.
  # This is fast because rsync only copies changed files.
  #
  # Original code (blog.cr:169):
  #   renderer.copy_assets_and_photos
  #
  # Dependencies: none (always runs)
  # Priority: 2 (after dev_render, before cache refresh)
  #
  r.task("Setup: copy assets", [] of Symbol, priority: 2) do |ctx|
    ViewRegistry::Log.debug { "Copying assets and photos via rsync" }
    ctx.copy_assets_and_photos
  end

  # ============================================
  # Task: Generate route_colors.js
  # ============================================
  #
  # Reads data/config/route_colors.yml and generates /js/self/route_colors.js
  # with window.ROUTE_STYLES for all map pages.
  #
  # Dependencies: none (always runs - reads static config)
  # Priority: 3 (after copy_assets so it won't be overwritten)
  #
  r.task("Setup: route colors", [] of Symbol, priority: 3) do |ctx|
    ViewRegistry::Log.debug { "Generating route_colors.js from config" }
    ctx.write_output(SpecialView::RouteColorsJsGenerator.new(context: ctx))
  end
end
