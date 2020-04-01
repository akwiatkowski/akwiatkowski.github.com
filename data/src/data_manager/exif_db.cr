class ExifDb
  BATCH_SAVE_COUNT = 500

  def initialize(
    @blog : Tremolite::Blog
  )
    @logger = @blog.logger.as(Logger)
    @cache_path = Tremolite::DataManager::CACHE_PATH

    # Post#slug
    # all exifs will be stored within PhotoEntity
    @exif_entities = Hash(String, Array(ExifEntity)).new
    @exif_entities_dirty = Hash(String, Bool).new

    @photo_entities = Array(PhotoEntity).new
  end

  # append, post, load, ... whatever is needed
  def append_photo_entity(photo_entity : PhotoEntity)
    load_or_initialize_exif_for_post(photo_entity.post_slug)
    process_photo_entity(photo_entity)
    return photo_entity
  end

  def save_cache(post_slug : String)
    dirty = @exif_entities_dirty[post_slug]?
    @logger.debug("#{self.class}: save_exif_entities dirty=#{dirty}")
    # not need to overwrite if no exif data was added
    return unless dirty

    File.open(exif_db_file_path(post_slug), "w") do |f|
      @exif_entities[post_slug].to_yaml(f)
    end

    @logger.info("#{self.class}: save_exif_entities #{@exif_entities[post_slug].size}")
  end

  def load_or_initialize_exif_for_post(post_slug : String)
    # do nothing if already initialized
    return if @exif_entities[post_slug]?

    path = exif_db_file_path(post_slug)
    if File.exists?(path)
      @logger.debug("#{self.class}: loading exif for #{post_slug}")
      @exif_entities[post_slug] = Array(ExifEntity).from_yaml(File.open(path))
      @exif_entities_dirty[post_slug] = false
    else
      @logger.debug("#{self.class}: initializing exif for #{post_slug}")
      @exif_entities[post_slug] = Array(ExifEntity).new
      # because even if it's empty it need to be saved
      @exif_entities_dirty[post_slug] = true
    end
  end

  def exif_db_file_parent_path
    return File.join([@cache_path, "exifs"])
  end

  def exif_db_file_path(post_slug : String)
    return File.join([exif_db_file_parent_path, "#{post_slug}.yml"])
  end

  # search in @exifs, match and assign or generate
  def process_photo_entity(photo_entity : PhotoEntity)
    selected = @exif_entities[photo_entity.post_slug].select do |e|
      e.post_slug == photo_entity.post_slug &&
        e.image_filename == photo_entity.image_filename
    end

    # if it's not available process exif
    # else select existing first one
    if selected.size == 0
      exif = ExifProcessor.process(
        photo_entity: photo_entity,
        path: @blog.data_path.as(String)
      )

      append_to_exifs(photo_entity.post_slug, exif)
    else
      exif = selected.first
    end
    # assign exif
    photo_entity.exif = exif

    append_photo_entity_to_internal(photo_entity)

    return photo_entity
  end

  private def append_to_exifs(post_slug, exif)
    @exif_entities[post_slug] << exif
    @exif_entities_dirty[post_slug] = true
  end

  private def append_photo_entity_to_internal(photo_entity : PhotoEntity)
    @photo_entities << photo_entity
  end
end
