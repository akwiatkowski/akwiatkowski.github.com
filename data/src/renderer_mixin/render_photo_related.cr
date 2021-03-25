require "../views/gallery_view/all_photos_view"
require "../views/gallery_view/camera_index_view"
require "../views/gallery_view/camera_view"
require "../views/gallery_view/focal_length_index_view"
require "../views/gallery_view/focal_length_view"
require "../views/gallery_view/lens_index_view"
require "../views/gallery_view/lens_view"
require "../views/gallery_view/tag_stats_view"
require "../views/gallery_view/tag_view"

module RendererMixin::RenderPhotoRelated
  # render only when exifs were loaded
  def render_all_photo_related
    render_gallery # TODO
    render_tag_galleries # TODO

    render_lens_galleries
    render_camera_galleries
    render_focal_length_galleries

    render_gallery_stats # TODO check what it is

    render_portfolio

    render_exif_stats
  end

  def render_gallery
    write_output(
      GalleryView::AllPhotosView.new(
        blog: blog
      )
    )
  end

  def render_tag_galleries
    PhotoEntity::TAG_GALLERIES.each do |tag|
      write_output(
        GalleryView::TagView.new(
          blog: blog,
          tag: tag
        )
      )
    end
  end

  def render_lens_galleries
    lens_renderers = Array(GalleryView::LensView).new

    # only for predefined lenses
    ExifEntity::LENS_NAMES.values.each do |lens|
      view = GalleryView::LensView.new(
        blog: blog,
        lens: lens,
        tags: ["good", "best"],
        include_headers: true
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

  def render_camera_galleries
    camera_renderers = Array(GalleryView::CameraView).new

    # only for predefined lenses
    ExifEntity::CAMERA_NAMES.values.each do |camera|
      view = GalleryView::CameraView.new(
        blog: blog,
        camera: camera,
        tags: ["good", "best"],
        include_headers: true
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
    while focal < 800
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
        include_headers: true
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

  def render_gallery_stats
    view = GalleryView::TagStatsView.new(
      blog: blog
    )
    write_output(view)
  end

  def render_portfolio
    write_output(
      PortfolioView.new(
        blog: blog,
        url: "/portfolio"
      )
    )
  end

  def render_exif_stats
    view = ExifStatsView.new(blog: blog, url: "/exif_stats")
    write_output(view)

    tags = ["bicycle", "hike", "photo", "train"]

    tags.each do |tag|
      view_by_tag = ExifStatsView.new(
        blog: @blog,
        url: "/exif_stats",
        by_tag: tag
      )
      write_output(view_by_tag)
    end
  end
end
