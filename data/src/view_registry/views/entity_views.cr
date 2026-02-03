# Entity Views
# ============
#
# Tags are not area types, so they keep their own view registration.
# Area-based entities (towns, voivodeships, meso_regions, macro_regions)
# are now handled by area_views.cr using the unified AreaEntity system.
#
# Current views:
# - Tag pages - /tagi/{slug}.html (priority: 11)
#
# Dependencies: [:posts, :yamls]
# - Posts contain the content
# - Yamls define the tags
#
# Priority: 11 (first views to render after tasks)
#
# View class used: PostListView::TagDynamicView

def register_entity_views(r : ViewRegistry)
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
end
