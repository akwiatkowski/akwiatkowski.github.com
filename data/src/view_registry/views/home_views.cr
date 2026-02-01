# Home Views
# ==========
#
# These views render the main home page and navigation-related pages.
#
# Current views:
# 1. Home page - / (priority: 20)
# 2. Map page - /mapa.html (priority: 21)
# 3. POIs page - /pois.html (priority: 22)
#
# Dependencies: [:posts]
# - These pages show post data but don't need yamls
#
# Priority: 20-29 (after entity views)
#
# View classes used: PostListView::CollectionDynamicView,
# StaticView::MapView, PoisView
# (loaded via renderer.cr)

def register_home_views(r : ViewRegistry)
  # ============================================
  # View: Home Page
  # ============================================
  #
  # Renders the main home/landing page showing recent posts
  # and site overview.
  #
  # URL: /
  # View class: PostListView::CollectionDynamicView
  #
  # Dependencies: [:posts]
  #
  r.register("Home: main page", [:posts], priority: 20) do |ctx|
    ViewRegistry::Log.info { "Rendering home page" }
    ctx.write_output(PostListView::CollectionDynamicView.new(blog: ctx.blog, url: "/"))
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
    ctx.write_output(StaticView::MapView.new(blog: ctx.blog))
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
    ctx.write_output(PoisView.new(blog: ctx.blog, url: "/pois.html"))
  end
end
