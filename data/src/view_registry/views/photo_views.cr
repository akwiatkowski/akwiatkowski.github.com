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
# View classes used: GalleryView::*, DynamicView::PortfolioView,
# DynamicView::ExifStatsView, DebugView::TagStatsView,
# DynamicView::TimelinePhotoView, PhotoMap::*
# (loaded via renderer.cr)
#
# HashQuantCoordViews alias defined in views/gallery_view/quant_coord_const.cr

# Constants for gallery fill
GALLERY_FILL_UNTIL          = 80
GALLERY_FILL_UNTIL_FOCAL    = 40
GALLERY_FILL_UNTIL_ISO      = 40
GALLERY_FILL_UNTIL_EXPOSURE = 40

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
  # Dependencies: [:exifs]
  #
  r.register("Photo galleries: all", [:exifs], priority: 30) do |ctx|
    ViewRegistry::Log.info { "Rendering photo galleries" }

    # === Tag galleries ===
    tag_renderers = Array(GalleryView::TagView).new
    ctx.photo_tags.each do |photo_tag|
      view = GalleryView::TagView.new(context: ctx, photo_tag: photo_tag)
      ctx.write_output(view)
      tag_renderers << view
    end
    tag_gallery_index_view = GalleryView::TagIndexView.new(context: ctx, renderers: tag_renderers)
    ctx.write_output(tag_gallery_index_view)

    # === Lens galleries ===
    lens_renderers = Array(GalleryView::LensView).new
    ExifEntity::LENS_NAMES.values.each do |lens|
      view = GalleryView::LensView.new(
        context: ctx,
        lens: lens,
        tags: ["good", "best"],
        include_headers: true,
        fill_until: GALLERY_FILL_UNTIL
      )
      ctx.write_output(view)
      lens_renderers << view
    end
    lens_gallery_index_view = GalleryView::LensIndexView.new(context: ctx, renderers: lens_renderers)
    ctx.write_output(lens_gallery_index_view)

    # === Camera galleries ===
    camera_renderers = Array(GalleryView::CameraView).new
    ExifEntity::CAMERA_NAMES.values.each do |camera|
      view = GalleryView::CameraView.new(
        context: ctx,
        camera: camera,
        tags: ["good", "best"],
        include_headers: true,
        fill_until: GALLERY_FILL_UNTIL
      )
      ctx.write_output(view)
      camera_renderers << view
    end
    camera_gallery_index_view = GalleryView::CameraIndexView.new(context: ctx, renderers: camera_renderers)
    ctx.write_output(camera_gallery_index_view)

    # === Focal length galleries ===
    focal_renderers = Array(GalleryView::FocalLengthView).new
    focals = Array(Tuple(Int32, Int32)).new
    focal = 16
    while focal < 1000
      new_focal = (focal.to_f * 1.2).to_i
      if new_focal > 80
        new_focal = (new_focal.to_f / 10.0).ceil.to_i * 10
      elsif new_focal > 40
        new_focal = (new_focal.to_f / 5.0).ceil.to_i * 5
      end
      focals << {focal, new_focal}
      focal = new_focal
    end
    focals.each do |f|
      view = GalleryView::FocalLengthView.new(
        context: ctx,
        focal_from: f[0].to_f,
        focal_to: f[1].to_f,
        tags: ["good", "best"],
        include_headers: true,
        fill_until: GALLERY_FILL_UNTIL_FOCAL
      )
      ctx.write_output(view)
      focal_renderers << view
    end
    focal_length_gallery_index_view = GalleryView::FocalLengthIndexView.new(context: ctx, renderers: focal_renderers)
    ctx.write_output(focal_length_gallery_index_view)

    # === ISO galleries ===
    iso_renderers = Array(GalleryView::IsoView).new
    isos = Array(Tuple(Int32, Int32)).new
    iso = 50
    while iso < 64000
      new_iso = iso * 2
      isos << {iso, new_iso}
      iso = new_iso
    end
    isos.each do |i|
      view = GalleryView::IsoView.new(
        context: ctx,
        iso_from: i[0],
        iso_to: i[1],
        tags: ["good", "best"],
        include_headers: true,
        fill_until: GALLERY_FILL_UNTIL_ISO
      )
      ctx.write_output(view)
      iso_renderers << view
    end
    iso_gallery_index_view = GalleryView::IsoIndexView.new(context: ctx, renderers: iso_renderers)
    ctx.write_output(iso_gallery_index_view)

    # === Exposure galleries ===
    exposure_renderers = Array(GalleryView::ExposureView).new
    exposures = Array(Tuple(Float64, Float64)).new
    exposures << {0.0001, 0.001}
    exposure = 0.001
    while exposure < 100.0
      new_exposure = exposure * 4.0
      exposures << {exposure, new_exposure}
      exposure = new_exposure
    end
    exposures.each do |e|
      view = GalleryView::ExposureView.new(
        context: ctx,
        exposure_from: e[0],
        exposure_to: e[1],
        tags: ["good", "best"],
        include_headers: true,
        fill_until: GALLERY_FILL_UNTIL_EXPOSURE
      )
      ctx.write_output(view)
      exposure_renderers << view
    end
    exposure_gallery_index_view = GalleryView::ExposureIndexView.new(context: ctx, renderers: exposure_renderers)
    ctx.write_output(exposure_gallery_index_view)

    # === Quantized coordinate galleries ===
    photo_coord_quant_cache = ctx.photo_coord_quant_cache
    photo_coord_quant_cache.refresh
    quant_renderers = HashQuantCoordViews.new
    photo_coord_quant_cache.cache.keys.each do |key|
      quant_photos_container = photo_coord_quant_cache.cache[key]
      quant_photos = quant_photos_container[:array]
      quant_info = quant_photos_container[:info]
      next if quant_photos.size == 0
      view = GalleryView::QuantCoordView.new(
        context: ctx,
        key: key,
        quant_photos: quant_photos,
        quant_info: quant_info
      )
      ctx.write_output(view)
      quant_renderers[key[:lat]] ||= Hash(Float32, GalleryView::QuantCoordView).new
      quant_renderers[key[:lat]][key[:lon]] = view
    end
    quant_coord_index_view = GalleryView::QuantCoordIndexView.new(context: ctx, renderers: quant_renderers)
    ctx.write_output(quant_coord_index_view)

    # === Main gallery index ===
    ctx.write_output(GalleryView::IndexView.new(
      context: ctx,
      tag_gallery_index_view: tag_gallery_index_view,
      lens_gallery_index_view: lens_gallery_index_view,
      camera_gallery_index_view: camera_gallery_index_view,
      focal_length_gallery_index_view: focal_length_gallery_index_view,
      iso_gallery_index_view: iso_gallery_index_view,
      exposure_gallery_index_view: exposure_gallery_index_view,
      quant_coord_index_view: quant_coord_index_view,
    ))

    # === Gallery stats ===
    ctx.write_output(DebugView::TagStatsView.new(context: ctx))
    ctx.write_output(DynamicView::TimelinePhotoView.new(context: ctx))

    # === Portfolio ===
    ctx.write_output(DynamicView::PortfolioView.new(context: ctx, url: "/portfolio.html"))

    # === EXIF stats ===
    ctx.write_output(DynamicView::ExifStatsView.new(context: ctx))
    ["bicycle", "hike", "photo", "train"].each do |tag|
      ctx.write_output(DynamicView::ExifStatsView.new(context: ctx, by_tag: tag))
    end
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
  # Dependencies: [:exifs]
  #
  r.register("Photo maps: all", [:exifs], priority: 35) do |ctx|
    ViewRegistry::Log.info { "Rendering photo maps" }

    # Collections for index page
    photomaps_global = Hash(String, PhotoMap::AbstractSvgView).new
    photomaps_for_tag = Hash(String, PhotoMap::MultiplePhotoEntitiesGridMapSvgView).new
    photomaps_for_voivodeship_big = Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView).new
    photomaps_for_voivodeship_small = Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView).new
    photomaps_for_post_big = Hash(Tremolite::Post, PhotoMap::PostBigMapSvgView).new
    photomaps_for_post_small = Hash(Tremolite::Post, PhotoMap::PostRouteMapSvgView).new

    # === Voivodeship maps ===
    ctx.voivodeships.each do |voivodeship|
      voivodeship_coord_range = CoordRange.new(voivodeship)
      post_slugs = ctx.posts.select { |post|
        post.was_in_voivodeship(voivodeship)
      }.map(&.slug)

      big_view = PhotoMap::MultiplePostsGridAndRoutesMapSvgView.new(
        context: ctx,
        url: Map::LinkGenerator.url_photomap_for_voivodeship_big(voivodeship: voivodeship),
        zoom: Map::DEFAULT_VOIVODESHIP_ZOOM,
        photo_size: Map::DEFAULT_VOIVODESHIP_PHOTO_SIZE,
        fixed_coord_range: voivodeship_coord_range,
        post_slugs: post_slugs,
      )
      photomaps_for_voivodeship_big[voivodeship.name] = big_view
      ctx.write_output(big_view)

      small_view = PhotoMap::MultiplePostsGridAndRoutesMapSvgView.new(
        context: ctx,
        url: Map::LinkGenerator.url_photomap_for_voivodeship_small(voivodeship: voivodeship),
        zoom: Map::DEFAULT_VOIVODESHIP_SMALL_ZOOM,
        photo_size: Map::DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE,
        fixed_coord_range: voivodeship_coord_range,
        post_slugs: post_slugs,
      )
      photomaps_for_voivodeship_small[voivodeship.name] = small_view
      ctx.write_output(small_view)
    end

    # === Post maps ===
    ctx.posts.each do |post|
      if post.detailed_routes && post.detailed_routes.not_nil!.size > 0
        if post.detailed_routes.not_nil![0].route.size > 0
          # Big map
          big_view = PhotoMap::PostBigMapSvgView.new(
            context: ctx,
            post: post,
            url: Map::LinkGenerator.url_photomap_for_post_big(post: post),
          )
          photomaps_for_post_big[post] = big_view
          ctx.write_output(big_view)

          # Small map
          small_view = PhotoMap::PostRouteMapSvgView.new(
            context: ctx,
            post: post,
            url: Map::LinkGenerator.url_photomap_for_post_small(post: post),
          )
          photomaps_for_post_small[post] = small_view
          ctx.write_output(small_view)
        end
      end
    end

    # === Idea maps ===
    ctx.ideas.each do |idea|
      ctx.write_output(PhotoMap::IdeaRouteMapSvgView.new(context: ctx, idea: idea))
    end

    # === Global maps ===
    global_maps = [
      {"Ogólne", "overall", Map::DEFAULT_OVERALL_ZOOM, Map::DEFAULT_OVERALL_PHOTO_SIZE, :grid_routes},
      {"Z grubsza", "coarse", Map::DEFAULT_COARSE_ZOOM, Map::DEFAULT_COARSE_PHOTO_SIZE, :grid_routes},
      {"Małe", "small", Map::DEFAULT_SMALL_ZOOM, Map::DEFAULT_SMALL_PHOTO_SIZE, :grid_routes},
      {"Szczegółowe", "detailed", Map::DEFAULT_DETAILED_ZOOM, Map::DEFAULT_DETAILED_PHOTO_SIZE, :grid_routes},
    ]
    global_maps.each do |name, slug, zoom, photo_size, _type|
      view = PhotoMap::GlobalGridAndRoutesMapSvgView.new(
        context: ctx,
        url: Map::LinkGenerator.url_photomap_for_main(slug: slug),
        zoom: zoom,
        photo_size: photo_size,
      )
      photomaps_global[name] = view
      ctx.write_output(view)
    end

    # Animated
    animated_view = PhotoMap::GlobalAnimatedRoutesMapSvgView.new(
      context: ctx,
      url: Map::LinkGenerator.url_photomap_for_main(slug: "small_animated"),
      zoom: Map::DEFAULT_SMALL_ZOOM
    )
    photomaps_global["Animowana"] = animated_view
    ctx.write_output(animated_view)

    # Small detailed (grid only)
    small_detailed_view = PhotoMap::GlobalGridMapSvgView.new(
      context: ctx,
      url: Map::LinkGenerator.url_photomap_for_main(slug: "small_detailed"),
      zoom: Map::DEFAULT_SMALL_DETAILED_ZOOM,
      photo_size: Map::DEFAULT_SMALL_DETAILED_PHOTO_SIZE,
    )
    photomaps_global["Mała i szczegółowa"] = small_detailed_view
    ctx.write_output(small_detailed_view)

    # Dots
    dots_view = PhotoMap::GlobalDotsMapSvgView.new(
      context: ctx,
      url: Map::LinkGenerator.url_photomap_for_main(slug: "dots"),
      zoom: Map::DEFAULT_COARSE_ZOOM,
      photo_size: Map::DEFAULT_DETAILED_PHOTO_SIZE,
      dot_radius: Map::DEFAULT_DOT_RADIUS,
    )
    photomaps_global["Kółko-zdjęcia"] = dots_view
    ctx.write_output(dots_view)

    # === Tagged photo maps ===
    selected_tags = ["rural", "winter", "city", "night", "macro", "portfolio", "cat", "best", "good", "timeline"]
    selected_tags.sort.each do |tag|
      photo_entities = ctx.exif_db.all_flatten_photo_entities.select { |pe|
        pe.tags.includes?(tag)
      }
      view = PhotoMap::MultiplePhotoEntitiesGridMapSvgView.new(
        context: ctx,
        url: Map::LinkGenerator.url_photomap_for_tag(slug: tag),
        zoom: Map::DEFAULT_TAG_ZOOM,
        photo_size: Map::DEFAULT_TAG_PHOTO_SIZE,
        photo_entities: photo_entities,
      )
      photomaps_for_tag[tag] = view
      ctx.write_output(view)
    end

    # === Photo maps index ===
    ctx.write_output(PhotoMap::IndexView.new(
      context: ctx,
      url: "/mapa_zdjec.html",
      photomaps_for_tag: photomaps_for_tag,
      photomaps_for_voivodeship_big: photomaps_for_voivodeship_big,
      photomaps_for_voivodeship_small: photomaps_for_voivodeship_small,
      photomaps_for_post_big: photomaps_for_post_big,
      photomaps_for_post_small: photomaps_for_post_small,
      photomaps_global: photomaps_global,
    ))
  end
end
