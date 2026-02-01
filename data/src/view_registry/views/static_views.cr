# Static Views
# ============
#
# These views render static/informational pages with minimal
# data processing. They include markdown-based pages and
# JS-heavy pages that load data client-side.
#
# Current views:
# 1. More page - /wiecej.html (priority: 90)
# 2. About page - /o_mnie.html (priority: 91)
# 3. English page - /en/index.html (priority: 92)
# 4. JS Ideas page - /pomysly.html (priority: 93)
# 5. JS Timeline page - /linia_czasu.html (priority: 94)
# 6. JS Panoramio page - /mapa2.html (priority: 95)
# 7. JS Exif Stats page - /exif_statystyki.html (priority: 96)
# 8. JS Bicycle Planner - /pomysly2.html (priority: 97)
#
# Dependencies: [] (empty = always run)
# - These pages are simple and don't depend on specific data changes
# - They're re-rendered on every build for simplicity
#
# Priority: 90-99 (near the end, low priority)
#
# Source: Extracted from render_fast.cr (render_fast_static_renders)
# and render_overalls.cr (render_js_pages)
#
def register_static_views(r : ViewRegistry)
  # ============================================
  # View: More Page
  # ============================================
  #
  # Renders the "more" page with additional site information.
  #
  # URL: /wiecej.html
  # View class: StaticView::MoreView
  #
  # Original code (render_fast.cr:73-76):
  #   def render_more
  #     view = StaticView::MoreView.new(blog: blog)
  #     write_output(view)
  #   end
  #
  # Called from: render_fast_static_renders (render_overalls.cr:26)
  #
  # Dependencies: [] (always runs)
  #
  r.register("Static: more page", [] of Symbol, priority: 90) do |ctx|
    ViewRegistry::Log.debug { "Rendering more page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_more
  end

  # ============================================
  # View: About Page
  # ============================================
  #
  # Renders the "about me" page from markdown.
  #
  # URL: /o_mnie.html
  # View class: MarkdownPageView
  #
  # Original code (render_fast.cr:78-88):
  #   def render_about
  #     view = MarkdownPageView.new(blog: blog, ...)
  #     write_output(view)
  #   end
  #
  # Called from: render_fast_static_renders (render_overalls.cr:27)
  #
  # Dependencies: [] (always runs)
  #
  r.register("Static: about page", [] of Symbol, priority: 91) do |ctx|
    ViewRegistry::Log.debug { "Rendering about page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_about
  end

  # ============================================
  # View: English Page
  # ============================================
  #
  # Renders the English language landing page from markdown.
  #
  # URL: /en/index.html
  # View class: MarkdownPageView
  #
  # Original code (render_fast.cr:90-100):
  #   def render_en
  #     view = MarkdownPageView.new(blog: blog, ...)
  #     write_output(view)
  #   end
  #
  # Called from: render_fast_static_renders (render_overalls.cr:28)
  #
  # Dependencies: [] (always runs)
  #
  r.register("Static: english page", [] of Symbol, priority: 92) do |ctx|
    ViewRegistry::Log.debug { "Rendering english page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_en
  end

  # ============================================
  # JS-Heavy Pages
  # ============================================
  #
  # These pages are simple HTML shells that load JavaScript
  # to fetch and display data dynamically.

  # ============================================
  # View: JS Ideas Page
  # ============================================
  #
  # Ideas/inspiration page with map visualization.
  #
  # URL: /pomysly.html
  # View class: StaticView::JsIdeasView
  #
  # Called from: render_js_pages (render_overalls.cr:19)
  #
  r.register("Static: JS ideas", [:posts], priority: 93) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS ideas page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_js_ideas
  end

  # ============================================
  # View: JS Timeline Page
  # ============================================
  #
  # Interactive timeline visualization.
  #
  # URL: /linia_czasu.html
  # View class: StaticView::JsTimelineView
  #
  # Called from: render_js_pages (render_overalls.cr:20)
  #
  r.register("Static: JS timeline", [:posts], priority: 94) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS timeline page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_js_timeline
  end

  # ============================================
  # View: JS Panoramio Page
  # ============================================
  #
  # Alternative map view (panoramio-style).
  #
  # URL: /mapa2.html
  # View class: StaticView::JsPanoramioView
  #
  # Called from: render_js_pages (render_overalls.cr:21)
  #
  r.register("Static: JS panoramio", [:posts], priority: 95) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS panoramio page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_js_panoramio
  end

  # ============================================
  # View: JS EXIF Stats Page
  # ============================================
  #
  # EXIF/camera statistics visualization.
  #
  # URL: /exif_statystyki.html
  # View class: StaticView::JsExifView
  #
  # Called from: render_js_pages (render_overalls.cr:22)
  #
  r.register("Static: JS exif stats", [:posts], priority: 96) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS exif stats page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_js_exif_stats
  end
end
