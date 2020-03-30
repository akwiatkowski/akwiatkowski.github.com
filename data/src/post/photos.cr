class Tremolite::Post
  @head_photo_entity : (PhotoEntity | Nil)
  @all_uploaded_photo_entities : (Array(PhotoEntity) | Nil)

  IMAGE_FORMAT_APSC    = :apsc
  IMAGE_FORMAT_M43     = :m34
  DEFAULT_IMAGE_FORMAT = IMAGE_FORMAT_APSC

  def gallery_url
    self.url + PostGalleryView::GALLERY_URL_SUFFIX
  end

  def all_photo_entities
    [@head_photo_entity.not_nil!] + @photo_entities.not_nil!
  end

  def image_url
    return images_dir_url + image_filename.not_nil!
  end

  def image_format_m43?
    @image_format == IMAGE_FORMAT_M43
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
    return Dir.entries(uploaded_photos_path)
  end

  # BaseView#process_functions is run in #to_html
  # because of that we don't have access to published photos before
  # converting markdown post to html output.
  def count_of_published_photos
    # TODO clean this
    # because it's theoretically not possible to run this during function processing
    size = @photo_entities.not_nil!.size
    return size if size > 0

    # ugly hack
    # check how many commands there is in markdown file
    size = @content_string.scan(/#{Tremolite::Views::BaseView::PHOTO_COMMAND}/).size
    return size
  end

  def append_photo_entity(pe : PhotoEntity)
    @photo_entities.not_nil! << pe
  end

  # getter/generator all photos uploaded to post dir
  # converted to PhotoEntity. used in PostGalleryView
  def all_uploaded_photo_entities : Array(PhotoEntity)
    return @all_uploaded_photo_entities.not_nil! if @all_uploaded_photo_entities

    # use already existing photos
    # photos which were added in post markdown content
    @all_uploaded_photo_entities = photo_entities.dup

    photo_entities_filenames = self.photo_entities.not_nil!.map { |pe| pe.image_filename }

    list_of_uploaded_photos.each do |name|
      if false == File.directory?(File.join([uploaded_photos_path, name]))
        unless photo_entities_filenames.includes?(name)
          # if it was not used already
          # create nameless PhotoEntity
          draft_photo_entity = PhotoEntity.new(
            post: self,
            image_filename: name,
            param_string: "",
          )

          # add to list, fetch exif or get exif cache, set some attribs
          draft_photo_entity = @blog.data_manager.not_nil!.process_photo_entity(draft_photo_entity)

          @all_uploaded_photo_entities.not_nil! << draft_photo_entity
        end
      end
    end

    @all_uploaded_photo_entities = @all_uploaded_photo_entities.not_nil!.sort { |a, b| a.image_filename <=> b.image_filename }
    return @all_uploaded_photo_entities.not_nil!
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
