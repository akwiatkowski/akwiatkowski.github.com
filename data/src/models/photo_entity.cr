require "./exif_entity"

struct PhotoEntity
  Log = ::Log.for(self)

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
  @is_published : Bool

  @post_preview_image_src : String
  @gallery_thumb_image_src : String
  @map_thumb_image_src : String
  @masonry_image_src : String

  @full_image_src : String

  @exif : ExifEntity

  @tags : Array(String)
  # all possible tags will be stored here
  @@tags_dictionary = Array(String).new

  FLAG_NOGALLERY   = "nogallery"
  FLAG_NO_TIMELINE = "notimeline"
  FLAG_TIMELINE    = "timeline" # TODO convert to tag
  FLAG_MAP         = "map"

  POST_PREVIEW_PREFIX = "big_thumb"
  MASONRY_PREFIX      = "small"
  GALLERY_PREFIX      = "gallery"
  MAP_PREFIX          = "gallery_thumb"

  TAG_GOOD = "good"
  TAG_BEST = "best"
  TAG_CAT  = "cat"
  TAG_MACRO = "macro"
  TAG_BIRD = "bird"
  TAG_WINTER = "winter"
  TAG_TIMELINE = "timeline"
  TAG_TRANSPORT = "transport"
  TAG_WATER = "water"
  TAG_SUNRISE = "sunrise"
  TAG_CITY = "city"

  TAG_GALLERIES = [
    TAG_MACRO,
    TAG_CAT,
    "portfolio",
    TAG_GOOD,
    TAG_BEST,
    TAG_TIMELINE,
    TAG_BIRD,
  ].sort

  # https://fontawesome.com/
  TAG_BOOTSTRAP_ICON = {
    TAG_GOOD => "check-circle-fill",
    TAG_BEST => "gem",
    TAG_CAT => "eye-fill",
    TAG_MACRO => "droplet",
    TAG_BIRD => "binoculars",
    TAG_WINTER => "snow3",
    TAG_TIMELINE => "calendar-date",
    TAG_TRANSPORT => "gear_wide",
    TAG_WATER => "water",
    TAG_SUNRISE => "sunrise",
    TAG_CITY => "shop",
  }
  # https://icons.getbootstrap.com
  # tree signpost-fill

  getter :desc, :image_filename, :is_gallery, :is_header, :is_timeline, :is_map, :is_published
  getter :post_preview_image_src, :gallery_thumb_image_src, :full_image_src, :masonry_image_src, :map_thumb_image_src
  getter :full_image_sanitized
  getter :time, :day_of_year, :float_of_year
  getter :tags, :nameless
  getter :post_title, :post_time, :post_slug, :post_url, :param_string

  property :exif

  def initialize(
    post : Tremolite::Post,
    @image_filename : String,
    @param_string,
    desc = nil,
    @is_gallery = true,
    @is_header = false,
    @is_timeline = false,
    @is_map = false,
    @is_published = false,
    @tags = Array(String).new
  )
    # nameless entities are uploaded not added in post content
    if desc.nil?
      @desc = @image_filename
      @nameless = true
    else
      @desc = desc
      @nameless = false
    end

    update_from_param_string

    # copy data from Post to not store instance here
    @post_url = post.url
    @post_time = post.time.not_nil!
    @post_title = post.title
    @post_slug = post.slug

    # just optimization
    @post_preview_image_src = processed_img_path(POST_PREVIEW_PREFIX)
    @gallery_thumb_image_src = processed_img_path(GALLERY_PREFIX)
    @masonry_image_src = processed_img_path(MASONRY_PREFIX)
    @map_thumb_image_src = processed_img_path(MAP_PREFIX)

    @full_image_src = generate_full_image_src
    @full_image_sanitized = @full_image_src.gsub(/\W/, "_").as(String)

    @time = post.time
    @day_of_year = @time.day_of_year
    @float_of_year = @day_of_year.to_f / 365.0

    # all data fetched from exif will be stored here
    @exif = ExifEntity.new(
      post_slug: @post_slug,
      image_filename: @image_filename,
    )
  end

  def mark_as_published!
    @published = true
  end

  def is_good?
    return has_tag?(TAG_GOOD)
  end

  def is_best?
    return has_tag?(TAG_BEST)
  end

  def is_at_least_good?
    return is_good? || is_best?
  end

  # TODO add method for filtering by tags (portfolio, is header)
  # TODO add method calc photo quality (tags, header, published, time...)

  def has_tag?(tag : String)
    return @tags.includes?(tag)
  end

  def update_desc_and_params(new_desc, new_param_string)
    @desc = new_desc
    @nameless = false
    @param_string = new_param_string
    update_from_param_string
  end

  # params_string can be updated later for header photo
  # from post_function
  private def update_from_param_string
    if @param_string.includes?(FLAG_NOGALLERY)
      @is_gallery = false
    end

    if @param_string.includes?(FLAG_NO_TIMELINE)
      @is_timeline = false
    elsif @param_string.includes?(FLAG_TIMELINE)
      @is_timeline = true
    end

    if @param_string.includes?(FLAG_MAP)
      @is_map = true
    end

    # add tags
    @param_string.split(/,/).each do |param_split|
      if param_split =~ /tag:(\w+)/
        @tags << $1.to_s

        @@tags_dictionary << $1.to_s unless @@tags_dictionary.includes?($1.to_s)
      end
    end
  end

  def self.tags_dictionary
    return @@tags_dictionary
  end

  def hash_for_partial(
    year_within_desc = false
  )
    data = Hash(String, String).new

    klass = @is_header ? "gallery-header-image" : "gallery-regular-image"
    klass += @is_timeline ? " gallery-is-timeline" : " gallery-is-not-timeline"

    data["klass"] = klass
    data["post.url"] = @post_url
    data["img.src"] = @gallery_thumb_image_src
    processed_desc = year_within_desc ? "#{@post_time.year} - #{@desc}" : @desc
    data["img.alt"] = processed_desc
    data["img.title"] = processed_desc
    data["post.title"] = @post_title
    data["img.url"] = full_image_src
    data["img.full_image_sanitized"] = full_image_sanitized

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

  def <=>(other : PhotoEntity)
    if other.exif && self.exif && other.exif.time && self.exif.time
      return self.exif.time.not_nil! <=> other.exif.time.not_nil!
    else
      return self.image_filename <=> other.image_filename
    end
  end

  private def generate_full_image_src
    "/images/#{@post_time.year.as(Int32)}/#{@post_slug}/#{@image_filename}"
  end
end
