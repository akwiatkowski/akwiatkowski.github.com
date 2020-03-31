class ExifDb
  BATCH_SAVE_COUNT = 500

  def initialize
    @photos = Array(PhotoEntity).new

    @exifs = Array(ExifEntity).new
    @exifs_loaded = false
    @exifs_dirty = false

    @cache_path = Tremolite::DataManager::CACHE_PATH
  end

  getter :photos, :exifs, :cache_path

  def exif_db_file_path
    return File.join([@cache_path, "exifs.yml"])
  end

  def load_exif_entities
    return unless File.exists?(exif_db_file_path)
    @logger.debug("#{self.class}: loading exif db")
    @exifs = Array(ExifEntity).from_yaml(File.open(exif_db_file_path))
  end

  def save_exif_entities
    @logger.debug("#{self.class}: save_exif_entities exifs_dirty=#{@exifs_dirty}")
    # not need to overwrite if no exif data was added
    return unless @exifs_dirty

    File.open(exif_db_file_path, "w") do |f|
      @exifs.to_yaml(f)
    end

    @logger.info("#{self.class}: save_exif_entities #{@exifs.size}")
  end

  def append_to_exifs(exif : ExifEntity)
    @exifs_dirty = true
    @exifs.not_nil! << exif
  end

  # search in @exifs, match and assign or generate
  def process_photo_entity(photo_entity : PhotoEntity)
    selected = @exifs.not_nil!.select do |e|
      e.post_slug == photo_entity.post_slug &&
        e.image_filename == photo_entity.image_filename
    end

    if selected.size == 0
      exif = ExifProcessor.process(
        photo_entity: photo_entity,
        path: @blog.data_path.as(String)
      )

      append_to_exifs(exif)

      # periodically save exifs
      if @exifs.not_nil!.size % BATCH_SAVE_COUNT == 0
        save_exif_entities
      end
    else
      exif = selected.first
    end

    photo_entity.exif = exif

    @photos.not_nil! << photo_entity

    return photo_entity
  end
end
