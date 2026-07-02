# Home Views
# ==========
#
# These views render the main home page and navigation-related pages.
#
# Current views:
# 1. Home page - / (priority: 20)
# 2. Route map page - /mapa_tras.html (priority: 21)
# 3. POIs page - /pois.html (priority: 22)
#
# Dependencies: [:posts]
# - These pages show post data but don't need yamls
#
# Priority: 20-29 (after entity views)
#
# View classes used: HomePageView, StaticView::RouteMapView, PoisView
# (loaded via renderer.cr)

def register_home_views(r : ViewRegistry)
  # ============================================
  # View: Home Page (Main)
  # ============================================
  #
  # Renders the home page with:
  # - Hero section with featured post
  # - Grid of recent posts
  # - Category chips for exploration
  # - Dark mode support
  #
  # URL: /
  # View class: HomePageView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: main page", [:posts], priority: 20) do |ctx|
    ViewRegistry::Log.info { "Rendering main home page" }
    ctx.render_and_write(HomePageView.new(context: ctx))
  end

  # ============================================
  # View: Map Page
  # ============================================
  #
  # Renders the interactive route map page showing all post locations.
  # This is a JS-heavy page that loads data via JSON.
  #
  # URL: /mapa_tras.html
  # View class: StaticView::RouteMapView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: route map page", [:posts], priority: 21) do |ctx|
    ViewRegistry::Log.info { "Rendering route map page" }
    ctx.render_and_write(StaticView::RouteMapView.new(context: ctx))
  end

  # ============================================
  # View: POIs Page
  # ============================================
  #
  # Renders interactive map of Points of Interest with
  # Preact side panel showing visited/todo details.
  #
  # URL: /pois.html
  # View class: PoisView
  #
  # Dependencies: [:posts, :yamls, :exifs] (train_stations/ideas from yamls, photo GPS from exifs)
  #
  r.register("Home: POIs page", [:posts, :yamls, :exifs], priority: 22) do |ctx|
    ViewRegistry::Log.info { "Rendering POIs page" }
    ctx.render_and_write(PoisView.new(context: ctx))
  end
end
