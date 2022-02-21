require "../views/gallery_view/camera_index_view"
require "../views/gallery_view/camera_view"
require "../views/gallery_view/focal_length_index_view"
require "../views/gallery_view/focal_length_view"
require "../views/gallery_view/iso_index_view"
require "../views/gallery_view/iso_view"
require "../views/gallery_view/exposure_index_view"
require "../views/gallery_view/exposure_view"
require "../views/gallery_view/lens_index_view"
require "../views/gallery_view/lens_view"
require "../views/gallery_view/tag_view"
require "../views/gallery_view/tag_index_view"
require "../views/gallery_view/index_view"

require "../views/dynamic_view/portfolio_view"
require "../views/dynamic_view/exif_stats_view"
require "../views/dynamic_view/debug_tag_stats_view"
require "../views/dynamic_view/timeline_photo_view"

module RendererMixin::RenderPhotoRelated
  # render only when exifs were loaded
  def render_all_photo_related
    tag_gallery_index_view = render_tag_galleries

    render_lens_galleries
    render_camera_galleries
    render_focal_length_galleries
    render_iso_galleries
    render_exposure_galleries

    render_gallery_index(
      tag_gallery_index_view: tag_gallery_index_view
    )

    render_gallery_stats # TODO check what it is

    render_portfolio

    render_exif_stats
  end

  def render_gallery_index(**args)
    write_output(
      GalleryView::IndexView.new(
        blog: blog,
        tag_gallery_index_view: args[:tag_gallery_index_view]
      )
    )
  end

  def render_tag_galleries
    tag_renderers = Array(GalleryView::TagView).new

    PhotoEntity::TAG_GALLERIES.each do |tag|
      view = GalleryView::TagView.new(
        blog: blog,
        tag: tag
      )
      write_output(view)

      tag_renderers << view
    end

    index_view = GalleryView::TagIndexView.new(
      blog: blog,
      tag_renderers: tag_renderers
    )
    write_output(index_view)

    return index_view
  end

  def render_lens_galleries
    lens_renderers = Array(GalleryView::LensView).new

    # only for predefined lenses
    ExifEntity::LENS_NAMES.values.each do |lens|
      view = GalleryView::LensView.new(
        blog: blog,
        lens: lens,
        tags: ["good", "best"],
        include_headers: true,
        # some cameras has very small amount of photos
        fill_until: FILL_UNTIL
      )
      write_output(view)

      lens_renderers << view
    end

    index_view = GalleryView::LensIndexView.new(
      blog: blog,
      lens_renderers: lens_renderers
    )
    write_output(index_view)
  end

  # fill camera/lens gallery to have at least
  FILL_UNTIL = 80
  # for focal lenght galleries we do not need that much
  FILL_UNTIL_FOCAL    = 40
  FILL_UNTIL_ISO      = 40
  FILL_UNTIL_EXPOSURE = 40

  def render_camera_galleries
    camera_renderers = Array(GalleryView::CameraView).new

    # only for predefined cameras
    ExifEntity::CAMERA_NAMES.values.each do |camera|
      view = GalleryView::CameraView.new(
        blog: blog,
        camera: camera,
        tags: ["good", "best"],
        include_headers: true,
        # some cameras has very small amount of photos
        fill_until: FILL_UNTIL
      )
      write_output(view)

      camera_renderers << view
    end

    index_view = GalleryView::CameraIndexView.new(
      blog: blog,
      camera_renderers: camera_renderers
    )
    write_output(index_view)
  end

  def render_focal_length_galleries
    renderers = Array(GalleryView::FocalLengthView).new

    # only for predefined focal
    # TODO generate it using algorithm
    # start from 18mm and increase by 20% up to 800mm
    focals = Array(Tuple(Int32, Int32)).new

    focal = 16
    while focal < 1000
      new_focal = (focal.to_f * 1.2).to_i

      # rounding, better to have bigger range
      if new_focal > 80
        new_focal = (new_focal.to_f / 10.0).ceil.to_i * 10
      elsif new_focal > 40
        new_focal = (new_focal.to_f / 5.0).ceil.to_i * 5
      end

      focals << {focal, new_focal}
      focal = new_focal
    end

    focals.each do |focal|
      view = GalleryView::FocalLengthView.new(
        blog: blog,
        focal_from: focal[0].to_f,
        focal_to: focal[1].to_f,
        tags: ["good", "best"],
        include_headers: true,
        # some cameras has very small amount of photos
        fill_until: FILL_UNTIL_FOCAL
      )
      write_output(view)

      renderers << view
    end

    index_view = GalleryView::FocalLengthIndexView.new(
      blog: blog,
      renderers: renderers
    )
    write_output(index_view)
  end

  def render_iso_galleries
    renderers = Array(GalleryView::IsoView).new

    isos = Array(Tuple(Int32, Int32)).new

    iso = 50
    while iso < 64000
      new_iso = iso * 2

      isos << {iso, new_iso}
      iso = new_iso
    end

    isos.each do |iso|
      view = GalleryView::IsoView.new(
        blog: blog,
        iso_from: iso[0],
        iso_to: iso[1],
        tags: ["good", "best"],
        include_headers: true,
        fill_until: FILL_UNTIL_ISO
      )
      write_output(view)

      renderers << view
    end

    index_view = GalleryView::IsoIndexView.new(
      blog: blog,
      renderers: renderers
    )
    write_output(index_view)
  end

  def render_exposure_galleries
    renderers = Array(GalleryView::ExposureView).new

    exposures = Array(Tuple(Float64, Float64)).new

    exposures << {0.0001, 0.001}

    exposure = 0.001
    while exposure < 100.0
      new_exposure = exposure * 4.0

      exposures << {exposure, new_exposure}
      exposure = new_exposure
    end

    exposures.each do |exposure|
      view = GalleryView::ExposureView.new(
        blog: blog,
        exposure_from: exposure[0],
        exposure_to: exposure[1],
        tags: ["good", "best"],
        include_headers: true,
        fill_until: FILL_UNTIL_EXPOSURE
      )
      write_output(view)

      renderers << view
    end

    index_view = GalleryView::ExposureIndexView.new(
      blog: blog,
      renderers: renderers
    )
    write_output(index_view)
  end

  def render_gallery_stats
    view = DynamicView::DebugTagStatsView.new(
      blog: blog
    )
    write_output(view)

    view = DynamicView::TimelinePhotoView.new(
      blog: blog
    )
    write_output(view)
  end

  def render_portfolio
    write_output(
      DynamicView::PortfolioView.new(
        blog: blog,
        url: "/portfolio"
      )
    )
  end

  def render_exif_stats
    view = DynamicView::ExifStatsView.new(blog: blog, url: "/exif_stats")
    write_output(view)

    tags = ["bicycle", "hike", "photo", "train"]

    tags.each do |tag|
      view_by_tag = DynamicView::ExifStatsView.new(
        blog: @blog,
        url: "/exif_stats",
        by_tag: tag
      )
      write_output(view_by_tag)
    end
  end
end
