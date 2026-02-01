# Photo Views
# ===========
#
# These views render photo galleries and SVG maps based on EXIF data.
# They are some of the most complex views, with multiple sub-views
# and index pages.
#
# Current views:
# 1. Photo galleries - /galeria/*.html (priority: 30)
# 2. Photo maps - /mapa_zdjec/*.svg (priority: 35)
#
# Dependencies: [:exifs]
# - EXIF data must be loaded before these views can render
#
# Priority: 30-39 (after entity views, before stats views)
#
# Source: Extracted from renderer mixins:
# - render_photo_related.cr (render_all_photo_related)
# - render_photo_maps.cr (render_all_photo_maps)
#
def register_photo_views(r : ViewRegistry)
  # ============================================
  # View: Photo Galleries
  # ============================================
  #
  # Renders all photo gallery pages organized by different criteria:
  # - Tags (rural, winter, macro, etc.)
  # - Camera (Canon, Sony, etc.)
  # - Lens (various lenses)
  # - Focal length (18mm, 24mm, etc.)
  # - ISO (100, 200, 400, etc.)
  # - Exposure (1/1000s, 1/500s, etc.)
  # - Quantized coordinates (grid-based location galleries)
  #
  # Also renders:
  # - Gallery index page (/galeria.html)
  # - Portfolio page (/portfolio.html)
  # - EXIF stats pages (/exif_stats.html and by-tag variants)
  # - Gallery stats (debug tag stats, timeline photo)
  #
  # URL patterns:
  # - /galeria.html (index)
  # - /galeria/tag/{slug}.html
  # - /galeria/aparat/{slug}.html
  # - /galeria/obiektyw/{slug}.html
  # - /galeria/focal/{range}.html
  # - /galeria/iso/{range}.html
  # - /galeria/exposure/{range}.html
  # - /galeria/coord/{lat}_{lon}.html
  #
  # View classes:
  # - GalleryView::IndexView (main index)
  # - GalleryView::TagView, TagIndexView
  # - GalleryView::CameraView, CameraIndexView
  # - GalleryView::LensView, LensIndexView
  # - GalleryView::FocalLengthView, FocalLengthIndexView
  # - GalleryView::IsoView, IsoIndexView
  # - GalleryView::ExposureView, ExposureIndexView
  # - GalleryView::QuantCoordView, QuantCoordIndexView
  # - DynamicView::PortfolioView
  # - DynamicView::ExifStatsView
  # - DynamicView::DebugTagStatsView
  # - DynamicView::TimelinePhotoView
  #
  # Original code (render_photo_related.cr:26-52):
  #   def render_all_photo_related
  #     tag_gallery_index_view = render_tag_galleries
  #     lens_gallery_index_view = render_lens_galleries
  #     camera_gallery_index_view = render_camera_galleries
  #     focal_length_gallery_index_view = render_focal_length_galleries
  #     iso_gallery_index_view = render_iso_galleries
  #     exposure_gallery_index_view = render_exposure_galleries
  #     quant_coord_index_view = render_photo_coord_quant
  #
  #     render_gallery_index(...)
  #     render_gallery_stats
  #     render_portfolio
  #     render_exif_stats
  #     render_debug_post_camera_stuff  # moved to debug_views.cr
  #     render_debug_post_photos_missing_exif  # moved to debug_views.cr
  #   end
  #
  # Dependencies: [:exifs]
  # - EXIF data contains camera, lens, focal length, ISO, exposure info
  # - Photo entities with coordinates needed for coord galleries
  #
  # Note: Debug views (camera stuff, missing EXIF) are registered
  # separately in debug_views.cr with priority 101-102.
  #
  r.register("Photo galleries: all", [:exifs], priority: 30) do |ctx|
    ViewRegistry::Log.info { "Rendering photo galleries" }

    # Wrapper: calls existing mixin method
    # This renders all gallery types + index + portfolio + exif stats
    # Note: The mixin also calls debug views which are now in debug_views.cr
    # Those will run separately at priority 101-102
    renderer = ctx.blog.renderer

    # Render each gallery type and collect index views
    tag_gallery_index_view = renderer.render_tag_galleries
    lens_gallery_index_view = renderer.render_lens_galleries
    camera_gallery_index_view = renderer.render_camera_galleries
    focal_length_gallery_index_view = renderer.render_focal_length_galleries
    iso_gallery_index_view = renderer.render_iso_galleries
    exposure_gallery_index_view = renderer.render_exposure_galleries
    quant_coord_index_view = renderer.render_photo_coord_quant

    # Render gallery index (needs all sub-index views)
    renderer.render_gallery_index(
      tag_gallery_index_view: tag_gallery_index_view,
      lens_gallery_index_view: lens_gallery_index_view,
      camera_gallery_index_view: camera_gallery_index_view,
      focal_length_gallery_index_view: focal_length_gallery_index_view,
      iso_gallery_index_view: iso_gallery_index_view,
      exposure_gallery_index_view: exposure_gallery_index_view,
      quant_coord_index_view: quant_coord_index_view
    )

    # Render gallery stats (debug tag stats, timeline photo)
    renderer.render_gallery_stats

    # Render portfolio and EXIF stats
    renderer.render_portfolio
    renderer.render_exif_stats
  end

  # ============================================
  # View: Photo Maps (SVG)
  # ============================================
  #
  # Renders SVG maps showing photo locations:
  # - Global maps (multiple zoom levels, animated, dots)
  # - Post maps (big and small for each post with routes)
  # - Voivodeship maps (per-region maps)
  # - Idea maps (planned trip routes)
  # - Tagged photo maps (photos by tag on map)
  # - Photo map index page
  #
  # URL patterns:
  # - /mapa_zdjec.html (index)
  # - /mapa_zdjec/main/{type}.svg (global maps)
  # - /mapa_zdjec/post/{slug}_big.svg
  # - /mapa_zdjec/post/{slug}_small.svg
  # - /mapa_zdjec/voivodeship/{slug}_big.svg
  # - /mapa_zdjec/voivodeship/{slug}_small.svg
  # - /mapa_zdjec/idea/{slug}.svg
  # - /mapa_zdjec/tag/{slug}.svg
  #
  # View classes:
  # - PhotoMap::IndexView
  # - PhotoMap::GlobalGridAndRoutesMapSvgView
  # - PhotoMap::GlobalGridMapSvgView
  # - PhotoMap::GlobalDotsMapSvgView
  # - PhotoMap::GlobalAnimatedRoutesMapSvgView
  # - PhotoMap::PostBigMapSvgView
  # - PhotoMap::PostRouteMapSvgView
  # - PhotoMap::MultiplePostsGridAndRoutesMapSvgView (voivodeship)
  # - PhotoMap::IdeaRouteMapSvgView
  # - PhotoMap::MultiplePhotoEntitiesGridMapSvgView (tagged)
  #
  # Original code (render_photo_maps.cr:2-13):
  #   def render_all_photo_maps
  #     render_photo_maps_voivodeships
  #     render_photo_maps_posts
  #     render_photo_maps_ideas
  #     render_photo_maps_global
  #     render_photo_maps_for_tagged_photos
  #     render_photo_maps_index
  #   end
  #
  # Dependencies: [:exifs]
  # - Photo entities with coordinates needed for map placement
  # - Post detailed_routes needed for route rendering
  #
  r.register("Photo maps: all", [:exifs], priority: 35) do |ctx|
    ViewRegistry::Log.info { "Rendering photo maps" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_all_photo_maps
  end
end
