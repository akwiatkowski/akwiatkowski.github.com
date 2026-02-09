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
  property exif_db : ExifDb?
  property photo_tags : Array(PhotoTagEntity)?
end
