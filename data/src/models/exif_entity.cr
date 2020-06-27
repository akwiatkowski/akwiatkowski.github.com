struct ExifEntity
  Log = ::Log.for(self)

  # used for mapping
  @image_filename : String
  @post_slug : String

  @lat : (Float64 | Nil)
  @lon : (Float64 | Nil)
  @altitude : (Float64 | Nil)
  @focal_length : (Float64 | Nil)
  @focal_length_35 : (Float64 | Nil)
  @crop : (Float64 | Nil)
  @aperture : (Float64 | Nil)
  @exposure : (Float64 | Nil)
  @exposure_string : (String | Nil)
  @focus_distance : (Float64 | Nil)
  @iso : Int32?

  @width : (Int32 | Nil)
  @height : (Int32 | Nil)

  @lens : (String | Nil)
  @camera : (String | Nil)

  @time : (Time | Nil)

  property :lat, :lon, :altitude, :focal_length, :aperture
  property :lens, :camera, :iso

  def initialize(@image_filename, @post_slug)
  end

  YAML.mapping(
    image_filename: String,
    post_slug: String,
    lat: Float64?,
    lon: Float64?,
    altitude: Float64?,
    focal_length: Float64?,
    focal_length_35: Float64?,
    crop: Float64?,
    aperture: Float64?,
    iso: Int32?,
    lens: String?,
    camera: String?,
    width: Int32?,
    height: Int32?,
    exposure: Float64?,
    exposure_string: String?,
    time: Time?,
    focus_distance: Float64?,
  )

  JSON.mapping(
    image_filename: String,
    post_slug: String,
    lat: Float64?,
    lon: Float64?,
    altitude: Float64?,
    focal_length: Float64?,
    focal_length_35: Float64?,
    crop: Float64?,
    aperture: Float64?,
    iso: Int32?,
    lens: String?,
    camera: String?,
    width: Int32?,
    height: Int32?,
    exposure: Float64?,
    exposure_string: String?,
    time: Time?,
    focus_distance: Float64?,
  )

  def hash_for_partial
    data = Hash(String, String).new
    data["img.lat"] = lat.to_s
    data["img.lon"] = lon.to_s
    data["img.altitude"] = altitude.to_s
    data["img.time"] = time.to_s
    data
  end
end
