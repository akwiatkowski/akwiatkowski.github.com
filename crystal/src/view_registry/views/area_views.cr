# Area Views
# ===========
#
# These views render pages for the unified area entity system.
# Each area type (town, county, voivodeship, meso_region, macro_region) gets:
# 1. Show page - main info page: /<type>/<slug>.html
# 2. Post list page - posts for area: /wpisy-dla/<type>/<slug>.html
# 3. Gallery page - photos in area: /galeria/<type>/<slug>.html
#
# Only areas with posts are rendered (empty areas are skipped).
#
# Dependencies: [:posts, :yamls]
# Priority: 14-16 (after legacy entity views)
#
# View classes: AreaShowView, PostListView::AreaPostListView, GalleryView::AreaGalleryView

def register_area_views(r : ViewRegistry)
  # ============================================
  # View: Area Show Pages
  # ============================================
  #
  # Renders the main info page for each area with posts.
  # Shows area stats, links to post list and gallery.
  #
  # URL pattern: /<type>/<slug>.html (e.g., /gminy/pobiedziska.html)
  # View class: AreaShowView
  #
  r.register("Areas: show pages", [:posts, :yamls], priority: 14) do |ctx|
    ViewRegistry::Log.info { "Rendering area show pages" }

    AreaType.each do |area_type|
      areas_with_posts = ctx.areas_with_posts(area_type)
      ViewRegistry::Log.info { "Rendering #{areas_with_posts.size} #{area_type} show pages" }

      areas_with_posts.sort_by(&.slug).each do |area|
        ctx.render_and_write(AreaShowView.new(context: ctx, area: area))
      end
    end
  end

  # ============================================
  # View: Area Post List Pages
  # ============================================
  #
  # Renders a page listing posts for each area with posts.
  #
  # URL pattern: /wpisy-dla/<type>/<slug>.html
  # View class: PostListView::AreaPostListView
  #
  r.register("Areas: post list pages", [:posts, :yamls], priority: 15) do |ctx|
    ViewRegistry::Log.info { "Rendering area post list pages" }

    AreaType.each do |area_type|
      areas_with_posts = ctx.areas_with_posts(area_type)
      ViewRegistry::Log.info { "Rendering #{areas_with_posts.size} #{area_type} post list pages" }

      areas_with_posts.sort_by(&.slug).each do |area|
        ctx.render_and_write(PostListView::AreaPostListView.new(context: ctx, area: area))
      end
    end
  end

  # ============================================
  # View: Area Gallery Pages
  # ============================================
  #
  # Renders a gallery page for each area with posts.
  # Only renders if the area has photos in its bounding box.
  #
  # URL pattern: /galeria/<type>/<slug>.html
  # View class: GalleryView::AreaGalleryView
  #
  r.register("Areas: gallery pages", [:posts, :yamls], priority: 16) do |ctx|
    ViewRegistry::Log.info { "Rendering area gallery pages" }

    AreaType.each do |area_type|
      areas_with_posts = ctx.areas_with_posts(area_type)
      ViewRegistry::Log.info { "Rendering #{areas_with_posts.size} #{area_type} gallery pages" }

      areas_with_posts.sort_by(&.slug).each do |area|
        # Only render gallery if area has bbox (needed for photo selection)
        next unless area.bbox
        ctx.render_and_write(GalleryView::AreaGalleryView.new(context: ctx, area: area))
      end
    end
  end

  # ============================================
  # View: External Area Post List Pages
  # ============================================
  #
  # Renders a page listing posts for each external (foreign) area.
  #
  # URL pattern: /wpisy-dla/zagranica/<slug>.html
  # View class: PostListView::ExternalAreaPostListView
  #
  r.register("External areas: post list pages", [:posts, :yamls], priority: 17) do |ctx|
    external_areas = ctx.external_areas_with_posts
    ViewRegistry::Log.info { "Rendering #{external_areas.size} external area post list pages" }

    external_areas.each do |area|
      ctx.render_and_write(PostListView::ExternalAreaPostListView.new(context: ctx, area: area))
    end
  end
end
