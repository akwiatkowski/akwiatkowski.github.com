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
# View classes used: ModelView::TownsIndexView, LandsIndexView
# (loaded via renderer.cr)

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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Index: towns", [:posts, :yamls], priority: 60) do |ctx|
    ViewRegistry::Log.info { "Rendering towns index" }
    ctx.write_output(ModelView::TownsIndexView.new(context: ctx, url: "/gminy.html"))
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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Index: lands", [:posts, :yamls], priority: 61) do |ctx|
    ViewRegistry::Log.info { "Rendering lands index" }
    ctx.write_output(ModelView::LandsIndexView.new(context: ctx, url: "/krainy.html"))
  end
end
