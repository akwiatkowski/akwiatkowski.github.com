# Home Views
# ==========
#
# These views render the main home page and navigation-related pages.
#
# Current views:
# 1. Home page (old) - /index.old.html (priority: 20)
# 2. New Home page - / (priority: 20)
# 3. Map page - /mapa.html (priority: 21)
# 4. POIs page - /pois.html (priority: 22)
#
# Dependencies: [:posts]
# - These pages show post data but don't need yamls
#
# Priority: 20-29 (after entity views)
#
# View classes used: PostListView::CollectionDynamicView,
# StaticView::MapView, PoisView, NewHomePageView
# (loaded via renderer.cr)

def register_home_views(r : ViewRegistry)
  # ============================================
  # View: Home Page (Old/Legacy)
  # ============================================
  #
  # Renders the old home/landing page showing recent posts
  # and site overview. Kept for reference.
  #
  # URL: /index.old.html
  # View class: PostListView::CollectionDynamicView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: old home page", [:posts], priority: 20) do |ctx|
    ViewRegistry::Log.info { "Rendering old home page" }
    ctx.write_output(PostListView::CollectionDynamicView.new(context: ctx, url: "/index.old.html"))
  end

  # ============================================
  # View: New Home Page (Main)
  # ============================================
  #
  # Renders the new modern home page design with:
  # - Hero section with featured post
  # - Grid of recent posts
  # - Category chips for exploration
  # - Dark mode support
  #
  # URL: /
  # View class: NewHomePageView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: main page", [:posts], priority: 20) do |ctx|
    ViewRegistry::Log.info { "Rendering main home page" }
    ctx.write_output(NewHomePageView.new(context: ctx))
  end

  # ============================================
  # View: Map Page
  # ============================================
  #
  # Renders the interactive map page showing all post locations.
  # This is a JS-heavy page that loads data via JSON.
  #
  # URL: /mapa.html
  # View class: StaticView::MapView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: map page", [:posts], priority: 21) do |ctx|
    ViewRegistry::Log.info { "Rendering map page" }
    ctx.write_output(StaticView::MapView.new(context: ctx))
  end

  # ============================================
  # View: POIs Page
  # ============================================
  #
  # Renders the Points of Interest page showing notable
  # locations from posts.
  #
  # URL: /pois.html
  # View class: PoisView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: POIs page", [:posts], priority: 22) do |ctx|
    ViewRegistry::Log.info { "Rendering POIs page" }
    ctx.write_output(PoisView.new(context: ctx, url: "/pois.html"))
  end
end
