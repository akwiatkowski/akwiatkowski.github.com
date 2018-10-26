struct PhotoEntity
  @desc : String
  @post : Tremolite::Post
  @image_filename : String
  @param_string : String
  @day_of_year : Int32
  @float_of_year : Float64
  @time : Time

  @is_gallery : Bool
  @is_header : Bool
  @is_timeline : Bool

  @big_thumb_image_src : String
  @thumb_image_src : String
  @full_image_src : String
  @small_image_src : String

  FLAG_NOGALLERY = "nogallery"
  FLAG_NO_TIMELINE = "notimeline"
  FLAG_TIMELINE = "timeline"

  THUMB_PREFIX     = "thumb"
  BIG_THUMB_PREFIX = "big_thumb"
  SMALL_PREFIX     = "small"

  getter :desc, :post, :image_filename, :is_gallery, :is_header, :is_timeline
  getter :thumb_image_src, :big_thumb_image_src, :full_image_src, :small_image_src
  getter :time, :day_of_year, :float_of_year

  def initialize(
    @post : Tremolite::Post,
    @desc,
    @image_filename,
    @param_string,
    @is_gallery = true,
    @is_header = false,
    @is_timeline = false
  )
    if param_string.includes?(FLAG_NOGALLERY)
      @is_gallery = false
    end

    if param_string.includes?(FLAG_NO_TIMELINE)
      @is_timeline = false
    elsif param_string.includes?(FLAG_TIMELINE)
      @is_timeline = true
    end

    # just optimization
    @big_thumb_image_src = processed_img_path(BIG_THUMB_PREFIX)
    @thumb_image_src = processed_img_path(THUMB_PREFIX)
    @small_image_src = processed_img_path(SMALL_PREFIX)
    @full_image_src = generate_full_image_src

    @time = @post.time
    @day_of_year = @time.day_of_year
    @float_of_year = @day_of_year.to_f / 365.0
  end

  def hash_for_partial
    data = Hash(String, String).new
    data["klass"] = @is_header ? "gallery-header-image" : "gallery-regular-image"
    data["post.url"] = @post.url
    data["img.src"] = @big_thumb_image_src
    data["img.alt"] = @desc
    data["img.title"] = @desc
    data["post.title"] = @post.title
    data["img.url"] = full_image_src
    # data["img.size"] = "" # TODO
    return data
  end

  def processed_img_path(prefix)
    Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: @post.time.year.as(Int32),
      post_month: @post.time.month.as(Int32),
      post_slug: @post.slug,
      prefix: prefix,
      file_name: @image_filename
    )
  end

  private def generate_full_image_src
    "/images/#{@post.time.year.as(Int32)}/#{@post.slug}/#{@image_filename}"
  end
end
