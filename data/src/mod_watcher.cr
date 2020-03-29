class Tremolite::ModWatcher
  EXIF_DB_KEY = "exif_db"
  EXIF_POSTS = "posts"
  EXIF_YAMLS = "yamls"
  EXIF_SOURCE_CODE = "source_code"

  # get current info to
  def current_for(key : String) : ModHash
    if key == EXIF_DB_KEY
      return current_exif_db
    elsif key == EXIF_POSTS
      return current_posts
    elsif key == EXIF_YAMLS
      return current_yamls
    elsif key == EXIF_SOURCE_CODE
      return current_source_code
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

  def current_source_code
    files = Dir[File.join([@blog.data_path, "**", "*.cr"])]
    return list_of_files_to_mod_data(file_paths: files)
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

  # return true if something was changed
  def compare_exif_db?
    return compare(EXIF_DB_KEY, current_exif_db)
  end

  def mark_updated_exif_db!
    @logger.debug("#{self.class}: mark_updated_exif_db!")
    set(EXIF_DB_KEY, current_exif_db)
  end
end
