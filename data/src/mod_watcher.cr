class Tremolite::ModWatcher
  # Unfortunately there will be some edge cases when something will be not updated.
  # I can remove ModWatcher cache file and it will re-render all.
  # And this is suggested solution before pushing to server.
  #
  # While writing/developing it would be good idea to not need to render
  # _everything_ when changing one file. I need to think about most possible cases.
  #
  # The next step will be to have blog exec be run in memory and wait for
  # any file to be changed.
  #
  # The most important is source code - *View classes. In-memory won't help
  # with this case.
  # 1) Store viewer classes modification time
  # TODO Though it's not super useful I think it would be a good idea to
  # have every *View class it's key and store mtime. It could allow forcing
  # re-render a bit easier.
  #
  # Second most important is html layout. Changing html has direct impact to
  # html output.
  # 2) Layout, html include files
  # It could be possible to divide layout related html files to views related files
  # but it's not that important right now.
  # Let's ignore this now.
  #
  # Next steps are most important in my opinion.
  # 3) Posts
  # Something take a lot of time. It's probably checking all photos in post photos
  # paths.
  # PostGalleryStatsView takes about 0.15s per Post. I think this can be only
  # executed if KEY_EXIF_DB is updated
  #
  # 4) Exif db.
  # Normally it's updated after I create post and add photos to that post.
  # We don't need to rerender photo_map, galleries, (what else?) if there
  # are not new photos.
  # DONE - it's updated only whe
  # TODO: test this adding new photos and check if it run photo_map
  #
  # 5) Towns
  # It's totally low priority. Rendering towns list is very fast.

  # Matrix:
  # 1) KEY_POSTS_FILES
  # 1) KEY_EXIF_DB - PostGalleryStatsView, galleries,

  KEY_POSTS_FILES = "posts"
  # size of all photos in data/images/**
  KEY_PHOTOS = "photos"
  KEY_EXIF_DB = "exif_db"
  KEY_YAMLS = "yamls"
  KEY_OVERALL_SOURCE_CODE = "source_code"

  # it's stored like other but compared differently
  # we want to have info which posts were changed and update only that
  KEY_POSTS_MTIME = "posts_mtime"
  # store number of photos (images located within path)
  KEY_POSTS_PHOTO_COUNTS = "posts_photo_count"
  # store number of photos (images added in post content)
  KEY_POSTS_PHOTO_IN_POST_COUNTS = "posts_photo_in_post_count"

  ALL_STATIC_KEYS = [
    KEY_POSTS_FILES,
    KEY_EXIF_DB,
    KEY_YAMLS,
    KEY_OVERALL_SOURCE_CODE,
  ]

  ALL_DYNAMIC_KEYS = [
    KEY_POSTS_MTIME,
    KEY_POSTS_PHOTO_COUNTS,
    KEY_POSTS_PHOTO_IN_POST_COUNTS,
  ]

  ALL_KEYS = ALL_STATIC_KEYS + ALL_DYNAMIC_KEYS

  # get current info to
  def current_for(key : String) : ModHash
    if key == KEY_EXIF_DB
      return current_exif_db
    elsif key == KEY_POSTS_FILES
      return current_posts
    elsif key == KEY_PHOTOS
      return current_photos
    elsif key == KEY_YAMLS
      return current_yamls
    elsif key == KEY_OVERALL_SOURCE_CODE
      return current_source_code

    elsif key == KEY_POSTS_MTIME
      return current_posts_detailed_mtime
    elsif key == KEY_POSTS_PHOTO_COUNTS
      return current_posts_detailed_all_photo_count
    elsif key == KEY_POSTS_PHOTO_IN_POST_COUNTS
      return current_posts_detailed_published_photo_count

    else
      return ModHash.new
    end
  end

  # mtime and size of exif yaml file decide if we need to re-render
  def current_exif_db
    path = @blog.data_manager.not_nil!.exif_db_file_path
    size = ""
    mtime = ""

    if File.exists?(path)
      fi = File.info(path)
      size = fi.size.to_s
      mtime = fi.modification_time.to_unix.to_s
    end

    h = ModHash.new
    h["size"] = size
    h["mtime"] = mtime

    return h
  end

  def current_yamls
    files = Dir[File.join([@blog.data_path, "**", "*.yml"])]
    # ["data/tags.yml", "data/todo_routes_done.yml", "data/todo_routes.yml", "data/towns/voivodeships/pomorskie.yml", "data/towns/voivodeships/podkarpackie.yml", "data/towns/voivodeships/zachodnio_pomorskie.yml", "data/towns/voivodeships/dolnoslaskie.yml", "data/towns/voivodeships/lubuskie.yml", "data/towns/voivodeships/kujawsko_pomorskie.yml", "data/towns/voivodeships/malopolskie.yml", "data/towns/voivodeships/slaskie.yml", "data/towns/voivodeships/podlaskie.yml", "data/towns/voivodeships/wielkopolskie.yml", "data/towns/voivodeships/warminsko_mazurskie.yml", "data/towns/voivodeships/opolskie.yml", "data/towns/other.yml", "data/towns/voivodeships.yml", "data/lands.yml", "data/transport_pois.yml", "data/config.yml", "data/land_types.yml"]

    return list_of_files_to_mod_data(file_paths: files)
  end

  # number of posts, latest mtime, size of all posts (markdown file)
  # TODO towns, ... ?
  def current_posts
    return list_of_files_to_mod_data(
      file_paths: @blog.post_collection.posts.map { |post| post.path }
    )
  end

  # check if there are photos added into data/images
  def current_photos
    files = Dir[File.join([@blog.data_path, "images", "**", "*"])]
    return list_of_files_to_mod_data(file_paths: files)
  end

  def current_source_code
    files = Dir[File.join([@blog.data_path, "**", "*.cr"])]
    return list_of_files_to_mod_data(file_paths: files)
  end

  def current_posts_detailed_mtime
    h = ModHash.new

    @blog.post_collection.posts.each do |post|
      fi = File.info(post.path)
      h[post.slug] = fi.modification_time.to_local.to_s
    end

    return h
  end

  def current_posts_detailed_all_photo_count
    h = ModHash.new

    @blog.post_collection.posts.each do |post|
      h[post.slug] = post.list_of_uploaded_photos.size.to_s
    end

    return h
  end

  def current_posts_detailed_published_photo_count
    h = ModHash.new

    @blog.post_collection.posts.each do |post|
      h[post.slug] = post.photo_entities.not_nil!.size.to_s
    end

    return h
  end

  # return ALL_STATIC_KEYS and dynamic (posts)
  def all_mod_watchers : NamedTuple(static: Array(String), posts_mtime: Array(String), photo_count: Array(String))
    static = Array(String).new
    posts = Array(String).new
    photo_counts = Array(String).new

    # return keys of all changed
    ALL_STATIC_KEYS.each do |k|
      static << k if compare(k)
    end

    # and compare Post mtimes
    stored_mtimes = get(KEY_POSTS_MTIME) || ModHash.new
    current_mtimes = current_posts_detailed_mtime

    current_mtimes.keys.each do |k|
      posts << k if stored_mtimes[k]? != current_mtimes[k]
    end

    # and compare Post all photo counts
    stored_p_counts = get(KEY_POSTS_PHOTO_COUNTS) || ModHash.new
    current_p_counts = current_posts_detailed_all_photo_count

    current_p_counts.keys.each do |k|
      photo_counts << k if stored_p_counts[k]? != current_p_counts[k]
    end

    # and compare Post published photo counts
    stored_p_counts = get(KEY_POSTS_PHOTO_IN_POST_COUNTS) || ModHash.new
    current_p_counts = current_posts_detailed_published_photo_count

    current_p_counts.keys.each do |k|
      photo_counts << k if stored_p_counts[k]? != current_p_counts[k]
    end

    # use this in array because they are related
    photo_counts = photo_counts.uniq

    return {
      static: static,
      posts_mtime: posts,
      photo_count: photo_counts,
    }
  end

  # refresh before saving to have all data updated
  def refresh
    ALL_KEYS.each do |static_key|
      set(key: static_key)
    end
  end

  private def list_of_files_to_mod_data(file_paths : Array(String))
    fa = file_paths.map do |path|
      fi = File.info(path)
      {
        size: fi.size,
        mtime: fi.modification_time.to_unix
      }
    end

    h = ModHash.new
    h["count"] = file_paths.size.to_s
    h["file_total_size"] = fa.map{|p| p[:size] }.sum.to_s
    h["file_latest_mtime"] = fa.map{|p| p[:mtime] }.max.to_s

    return h
  end
end
