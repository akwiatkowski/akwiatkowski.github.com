class Tremolite::ImageResizer
  Log = ::Log.for(self)

  @@sizez = {
    "article"   => {width: 1000, height: 800, quality: 85},
    "card"      => {width: 700, height: 525, quality: 82},
    "grid"      => {width: 560, height: 420, quality: 80},
    "thumbnail" => {width: 150, height: 112, quality: 72},
  }
  @@quality = 70

  # AVIF quality ranges per size (min/max for avifenc)
  @@avif_settings = {
    "article"   => {min: 20, max: 40},
    "card"      => {min: 20, max: 40},
    "grid"      => {min: 20, max: 40},
    "thumbnail" => {min: 20, max: 40},
  }

  PROCESSED_IMAGES_PATH         = File.join(["images", "processed"])
  PROCESSED_IMAGES_PATH_FOR_WEB = File.join(["/", "images", "processed"])

  def initialize(@data_path : String, @output_path : String)
    @processed_path = File.join([@output_path, PROCESSED_IMAGES_PATH])
    @flags = "-interlace Plane"
    # -strip - removed strip because it messed with color space, exif is ok
  end

  def resize_all_images_for_post(post : Tremolite::Post, overwrite : Bool)
    # iterate by all images in proper direcory
    path = File.join([@data_path, post.images_dir_url])
    Dir.mkdir_p(path) # unless File.exists?(path)
    Dir.entries(path).each do |name|
      if false == File.directory?(File.join([path, name]))
        resize_for_post(post: post, name: name, overwrite: overwrite)
      end
    end
  end

  # Use this method for all processed images paths
  def self.processed_path_for_post(
    processed_path : String,
    post_year : Int32,
    post_month : Int32,
    post_slug : String,
    prefix : String,
    file_name : String,
    format : String = "jpg",
  ) : String
    post_month_string = post_month < 10 ? "0#{post_month}" : post_month.to_s
    file_name_wo_ext = file_name.gsub(/\.(jpg|jpeg|png)$/i, "")

    return File.join([processed_path, post_year.to_s, post_month_string, "#{post_slug}_#{file_name_wo_ext}_#{prefix}.#{format}"])
  end

  def resize_for_post(post : Tremolite::Post, overwrite : Bool, name = "header.jpg")
    img_url = File.join([@data_path, "images", post.year.to_s, post.slug, name])
    if File.exists?(img_url)
      # there are defined sizes of output images
      @@sizez.each do |prefix, resolution|
        output_url = self.class.processed_path_for_post(
          processed_path: @processed_path,
          post_year: post.year,
          post_month: post.time.month,
          post_slug: post.slug,
          prefix: prefix,
          file_name: name
        )

        resize_image(
          path: img_url,
          width: resolution[:width],
          height: resolution[:height],
          output: output_url,
          quality: resolution[:quality],
          overwrite: overwrite
        )

        # Encode AVIF from the resized JPEG
        avif_settings = @@avif_settings[prefix]?
        if avif_settings
          avif_url = self.class.processed_path_for_post(
            processed_path: @processed_path,
            post_year: post.year,
            post_month: post.time.month,
            post_slug: post.slug,
            prefix: prefix,
            file_name: name,
            format: "avif"
          )

          encode_avif(
            jpeg_path: output_url,
            avif_path: avif_url,
            min_q: avif_settings[:min],
            max_q: avif_settings[:max],
            overwrite: overwrite
          )
        end
      end
    end
  end

  def resize_image(
    path : String,
    width : Int32,
    height : Int32,
    output : String,
    overwrite : Bool,
    quality = 70,
  )
    Dir.mkdir_p_dirname(output)

    # IMv7: input before flags
    command = "magick \"#{path}\" #{@flags} -quality #{quality} -resize #{width}x#{height} \"#{output}\""

    if overwrite || false == File.exists?(output)
      Log.info { "JPEG #{path} - #{width}x#{height}" }
      `#{command}`
    end
  end

  # Encode AVIF from resized JPEG (avifenc reads JPEG directly)
  private def encode_avif(jpeg_path : String, avif_path : String, min_q : Int32, max_q : Int32, overwrite : Bool)
    Dir.mkdir_p_dirname(avif_path)

    if overwrite || false == File.exists?(avif_path)
      if File.exists?(jpeg_path)
        Log.info { "AVIF #{avif_path}" }
        `avifenc -s 6 -j 4 --min #{min_q} --max #{max_q} "#{jpeg_path}" "#{avif_path}" 2>&1`
        Log.warn { "AVIF encode failed: #{jpeg_path}" } unless $?.success?
      end
    end
  end

  # deprecated
  def self.download_image(source : String, output : String)
    Dir.mkdir_p_dirname(output)
    command = "wget \"#{source}\" -O \"#{output}\" "
    `#{command}`
  end

  def self.copy_image(source : String, output : String)
    Dir.mkdir_p_dirname(output)
    command = "cp \"#{source}\" \"#{output}\" "
    `#{command}`
  end
end
