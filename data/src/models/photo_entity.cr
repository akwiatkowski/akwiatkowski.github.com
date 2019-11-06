require "./exif_entity"

struct PhotoEntity
  @desc : String
  @image_filename : String
  @param_string : String
  @day_of_year : Int32
  @float_of_year : Float64
  @time : Time

  @post_url : String
  @post_time : Time
  @post_title : String
  @post_slug : String

  @is_gallery : Bool
  @is_header : Bool
  @is_timeline : Bool

  @big_thumb_image_src : String
  @gallery_thumb_image_src : String
  @thumb_image_src : String
  @full_image_src : String
  @small_image_src : String

  @exif : ExifEntity

  @tags : Array(String)

  FLAG_NOGALLERY = "nogallery"
  FLAG_NO_TIMELINE = "notimeline"
  FLAG_TIMELINE = "timeline"

  THUMB_PREFIX     = "thumb"
  BIG_THUMB_PREFIX = "big_thumb"
  GALLERY_THUMB_PREFIX = "gallery_thumb"
  SMALL_PREFIX     = "small"

  getter :desc, :image_filename, :is_gallery, :is_header, :is_timeline
  getter :thumb_image_src, :big_thumb_image_src, :gallery_thumb_image_src, :full_image_src, :small_image_src
  getter :time, :day_of_year, :float_of_year
  getter :tags, :nameless
  getter :post_title, :post_time, :post_slug, :post_url

  property :exif

  def initialize(
    post : Tremolite::Post,
    @image_filename : String,
    @param_string,
    desc = nil,
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

    # nameless entities are uploaded not added in post content
    if desc.nil?
      @desc = @image_filename
      @nameless = true
    else
      @desc = desc
      @nameless = false
    end

    # copy data from Post to not store instance here
    @post_url = post.url
    @post_time = post.time.not_nil!
    @post_title = post.title
    @post_slug = post.slug

    # add tags
    param_string.split(/,/).each do |param_split|
      if param_split =~ /tag:(\w+)/
        @tags << $1.to_s
      end
    end

    # just optimization
    @big_thumb_image_src = processed_img_path(BIG_THUMB_PREFIX)
    @gallery_thumb_image_src = processed_img_path(GALLERY_THUMB_PREFIX)
    @thumb_image_src = processed_img_path(THUMB_PREFIX)
    @small_image_src = processed_img_path(SMALL_PREFIX)
    @full_image_src = generate_full_image_src

    @time = post.time
    @day_of_year = @time.day_of_year
    @float_of_year = @day_of_year.to_f / 365.0

    # all data fetched from exif will be stored here
    @exif = ExifEntity.new(
      post_slug: @post_slug,
      image_filename: @image_filename,
    )
  end

  def hash_for_partial(
    year_within_desc = false
  )
    data = Hash(String, String).new

    klass = @is_header ? "gallery-header-image" : "gallery-regular-image"
    klass += @is_timeline ? " gallery-is-timeline" : " gallery-is-not-timeline"

    data["klass"] = klass
    data["post.url"] = @post_url
    data["img.src"] = @gallery_thumb_image_src  # @big_thumb_image_src
    processed_desc = year_within_desc ? "#{@post_time.year} - #{@desc}": @desc
    data["img.alt"] = processed_desc
    data["img.title"] = processed_desc
    data["post.title"] = @post_title
    data["img.url"] = full_image_src

    data.merge!(self.exif.not_nil!.hash_for_partial)

    return data
  end

  def processed_img_path(prefix)
    Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: @post_time.year.as(Int32),
      post_month: @post_time.month.as(Int32),
      post_slug: @post_slug,
      prefix: prefix,
      file_name: @image_filename
    )
  end

  private def generate_full_image_src
    "/images/#{@post_time.year.as(Int32)}/#{@post_slug}/#{@image_filename}"
  end
end
