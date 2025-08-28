class ExifProcessor
  Log = ::Log.for(self)

  PROCESSED_KEYS = [
    "Exif.GPSInfo.GPSAltitude",
    "Exif.GPSInfo.GPSLongitude",
    "Exif.GPSInfo.GPSLatitude",
    "Exif.GPSInfo.GPSLongitudeRef",
    "Exif.GPSInfo.GPSLatitudeRef",
    "Exif.Photo.FocalLength",
    "Exif.Photo.FocalLengthIn35mmFilm",
    "Exif.Photo.FNumber",
    "Exif.Photo.LensModel",
    "Exif.Image.Model",

    "Exif.Photo.PixelXDimension",
    "Exif.Photo.PixelYDimension",
    "Exif.Photo.ExposureTime",

    "Exif.Image.DateTimeOriginal",
    "Exif.Image.DateTime",
    "Exif.Photo.DateTimeOriginal",

    "Exif.OlympusFi.FocusDistance",

    "Exif.Photo.ISOSpeedRatings", # ISO
  ]

  TODO_KEYS = [
    "Exif.OlympusFi.SensorTemperature",

    "Exif.OlympusCs.WhiteBalanceTemperature",
    "Exif.Pentax.Temperature",
  ]

  # on mac "15 deg 56' 48.45" - there is space after first number
  GEO_DEGREE_REGEXP = /(\d+)\s*deg\s+(\d+)'\s+([0-9.]+)/

  def self.process(photo_entity, path) : ExifEntity
    path = File.join([path, photo_entity.full_image_src])
    hash = result(path)

    exif = ExifEntity.new(
      post_slug: photo_entity.post_slug,
      image_filename: photo_entity.image_filename,
    )

    # and now some custom data

    # original image dimension
    if hash["Exif.Photo.PixelXDimension"]?
      exif.width = hash["Exif.Photo.PixelXDimension"].to_i
    end
    if hash["Exif.Photo.ImageWidth"]?
      exif.width ||= hash["Exif.Photo.ImageWidth"].to_i
    end

    if hash["Exif.Photo.PixelYDimension"]?
      exif.height = hash["Exif.Photo.PixelYDimension"].to_i
    end
    if hash["Exif.Photo.ImageLength"]?
      exif.height ||= hash["Exif.Photo.ImageLength"].to_i
    end

    if hash["Exif.Photo.DateTimeOriginal"]?
      time = Time.parse(
        time: hash["Exif.Photo.DateTimeOriginal"],
        pattern: "%Y:%m:%d %H:%M:%S",
        location: Time::Location.local,
      )
      exif.time = time
    end

    # GPS altitude
    if hash["Exif.GPSInfo.GPSAltitude"]?
      exif.altitude = hash["Exif.GPSInfo.GPSAltitude"].gsub(/[a-z]/, "").to_f
    end

    # GPS coords
    if hash["Exif.GPSInfo.GPSLongitude"]?.to_s.size > 1 && hash["Exif.GPSInfo.GPSLatitude"]?.to_s.size > 1
      # "15deg 47' 41.705\""
      if match = hash["Exif.GPSInfo.GPSLongitude"].match(GEO_DEGREE_REGEXP)
        decimal = convert_degree_to_decimal(
          degree: match[1].to_s.to_f,
          minutes: match[2].to_s.to_f,
          seconds: match[3].to_s.to_f,
        )

        if hash["Exif.GPSInfo.GPSLongitudeRef"] == "West"
          decimal *= -1.0
        end

        exif.lon = decimal
      else
        Log.error { "photo '#{path}' lon '#{hash["Exif.GPSInfo.GPSLongitude"]? }' regexp not match" }
      end

      if match = hash["Exif.GPSInfo.GPSLatitude"].match(GEO_DEGREE_REGEXP)
        decimal = convert_degree_to_decimal(
          degree: match[1].to_s.to_f,
          minutes: match[2].to_s.to_f,
          seconds: match[3].to_s.to_f,
        )

        if hash["Exif.GPSInfo.GPSLatitudeRef"] == "South"
          decimal *= -1.0
        end

        exif.lat = decimal
      else
        Log.error { "photo '#{path}' lat '#{hash["Exif.GPSInfo.GPSLatitude"]? }' regexp not match" }
      end
    end

    # lens focal length
    if hash["Exif.Photo.FocalLength"]?
      focal_value = hash["Exif.Photo.FocalLength"].gsub(/[a-z]/, "").to_f

      if focal_value > 0.0
        exif.focal_length = focal_value
      end
    end
    if hash["Exif.Photo.FocalLengthIn35mmFilm"]? &&
       hash["Exif.Photo.FocalLengthIn35mmFilm"]?.to_s.strip != "Unknown"
      # puts hash.to_yaml
      exif.focal_length_35 = hash["Exif.Photo.FocalLengthIn35mmFilm"].gsub(/[a-z]/, "").to_f
    end

    # crop info processing
    # calculate from existing `focal_length_35`
    if exif.focal_length_35 && exif.focal_length
      exif.crop = exif.focal_length_35.not_nil!.to_f / exif.focal_length.not_nil!.to_f
    end
    # if it's olympus - crop 2x and calculate `focal_length_35`
    if hash["Exif.Image.Make"]? && hash["Exif.Image.Make"].to_s.downcase.index("olymp")
      exif.crop ||= 2.0
    end
    # if it's olympus - crop 2x and calculate `focal_length_35`
    if hash["Exif.Image.Make"]? && hash["Exif.Image.Make"].to_s.downcase.index("pentax")
      exif.crop ||= 1.5
    end
    # XXX add Sony?
    # calculate `focal_length_35` using `focal_length` and `crop`
    if exif.crop && exif.focal_length
      exif.focal_length_35 ||= exif.focal_length.not_nil!.to_f * exif.crop.not_nil!.to_f
    end

    # lens aperture
    if hash["Exif.Photo.FNumber"]?
      exif.aperture = hash["Exif.Photo.FNumber"].gsub(/[A-Z]/, "").to_f
    end

    # ISO
    if hash["Exif.Photo.ISOSpeedRatings"]?
      exif.iso = hash["Exif.Photo.ISOSpeedRatings"].gsub(/[A-Z]/, "").to_i
    end

    # exposure time
    if hash["Exif.Photo.ExposureTime"]?
      exif.exposure_string = hash["Exif.Photo.ExposureTime"]

      if hash["Exif.Photo.ExposureTime"]? =~ /(\d+)\s*s/
        # more than second
        exif.exposure = $1.to_s.to_f
      end

      if hash["Exif.Photo.ExposureTime"]? =~ /1\/(\d+)\s*s/
        # fraction of second
        exif.exposure = 1.0 / $1.to_s.to_f
      end
    end

    if hash["Exif.Photo.LensModel"]?
      exif.lens = hash["Exif.Photo.LensModel"].to_s
    end
    if hash["Exif.Pentax.LensType"]?
      exif.lens ||= hash["Exif.Pentax.LensType"].to_s
    end

    if hash["Exif.Image.Model"]?
      exif.camera = hash["Exif.Image.Model"].to_s
    end

    if hash["Exif.OlympusFi.FocusDistance"]?
      if hash["Exif.OlympusFi.FocusDistance"] == "Infinity"
        # inifity
        exif.focus_distance = 1000.0
      else
        exif.focus_distance = hash["Exif.OlympusFi.FocusDistance"].to_s.gsub(/[a-z]/, "").to_f
      end
    end

    return exif
  end

  def self.convert_degree_to_decimal(degree, minutes, seconds)
    # https://www.latlong.net/degrees-minutes-seconds-to-decimal-degrees
    return degree.to_f + (minutes.to_f / 60.0) + (seconds.to_f / 3600.0)
  end

  def self.command(path)
    "exiv2 -pt #{path}"
  end

  def self.result(path)
    result = `#{command(path)}`

    hash = Hash(String, String).new
    result.each_line do |line|
      # puts line
      if line =~ /(\S+)\s+(\S+)\s+(\S+)\s+(.+)/
        hash[$1.to_s.strip] = $4.to_s.strip
      end
    end

    return hash
  end
end
