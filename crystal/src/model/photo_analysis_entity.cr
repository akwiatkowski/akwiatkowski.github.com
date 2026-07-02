struct PhotoAnalysisEntity
  include YAML::Serializable
  include JSON::Serializable

  getter image_filename : String
  getter post_slug : String
  getter ahash : String
  getter dhash : String
  getter phash : String
  getter avg_rgb : Array(Int32)
  getter top5_rgb : Array(Array(Int32))

  def initialize(@image_filename, @post_slug, @ahash, @dhash, @phash, @avg_rgb, @top5_rgb)
  end
end
