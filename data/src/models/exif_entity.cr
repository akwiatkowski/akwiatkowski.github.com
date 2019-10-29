struct ExifEntity
  # used for mapping
  @image_filename : String
  @post_slug : String

  @lat : (Float64 | Nil)
  @lon : (Float64 | Nil)
  @altitude : (Float64 | Nil)
  @focal_length : (Float64 | Nil)
  @aperture : (Float64 | Nil)

  @lens : (String | Nil)
  @camera : (String | Nil)

  property :lat, :lon, :altitude, :focal_length, :aperture
  property :lens, :camera

  def initialize(@image_filename, @post_slug)
  end

  YAML.mapping(
    image_filename: String,
    post_slug: String,
    lat: Float64?,
    lon: Float64?,
    altitude: Float64?,
    focal_length: Float64?,
    aperture: Float64?,
    lens: String?,
    camera: String?,
  )
end
