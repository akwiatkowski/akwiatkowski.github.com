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
# 8. JS Bicycle Planner page - /pomysly2.html (priority: 97)
#
# Dependencies: [] (empty = always run)
# - These pages are simple and don't depend on specific data changes
# - They're re-rendered on every build for simplicity
#
# Priority: 90-99 (near the end, low priority)
#
# View classes used: StaticView::MoreView, JsIdeasView, JsTimelineView,
# JsPanoramioView, JsExifView, MarkdownPageView
# (loaded via renderer.cr)

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
  # Dependencies: [] (always runs)
  #
  r.register("Static: more page", [] of Symbol, priority: 90) do |ctx|
    ViewRegistry::Log.debug { "Rendering more page" }
    ctx.write_output(StaticView::MoreView.new(context: ctx))
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
  # Dependencies: [] (always runs)
  #
  r.register("Static: about page", [] of Symbol, priority: 91) do |ctx|
    ViewRegistry::Log.debug { "Rendering about page" }
    ctx.write_output(MarkdownPageView.new(
      context: ctx,
      url: "/o_mnie.html",
      file: "about",
      image_url: ctx["about.backgrounds"],
      title: ctx["about.title"],
      subtitle: ctx["about.subtitle"]
    ))
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
  # Dependencies: [] (always runs)
  #
  r.register("Static: english page", [] of Symbol, priority: 92) do |ctx|
    ViewRegistry::Log.debug { "Rendering english page" }
    ctx.write_output(MarkdownPageView.new(
      context: ctx,
      url: "/en/index.html",
      file: "en",
      image_url: ctx["en.backgrounds"],
      title: ctx["en.title"],
      subtitle: ctx["en.subtitle"]
    ))
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
  r.register("Static: JS ideas", [:posts], priority: 93) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS ideas page" }
    ctx.write_output(StaticView::JsIdeasView.new(context: ctx, url: "pomysly.html"))
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
  r.register("Static: JS timeline", [:posts], priority: 94) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS timeline page" }
    ctx.write_output(StaticView::JsTimelineView.new(context: ctx, url: "linia_czasu.html"))
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
  r.register("Static: JS panoramio", [:posts], priority: 95) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS panoramio page" }
    ctx.write_output(StaticView::JsPanoramioView.new(context: ctx, url: "mapa2.html"))
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
  r.register("Static: JS exif stats", [:posts], priority: 96) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS exif stats page" }
    ctx.write_output(StaticView::JsExifView.new(context: ctx, url: "exif_statystyki.html"))
  end

  # ============================================
  # View: JS Bicycle Planner Page
  # ============================================
  #
  # Bicycle route planner with map visualization.
  #
  # URL: /pomysly2.html
  # View class: StaticView::JsBicyclePlannerView
  #
  r.register("Static: JS bicycle planner", [:posts], priority: 97) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS bicycle planner page" }
    ctx.write_output(StaticView::JsBicyclePlannerView.new(context: ctx, url: "pomysly2.html"))
  end
end
