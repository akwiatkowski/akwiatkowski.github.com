class Tremolite::PostCollection
  # Late-bound dependencies that need custom types (ExifDb, PhotoTagEntity)
  property photo_tags : Array(PhotoTagEntity)?
  property exif_db : ExifDb?

  def each_post_file(&block : String -> Nil)
    Dir[File.join([@posts_path, "**", "*.#{@posts_ext}"])].sort.each do |post_path|
      block.call(post_path)
    end
  end
end
