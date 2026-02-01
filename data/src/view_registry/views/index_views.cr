# Index Views
# ===========
#
# These views render index/listing pages for entities.
# They show all entities of a type in one page.
#
# Current views:
# 1. Towns index - /gminy.html (priority: 60)
# 2. Lands index - /krainy.html (priority: 61)
#
# Dependencies: [:posts, :yamls]
# - Posts: needed for post counts per entity
# - Yamls: entity definitions
#
# Priority: 60-69 (after entity pages, before static)
#
# Note: These are separate from entity pages because they
# show ALL entities, not individual entity detail pages.
#
# Source: Extracted from renderer mixins:
# - render_towns.cr (render_towns_index)
# - render_lands.cr (render_lands_index)
#
def register_index_views(r : ViewRegistry)
  # ============================================
  # View: Towns Index
  # ============================================
  #
  # Renders the main towns listing page showing all towns
  # with their post counts and thumbnails.
  #
  # URL: /gminy.html
  # View class: ModelView::TownsIndexView
  #
  # Original code (render_towns.cr:12-14):
  #   def render_towns_index
  #     view = ModelView::TownsIndexView.new(blog: @blog, url: "/gminy.html")
  #     write_output(view)
  #   end
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Index: towns", [:posts, :yamls], priority: 60) do |ctx|
    ViewRegistry::Log.info { "Rendering towns index" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_towns_index
  end

  # ============================================
  # View: Lands Index
  # ============================================
  #
  # Renders the main lands listing page showing all lands/regions
  # with their post counts and descriptions.
  #
  # URL: /krainy.html
  # View class: ModelView::LandsIndexView
  #
  # Original code (render_lands.cr:17-19):
  #   def render_lands_index
  #     view = ModelView::LandsIndexView.new(blog: @blog, url: "/krainy.html")
  #     write_output(view)
  #   end
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Index: lands", [:posts, :yamls], priority: 61) do |ctx|
    ViewRegistry::Log.info { "Rendering lands index" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_lands_index
  end
end
