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
# Source: Extracted from render_overalls.cr (render_all_views_post_related)
# and render_fast.cr
#
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
  # Original code (render_fast.cr:11-18):
  #   def render_home_new
  #     write_output(
  #       PostListView::CollectionDynamicView.new(blog: blog, url: "/")
  #     )
  #   end
  #
  # Called from: render_all_views_post_related (render_overalls.cr:13)
  #
  # Dependencies: [:posts]
  #
  r.register("Home: main page", [:posts], priority: 20) do |ctx|
    ViewRegistry::Log.info { "Rendering home page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_home_new
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
  # Original code (render_fast.cr:20-26):
  #   def render_map
  #     write_output(StaticView::MapView.new(blog: blog))
  #   end
  #
  # Called from: render_all_views_post_related (render_overalls.cr:14)
  #
  # Dependencies: [:posts]
  #
  r.register("Home: map page", [:posts], priority: 21) do |ctx|
    ViewRegistry::Log.info { "Rendering map page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_map
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
  # Original code (render_fast.cr:150-157):
  #   def render_pois
  #     write_output(PoisView.new(blog: blog, url: "/pois.html"))
  #   end
  #
  # Called from: render_all_views_post_related (render_overalls.cr:15)
  #
  # Dependencies: [:posts]
  #
  r.register("Home: POIs page", [:posts], priority: 22) do |ctx|
    ViewRegistry::Log.info { "Rendering POIs page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_pois
  end
end
