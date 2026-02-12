# Static Views
# ============
#
# These views render static/informational pages with minimal
# data processing. They include markdown-based pages and
# JS-heavy pages that load data client-side.
#
# Current views:
# 1. More page - /wiecej.html (priority: 89)
# 2. Portfolio page - /portfolio.html (priority: 90)
# 3. About page - /o-mnie.html (priority: 91)
# 4. English page - /en/index.html (priority: 92)
# 5. Trip ideas page - /pomysly_tras.html (priority: 93)
# 6. JS Timeline page - /linia_czasu.html (priority: 94)
# 7. Photo map page - /mapa_zdjec.html (priority: 95)
# 8. JS Exif Stats page - /statystyki_exif.html (priority: 96)
# 9. Photo planner page - /pomysly_dla_zdjec.html (priority: 97)
#
# Dependencies: [] (empty = always run)
# - These pages are simple and don't depend on specific data changes
# - They're re-rendered on every build for simplicity
#
# Priority: 90-99 (near the end, low priority)
#
# View classes used: NewMoreView, PortfolioView, TripIdeasView, JsTimelineView,
# PhotoMapView, JsExifView, PhotoPlannerView, MarkdownPageView
# (loaded via renderer.cr)

def register_static_views(r : ViewRegistry)
  # ============================================
  # View: New More Page
  # ============================================
  #
  # Renders the new "more" page with modern design.
  #
  # URL: /wiecej.html
  # View class: NewMoreView
  #
  # Dependencies: [] (always runs)
  #
  r.register("Static: new more page", [] of Symbol, priority: 89) do |ctx|
    ViewRegistry::Log.debug { "Rendering new more page" }
    ctx.render_and_write(NewMoreView.new(context: ctx))
  end

  # ============================================
  # View: About Page
  # ============================================
  #
  # Renders the "about me" page from markdown.
  #
  # URL: /o-mnie.html
  # View class: MarkdownPageView
  #
  # Dependencies: [] (always runs)
  #
  r.register("Static: about page", [] of Symbol, priority: 91) do |ctx|
    ViewRegistry::Log.debug { "Rendering about page" }
    ctx.render_and_write(MarkdownPageView.new(
      context: ctx,
      url: "/o-mnie.html",
      file: "about",
      image_url: ctx.background_for_page("about"),
      title: ctx.title_for_page("about"),
      subtitle: ctx.subtitle_for_page("about")
    ))
    # Legacy URL redirect
    ctx.render_and_write(SpecialView::TemporaryRedirectView.new(
      context: ctx,
      old_url: "/o_mnie.html",
      new_url: "/o-mnie.html"
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
    ctx.render_and_write(MarkdownPageView.new(
      context: ctx,
      url: "/en/index.html",
      file: "en",
      image_url: ctx.background_for_page("en"),
      title: ctx.title_for_page("en"),
      subtitle: ctx.subtitle_for_page("en")
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
  # URL: /pomysly_tras.html
  # View class: StaticView::TripIdeasView
  #
  r.register("Static: trip ideas", [:posts], priority: 93) do |ctx|
    ViewRegistry::Log.debug { "Rendering trip ideas page" }
    ctx.render_and_write(StaticView::TripIdeasView.new(context: ctx))
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
    ctx.render_and_write(StaticView::JsTimelineView.new(context: ctx))
  end

  # ============================================
  # View: Photo Map Page
  # ============================================
  #
  # Photo map view (panoramio-style).
  #
  # URL: /mapa_zdjec.html
  # View class: StaticView::PhotoMapView
  #
  r.register("Static: photo map", [:posts], priority: 95) do |ctx|
    ViewRegistry::Log.debug { "Rendering photo map page" }
    ctx.render_and_write(StaticView::PhotoMapView.new(context: ctx))
  end

  # ============================================
  # View: JS EXIF Stats Page
  # ============================================
  #
  # EXIF/camera statistics visualization.
  #
  # URL: /statystyki_exif.html
  # View class: StaticView::JsExifView
  #
  r.register("Static: JS exif stats", [:posts], priority: 96) do |ctx|
    ViewRegistry::Log.debug { "Rendering JS exif stats page" }
    ctx.render_and_write(StaticView::JsExifView.new(context: ctx))
  end

  # ============================================
  # View: Photo Planner Page
  # ============================================
  #
  # Photo route planner - generates bicycle routes
  # optimizing photo coverage of new areas.
  #
  # URL: /pomysly_dla_zdjec.html
  # View class: StaticView::PhotoPlannerView
  #
  r.register("Static: photo planner", [:posts], priority: 97) do |ctx|
    ViewRegistry::Log.debug { "Rendering photo planner page" }
    ctx.render_and_write(StaticView::PhotoPlannerView.new(context: ctx))
  end

  # ============================================
  # View: Portfolio Page
  # ============================================
  #
  # Photography portfolio with masonry grid, ambilight glow,
  # and lightbox with EXIF data.
  #
  # URL: /portfolio.html
  # View class: PortfolioView
  #
  # Dependencies: [:posts, :exifs] (needs published photos with EXIF)
  #
  r.register("Static: portfolio", [:posts, :exifs], priority: 90) do |ctx|
    ViewRegistry::Log.debug { "Rendering portfolio page" }
    ctx.render_and_write(PortfolioView.new(context: ctx))
  end
end
