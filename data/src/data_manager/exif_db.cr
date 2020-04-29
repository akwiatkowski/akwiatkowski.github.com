class ExifDb
  Log = ::Log.for(self)

  BATCH_SAVE_COUNT = 500

  def initialize(
    @blog : Tremolite::Blog
  )
    @cache_path = Tremolite::DataManager::CACHE_PATH

    # Post#slug
    # all exifs will be stored within PhotoEntity
    @exif_entities = Hash(String, Array(ExifEntity)).new
    @exif_entities_dirty = Hash(String, Bool).new

    @published_photo_entities = Hash(String, Array(PhotoEntity)).new
    @uploaded_photo_entities = Hash(String, Array(PhotoEntity)).new

    @loaded_posts = Hash(String, Bool).new
  end

  def published_photo_entities(post_slug : String) : Array(PhotoEntity)
    @published_photo_entities[post_slug]? || Array(PhotoEntity).new
  end

  def uploaded_photo_entities(post_slug : String) : Array(PhotoEntity)
    @uploaded_photo_entities[post_slug]? || Array(PhotoEntity).new
  end

  def all_flatten_photo_entities : Array(PhotoEntity)
    @published_photo_entities.values.flatten + @uploaded_photo_entities.values.flatten
  end

  # PE created from function while processing md file
  def append_published_photo_entity(photo_entity : PhotoEntity)
    exifed_pe = process_photo_entity(photo_entity)

    @published_photo_entities[exifed_pe.post_slug] ||= Array(PhotoEntity).new
    @published_photo_entities[exifed_pe.post_slug] << exifed_pe

    return exifed_pe
  end

  def append_uploaded_photo_entity(photo_entity : PhotoEntity)
    exifed_pe = process_photo_entity(photo_entity)

    @uploaded_photo_entities[exifed_pe.post_slug] ||= Array(PhotoEntity).new
    @uploaded_photo_entities[exifed_pe.post_slug] << exifed_pe

    return exifed_pe
  end

  def initialize_post_photos_exif(post : Tremolite::Post)
    return if @loaded_posts[post.slug]?

    # append header
    if post.header_photo_entity
      append_uploaded_photo_entity(post.header_photo_entity.not_nil!)
    end

    # we need populate published photos to not overadd them as uploaded
    post.populate_published_post

    published_filenames = published_photo_entities(post.slug).map do |pe|
      pe.image_filename
    end

    uploaded_filenames = post.list_of_uploaded_photos
    not_published_filenames = post.list_of_uploaded_photos - published_filenames

    Log.debug { "not_published_filenames #{not_published_filenames.size}, uploaded_filenames #{uploaded_filenames.size}" }

    not_published_filenames.each do |uploaded_path|
      draft_photo_entity = PhotoEntity.new(
        post: post,
        image_filename: uploaded_path,
        param_string: "",
      )

      append_uploaded_photo_entity(draft_photo_entity)
    end

    # mark as loaded
    @loaded_posts[post.slug] = true
  end

  # this should load all existing caches and initialize photo_entities
  # for not it uses Post#all_uploaded_photo_entities which is not best idea
  def load_photo_entities
    @blog.post_collection.posts.each do |post|
      # TODO is it possible to move exif generate/load from function to here?
      # load_or_initialize_exif_for_post(post.slug)
      post.all_uploaded_photo_entities
    end
    @photo_entities_loaded = true
  end

  def save_cache(post_slug : String)
    dirty = @exif_entities_dirty[post_slug]?
    Log.debug { "save_exif_entities dirty=#{dirty}" }
    # not need to overwrite if no exif data was added
    return unless dirty

    File.open(exif_db_file_path(post_slug), "w") do |f|
      @exif_entities[post_slug].to_yaml(f)
    end

    Log.info { "save_exif_entities #{@exif_entities[post_slug].size}" }
  end

  def load_or_initialize_exif_for_post(post_slug : String)
    # do nothing if already initialized
    return if @exif_entities[post_slug]?

    path = exif_db_file_path(post_slug)
    if File.exists?(path)
      Log.debug { "loading exif for #{post_slug}" }
      @exif_entities[post_slug] = Array(ExifEntity).from_yaml(File.open(path))
      @exif_entities_dirty[post_slug] = false
    else
      Log.debug { "initializing exif for #{post_slug}" }
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
  private def process_photo_entity(photo_entity : PhotoEntity)
    load_or_initialize_exif_for_post(photo_entity.post_slug)

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

    return photo_entity
  end

  private def append_to_exifs(post_slug, exif)
    @exif_entities[post_slug] << exif
    @exif_entities_dirty[post_slug] = true
  end
end
