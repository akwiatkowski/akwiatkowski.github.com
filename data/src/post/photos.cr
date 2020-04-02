class Tremolite::Post
  @head_photo_entity : (PhotoEntity | Nil)
  @all_uploaded_photo_entities : (Array(PhotoEntity) | Nil)

  IMAGE_FORMAT_APSC    = :apsc
  IMAGE_FORMAT_M43     = :m34
  DEFAULT_IMAGE_FORMAT = IMAGE_FORMAT_APSC

  def gallery_url
    self.url + PostGalleryView::GALLERY_URL_SUFFIX
  end

  def image_url
    return images_dir_url + image_filename.not_nil!
  end

  def image_format_m43?
    @image_format == IMAGE_FORMAT_M43
  end

  def populate_published_post
    # by running this it runs function which populate exif_db
    content_html
  end

  def processed_image_url(prefix : String)
    Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB, # web paths not neet public folder path
      post_year: self.year,
      post_month: self.time.month,
      post_slug: slug,
      prefix: prefix,
      file_name: image_filename.not_nil!
    )
  end

  # path where all uploaded photos are stored
  def uploaded_photos_path
    return File.join([data_path, self.images_dir_url])
  end

  def list_of_uploaded_photos
    upp = uploaded_photos_path
    # return only files, no directories
    return Dir.entries(uploaded_photos_path).select do |path|
        File.directory?(File.join([upp, path])) == false
    end
  end

  # it's not into published here
  def header_photo_entity
    @head_photo_entity
  end

  def published_photo_entities : Array(PhotoEntity)
    # TODO add header photo entity
    @blog.data_manager.exif_db.published_photo_entities(self.slug)
  end

  def uploaded_photo_entities : Array(PhotoEntity)
    @blog.data_manager.exif_db.uploaded_photo_entities(self.slug)
  end

  def all_photo_entities_unsorted : Array(PhotoEntity)
    published_photo_entities + uploaded_photo_entities
  end

  # XXX refactor
  def small_image_url
    @head_photo_entity.not_nil!.small_image_src
  end

  def big_thumb_image_url
    @head_photo_entity.not_nil!.big_thumb_image_src
  end

  def thumb_image_url
    @head_photo_entity.not_nil!.thumb_image_src
  end
end
