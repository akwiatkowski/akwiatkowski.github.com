class Tremolite::ModWatcher
  EXIF_DB_KEY = "exif_db"

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

  # return true if something was changed
  def compare_exif_db?
    return compare(EXIF_DB_KEY, current_exif_db)
  end

  def mark_updated_exif_db!
    @logger.debug("#{self.class}: mark_updated_exif_db!")
    set(EXIF_DB_KEY, current_exif_db)
  end
end
