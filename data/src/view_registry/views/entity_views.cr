# Entity Views
# ============
#
# These views render entity pages: towns, tags, voivodeships, lands.
# Each entity type gets its own page listing posts associated with it.
#
# Current views:
# 1. Town pages - /gminy/{slug}.html (priority: 10)
# 2. Tag pages - /tagi/{slug}.html (priority: 11)
# 3. Voivodeship pages - /wojewodztwa/{slug}.html (priority: 12)
# 4. Land pages - /krainy/{slug}.html (priority: 13)
#
# Dependencies: [:posts, :yamls]
# - Posts contain the content
# - Yamls define the entities (towns, tags, etc.)
#
# Priority: 10-13 (first views to render after tasks)
#
# Migration note:
# ---------------
# These registrations currently WRAP the existing mixin methods.
# This allows us to:
# 1. Test that the registry calls things correctly
# 2. Later move the logic INTO the registration blocks
# 3. Eventually delete the mixin files
#
# Source: Extracted from renderer mixins:
# - render_towns.cr (render_towns_pages, render_town_page)
# - render_tags.cr (render_tags_pages, render_tag_page)
# - render_voivodeships.cr (render_voivodeships_pages, render_voivodeship_page)
# - render_lands.cr (render_lands_pages, render_land_page)
#
def register_entity_views(r : ViewRegistry)
  # ============================================
  # View: Town Pages
  # ============================================
  #
  # Renders a page for each town (gmina) showing posts
  # where the author visited that town.
  #
  # URL pattern: /gminy/{slug}.html
  # View class: PostListView::TownDynamicView
  #
  # Original code (render_towns.cr:4-10):
  #   def render_towns_pages
  #     towns_to_render.each do |town|
  #       validator.validate_object(town)
  #       render_town_page(town)
  #     end
  #   end
  #
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: town definitions
  #
  r.register("Towns: all pages", [:posts, :yamls], priority: 10) do |ctx|
    ViewRegistry::Log.info { "Rendering town pages" }

    # Wrapper: calls existing mixin method
    # TODO: Move logic here once registry is validated
    ctx.blog.renderer.render_towns_pages
  end

  # ============================================
  # View: Tag Pages
  # ============================================
  #
  # Renders a page for each tag showing posts with that tag.
  #
  # URL pattern: /tagi/{slug}.html
  # View class: PostListView::TagDynamicView
  #
  # Original code (render_tags.cr:4-9):
  #   def render_tags_pages
  #     tags_to_render.each do |tag|
  #       validator.validate_object(tag)
  #       render_tag_page(tag)
  #     end
  #   end
  #
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: tag definitions
  #
  r.register("Tags: all pages", [:posts, :yamls], priority: 11) do |ctx|
    ViewRegistry::Log.info { "Rendering tag pages" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_tags_pages
  end

  # ============================================
  # View: Voivodeship Pages
  # ============================================
  #
  # Renders a page for each voivodeship (województwo) showing
  # posts from that region.
  #
  # URL pattern: /wojewodztwa/{slug}.html
  # View class: PostListView::VoivodeshipDynamicView
  #
  # Original code (render_voivodeships.cr:4-9):
  #   def render_voivodeships_pages
  #     voivodeships_to_render.each do |voivodeship|
  #       validator.validate_object(voivodeship)
  #       render_voivodeship_page(voivodeship)
  #     end
  #   end
  #
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: voivodeship definitions
  #
  r.register("Voivodeships: all pages", [:posts, :yamls], priority: 12) do |ctx|
    ViewRegistry::Log.info { "Rendering voivodeship pages" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_voivodeships_pages
  end

  # ============================================
  # View: Land Pages
  # ============================================
  #
  # Renders a page for each land/region (kraina) showing
  # posts from that geographic area.
  #
  # URL pattern: /krainy/{slug}.html
  # View class: PostListView::LandDynamicView
  #
  # Note: This has a prerequisite - posts must have lands assigned.
  # The mixin calls ensure_posts_have_assigned_lands before rendering.
  #
  # Original code (render_lands.cr:5-14):
  #   def render_lands_pages
  #     blog.post_collection.ensure_posts_have_assigned_lands
  #     lands_to_render.each do |land|
  #       validator.validate_object(land)
  #       render_land_page(land)
  #     end
  #   end
  #
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: land definitions
  #
  r.register("Lands: all pages", [:posts, :yamls], priority: 13) do |ctx|
    ViewRegistry::Log.info { "Rendering land pages" }

    # Wrapper: calls existing mixin method
    # Note: mixin internally calls ensure_posts_have_assigned_lands
    ctx.blog.renderer.render_lands_pages
  end
end
