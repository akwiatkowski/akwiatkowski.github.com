struct ExifEntity
  include YAML::Serializable
  include JSON::Serializable

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

  @lens_name : (String | Nil)
  @camera_name : (String | Nil)

  @time : (Time | Nil)

  property :lat, :lon, :altitude, :focal_length, :aperture
  property :lens, :camera, :iso, :exposure
  property :width, :height, :time, :focal_length_35, :crop, :exposure_string, :focus_distance

  getter :post_slug, :image_filename

  def initialize(@image_filename, @post_slug)
  end

  def hash_for_partial
    data = Hash(String, String).new
    data["img.lat"] = lat.to_s
    data["img.lon"] = lon.to_s
    data["img.altitude"] = altitude.to_s
    data["img.time"] = time.to_s
    data
  end

  def is_horizontal?
    return false if self.width.nil? || self.height.nil?
    return self.width.not_nil! > self.height.not_nil!
  end

  # safest way to process weird lens/camera names

  CAMERA_NAMES = {
    "ILCE-7M3" => "Sony A7 III",
    "ILCE-7R" => "Sony A7R",
    "ILCE-7RM3" => "Sony A7R III"
    "E-M1MarkII" => "Olympus M1m2",
    "E-M10MarkII" => "Olympus M10m2",
    "Hero3-Black Edition" => "Gopro 3 Black",
  }

  LENS_NAMES = {
    "FE 85mm F1.8" => "Sony 85 f1.8",
    "E 28-75mm F2.8-2.8" => "Tamron 28-75mm f2.8",
    "100-400mm F5-6.3 DG DN OS | Contemporary 020" => "Sigma 100-400mm f5-6.3",
    "LUMIX G VARIO 14-140/F3.5-5.6" => "Lumix 14-140mm",
    "OLYMPUS M.12-100mm F4.0" => "Olympus 12-100mm f4",
    "LUMIX G 20/F1.7 II" => "Lumix 20mm f1.7",
    "M.40-150mm F2.8 + MC-14" => "Olympus 40-150mm f2.8 + TC 1.4x",
    "E 20mm F2" => "Tokina 20mm f2",
    "OLYMPUS M.40-150mm F2.8" => "Olympus 40-140mm f2.8",
    "OLYMPUS M.9-18mm F4.0-5.6" => "Olympus 9-18mm",
    "OLYMPUS M.60mm F2.8 Macro" => "Olympus 60mm Macro",
    "smc PENTAX-DA 16-45mm F4 ED AL" => "Pentax DA 16-45mm f4",
    "smc PENTAX-DA 15mm F4 ED AL Limited" => "Pentax Limited 15mm f4",
    "OLYMPUS M.75-300mm F4.8-6.7 II" => "Olympus 75-300mm",
    "Sigma 150-500mm F5-6.3 APO DG OS HSM" => "Sigma 150-500mm",
    "smc PENTAX-FA Macro 50mm F2.8" => "Pentax FA 50mm Macro",
    "OLYMPUS M.25mm F1.2" => "Olympus 25mm f1.2",
    "smc PENTAX-DA 70mm F2.4 Limited" => "Pentax Limited 70mm f2.4",
    "smc PENTAX-DA 40mm F2.8 Limited" => "Pentax Limited 40mm f2.8",
    "smc PENTAX-DA 35mm F2.4 AL" => "Pentax DA 35mm f2.4",
    "OLYMPUS M.17mm F1.2" => "Olympus 17mm f1.2",
    "LEICA DG SUMMILUX 25/F1.4" => "Lumix 25mm f1.4",
    "Sigma Lens" => "Nieznane",
    "A Series Lens" => "Nieznane",
    "K or M Lens" => "Nieznane",
    "OLYMPUS M.75mm F1.8" => "Olympus 75mm f1.8",
    "LEICA DG 8-18/F2.8-4.0" => "Lumix 8-18mm",
    "OLYMPUS M.8mm F1.8" => "Olympus 8mm f1.8",
    "105mm F1.4 DG HSM | Art 018" => "Sigma 105mm f1.4",
    "OLYMPUS M.14-42mm F3.5-5.6 EZ" => "Olympus 14-42mm Kit"
  }

  NAMES = CAMERA_NAMES.merge(LENS_NAMES)

  def camera_name
    if @camera_name.nil?
      @camera_name = self.camera
      @camera_name = NAMES[self.camera].to_s if NAMES[self.camera]?
    end
    return @camera_name
  end

  def lens_name
    if @lens_name.nil?
      @lens_name = self.lens
      @lens_name = NAMES[self.lens].to_s if NAMES[self.lens]?
    end
    return @lens_name
  end
end
