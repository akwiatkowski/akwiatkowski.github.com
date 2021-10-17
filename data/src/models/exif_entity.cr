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

  @@lenses_dictionary = Array(String).new
  @@cameras_dictionary = Array(String).new

  def self.lenses_dictionary
    return @@lenses_dictionary
  end

  def self.cameras_dictionary
    return @@cameras_dictionary
  end

  def self.log_not_named
    lenses_dictionary.each do |lens|
      Log.error { "lens '#{lens}' not in dictionary" } if LENS_NAMES[lens]?.nil?
    end

    cameras_dictionary.each do |camera|
      Log.error { "camera '#{camera}' not in dictionary" } if CAMERA_NAMES[camera]?.nil?
    end

    Log.info { "#{lenses_dictionary.size} lenses and #{cameras_dictionary.size} cameras from exifs" }
  end

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
    "ILCE-7M3"            => "Sony A7 III",
    "ILCE-7R"             => "Sony A7R",
    "ILCE-7RM3"           => "Sony A7R III",
    "E-M1MarkII"          => "Olympus M1m2",
    "E-M10MarkII"         => "Olympus M10m2",
    "Hero3-Black Edition" => "Gopro 3 Black",
    "PENTAX K-S2"         => "Pentax K-S2",
    "PENTAX K100D"        => "Pentax K100D",
    "PENTAX K-5"          => "Pentax K-5",
    "FC1102"              => "DJI Spark",
  }

  LENS_NAMES = {
    "FE 85mm F1.8"                                 => "Sony 85mm f1.8",
    "E 28-75mm F2.8-2.8"                           => "Tamron 28-75mm f2.8",
    "100-400mm F5-6.3 DG DN OS | Contemporary 020" => "Sigma 100-400mm f5-6.3",
    "LUMIX G VARIO 14-140/F3.5-5.6"                => "Lumix 14-140mm",
    "OLYMPUS M.12-100mm F4.0"                      => "Olympus 12-100mm f4",
    "LUMIX G 20/F1.7 II"                           => "Lumix 20mm f1.7",
    "M.40-150mm F2.8 + MC-14"                      => "Olympus 40-150mm f2.8 + TC 1.4x",
    "M.40-150mm F2.8 + MC-20"                      => "Olympus 40-150mm f2.8 + TC 2.0x",
    "E 20mm F2"                                    => "Tokina 20mm f2",
    "OLYMPUS M.40-150mm F2.8"                      => "Olympus 40-150mm f2.8",
    "OLYMPUS M.9-18mm F4.0-5.6"                    => "Olympus 9-18mm",
    "OLYMPUS M.60mm F2.8 Macro"                    => "Olympus 60mm Macro",
    "smc PENTAX-DA 16-45mm F4 ED AL"               => "Pentax DA 16-45mm f4",
    "smc PENTAX-DA 15mm F4 ED AL Limited"          => "Pentax Limited 15mm f4",
    "OLYMPUS M.75-300mm F4.8-6.7 II"               => "Olympus 75-300mm",
    "Sigma 150-500mm F5-6.3 APO DG OS HSM"         => "Sigma 150-500mm",
    "smc PENTAX-FA Macro 50mm F2.8"                => "Pentax FA 50mm Macro",
    "OLYMPUS M.25mm F1.2"                          => "Olympus 25mm f1.2",
    "smc PENTAX-DA 70mm F2.4 Limited"              => "Pentax Limited 70mm f2.4",
    "smc PENTAX-DA 40mm F2.8 Limited"              => "Pentax Limited 40mm f2.8",
    "smc PENTAX-DA 35mm F2.4 AL"                   => "Pentax DA 35mm f2.4",
    "OLYMPUS M.17mm F1.2"                          => "Olympus 17mm f1.2",
    "LEICA DG SUMMILUX 25/F1.4"                    => "Lumix 25mm f1.4",
    "Sigma Lens"                                   => "Nieznane",
    "A Series Lens"                                => "Nieznane",
    "K or M Lens"                                  => "Nieznane",
    "OLYMPUS M.75mm F1.8"                          => "Olympus 75mm f1.8",
    "LEICA DG 8-18/F2.8-4.0"                       => "Lumix 8-18mm",
    "OLYMPUS M.8mm F1.8"                           => "Olympus 8mm f1.8",
    "105mm F1.4 DG HSM | Art 018"                  => "Sigma 105mm f1.4",
    "OLYMPUS M.14-42mm F3.5-5.6 EZ"                => "Olympus 14-42mm Kit",
    "OLYMPUS M.14-42mm F3.5-5.6 II R"              => "Olympus 14-42mm Kit",
    "Sigma 17-50/2.8"                              => "Sigma 17-50mm/2.8",
    "Sigma 10-20"                                  => "Sigma 10-20mm",
    "Pentax FA 50mm Macro"                         => "Pentax FA 50mm F2.8",
    "Ports 55/1.2"                                 => "Ports 55mm f1.2",
    "Sigma 18-200 old"                             => "Sigma 18-200mm (old)",
    "Sigma 18-200 C"                               => "Sigma 18-200mm C",
    "FE 70-200mm F2.8 GM OSS"                      => "Sony GM 70-200mm f2.8",
    "----"                                         => "Nieznane",
    "Pentax SMC-A 135/2.8"                         => "Pentax A 135mm f2.8",
    "M.300mm F4.0 + MC-14"                         => "Olympus 300mm f4 + TC 1.4x",
    "M.300mm F4.0 + MC-20"                         => "Olympus 300mm f4 + TC 2.0x",
    "OLYMPUS M.300mm F4.0"                         => "Olympus 300mm f4",
  }

  NAMES = CAMERA_NAMES.merge(LENS_NAMES)

  UNKNOWN_LENS = LENS_NAMES["Sigma Lens"]

  def camera_name
    if @camera_name.to_s == ""
      @camera_name = self.camera

      if self.camera
        unless @@cameras_dictionary.includes?(self.camera.not_nil!.strip)
          @@cameras_dictionary << self.camera.not_nil!
        end

        @camera_name = NAMES[self.camera.not_nil!.strip].to_s if NAMES[self.camera.not_nil!.strip]?
      end
    end
    return @camera_name
  end

  def lens_name
    if @lens_name.to_s == ""
      @lens_name = self.lens

      if self.lens
        unless @@lenses_dictionary.includes?(self.lens.not_nil!.strip)
          @@lenses_dictionary << self.lens.not_nil!
        end

        @lens_name = NAMES[self.lens.not_nil!.strip].to_s if NAMES[self.lens.not_nil!.strip]?
      end

      fix_lens_name
    end

    return @lens_name
  end

  private def focal_length_int
    return @focal_length.not_nil!.to_i
  end

  private def fix_lens_name
    # if there is lens set (other than unknown)
    return unless @lens_name.to_s == UNKNOWN_LENS
    # no focal length -> no lens
    return if @focal_length.nil?

    # Pentax A lens and 50mm it's 50mm macro
    if self.lens == "A Series Lens" && focal_length_int == 50
      @lens_name = LENS_NAMES["Pentax FA 50mm Macro"]
      return
    end

    # no contact lens and 55mm, it's weird Ports 55/1.2
    if self.lens == "K or M Lens" && focal_length_int == 55
      @lens_name = LENS_NAMES["Ports 55/1.2"]
      return
    end

    # no contact or manual contact lens and 135mm, it's SMC-A 135mm
    if (self.lens == "K or M Lens" || self.lens == "") && focal_length_int == 135
      @lens_name = LENS_NAMES["Pentax SMC-A 135/2.8"]
      return
    end

    # shitty K100D with sigma lens was in most cases old shitty Sigma 18-200
    if self.camera == "PENTAX K100D" && self.lens == "Sigma Lens"
      if focal_length_int >= 18 && focal_length_int <= 200
        @lens_name = LENS_NAMES["Sigma 18-200 old"]
        return
      end
    end

    # 50mm macro was used heavily with K100D
    if self.camera == "PENTAX K100D" && focal_length_int == 50
      @lens_name = LENS_NAMES["smc PENTAX-FA Macro 50mm F2.8"]
      return
    end

    # weird case but K-S2 didn't store lens name
    # K5 was better in this case
    if is_pentax_ks2?
      if focal_length_int == 15
        # 15mm limited most of the time, sigma 10-20 very rarely
        @lens_name = LENS_NAMES["smc PENTAX-DA 15mm F4 ED AL Limited"]
      elsif focal_length_int == 70
        # 70mm most often, sigma 18-200 very uncommon
        @lens_name = LENS_NAMES["smc PENTAX-DA 70mm F2.4 Limited"]
      elsif focal_length_int == 40
        # sigma 17-50 possible but lets mark it as 40mm limited
        @lens_name = LENS_NAMES["smc PENTAX-DA 40mm F2.8 Limited"]
      elsif focal_length_int >= 17 && focal_length_int <= 50
        # sometime it was Pentax 50mm macro but
        # because I used sigma 17-50 at full zoom quite often
        # it's not possible to fix it
        @lens_name = LENS_NAMES["Sigma 17-50/2.8"]
      elsif focal_length_int >= 18 && focal_length_int <= 200
        # overlapping hard with sigma 17-50
        @lens_name = LENS_NAMES["Sigma 18-200 C"]
      elsif focal_length_int >= 150 && focal_length_int <= 500
        # >200mm it's only sigma 150-500mm
        @lens_name = LENS_NAMES["Sigma 150-500mm F5-6.3 APO DG OS HSM"]
      elsif focal_length_int >= 10 && focal_length_int <= 20
        # used for some landscape photos
        @lens_name = LENS_NAMES["Sigma 10-20"]
      else
        @lens_name = LENS_NAMES["K or M Lens"]
      end
    end
  end

  private def is_pentax_ks2?
    return true if self.camera == "PENTAX K-S2"
    return false
  end
end
