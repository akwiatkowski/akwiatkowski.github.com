require "./models/poi_entity"
require "./models/photo_entity"

require "./post/helpers"
require "./post/accessors"
require "./post/initializers"
require "./post/photos"
require "./post/related_posts"
require "./post/areas"

class Tremolite::Post
  # Late-bound dependencies that need custom types (ExifDb, PhotoTagEntity)
  setter exif_db : ExifDb?
  getter! exif_db : ExifDb?
  setter photo_tags : Array(PhotoTagEntity)?
  getter! photo_tags : Array(PhotoTagEntity)?
end
