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

  @tags : Array(String)

  FLAG_NOGALLERY = "nogallery"
  FLAG_NO_TIMELINE = "notimeline"
  FLAG_TIMELINE = "timeline"

  THUMB_PREFIX     = "thumb"
  BIG_THUMB_PREFIX = "big_thumb"
  SMALL_PREFIX     = "small"

  getter :desc, :post, :image_filename, :is_gallery, :is_header, :is_timeline
  getter :thumb_image_src, :big_thumb_image_src, :full_image_src, :small_image_src
  getter :time, :day_of_year, :float_of_year
  getter :tags

  def initialize(
    @post : Tremolite::Post,
    @desc,
    @image_filename,
    @param_string,
    @is_gallery = true,
    @is_header = false,
    @is_timeline = false,
    @tags = Array(String).new
  )
    if param_string.includes?(FLAG_NOGALLERY)
      @is_gallery = false
    end

    if param_string.includes?(FLAG_NO_TIMELINE)
      @is_timeline = false
    elsif param_string.includes?(FLAG_TIMELINE)
      @is_timeline = true
    end

    # add tags
    param_string.split(/,/).each do |param_split|
      if param_split =~ /tag:(\w+)/
        @tags << $1.to_s
      end
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

  def hash_for_partial(
    year_within_desc = false
  )
    data = Hash(String, String).new

    klass = @is_header ? "gallery-header-image" : "gallery-regular-image"
    klass += @is_timeline ? " gallery-is-timeline" : " gallery-is-not-timeline"

    data["klass"] = klass
    data["post.url"] = @post.url
    data["img.src"] = @big_thumb_image_src
    processed_desc = year_within_desc ? "#{@post.time.year} - #{@desc}": @desc
    data["img.alt"] = processed_desc
    data["img.title"] = processed_desc
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
