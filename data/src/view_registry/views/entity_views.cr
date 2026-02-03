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
# View classes used: PostListView::TownDynamicView, TagDynamicView,
# VoivodeshipDynamicView, LandDynamicView
# (loaded via renderer.cr)

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
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: town definitions
  #
  r.register("Towns: all pages", [:posts, :yamls], priority: 10) do |ctx|
    ViewRegistry::Log.info { "Rendering town pages" }
    ctx.towns.each do |town|
      ctx.validator.validate_object(town)
      ctx.write_output(PostListView::TownDynamicView.new(context: ctx, town: town))
    end
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
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: tag definitions
  #
  r.register("Tags: all pages", [:posts, :yamls], priority: 11) do |ctx|
    ViewRegistry::Log.info { "Rendering tag pages" }
    ctx.tags.each do |tag|
      ctx.validator.validate_object(tag)
      ctx.write_output(PostListView::TagDynamicView.new(context: ctx, tag: tag))
    end
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
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: voivodeship definitions
  #
  r.register("Voivodeships: all pages", [:posts, :yamls], priority: 12) do |ctx|
    ViewRegistry::Log.info { "Rendering voivodeship pages" }
    ctx.voivodeships.each do |voivodeship|
      ctx.validator.validate_object(voivodeship)
      ctx.write_output(PostListView::VoivodeshipDynamicView.new(context: ctx, voivodeship: voivodeship))
    end
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
  # We call ensure_posts_have_assigned_lands before rendering.
  #
  # Dependencies: [:posts, :yamls]
  # - Posts: content to display
  # - Yamls: land definitions
  #
  r.register("Lands: all pages", [:posts, :yamls], priority: 13) do |ctx|
    ViewRegistry::Log.info { "Rendering land pages" }
    ctx.blog.post_collection.ensure_posts_have_assigned_lands
    ctx.lands.each do |land|
      ctx.validator.validate_object(land)
      ctx.write_output(PostListView::LandDynamicView.new(context: ctx, land: land))
    end
  end
end
