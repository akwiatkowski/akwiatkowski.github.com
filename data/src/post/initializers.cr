alias PostRouteObject = Hash(String, (String | Array(Array(Float64))))

class Tremolite::Post
  def custom_initialize
    header_image_defaults

    basic_initialize
    tags_initialize
    towns_initialize
    lands_initialize
    pois_initialize
    coords_initialize
    published_photos_entities_initialize
    seo_initialize
  end

  def custom_process_header
    tags_from_headers
    towns_from_headers
    lands_from_headers
    pois_from_headers
    coords_from_headers
    basic_from_headers
    seo_from_headers
    finished_at_from_headers
    header_post_photo_from_headers
  end

  # TODO this will require a lot of operations
  def slow_process_header
    photos_entities_from_content
  end

  def tags_initialize
    @tags = Array(String).new
  end

  def tags_from_headers
    if @header["tags"]?
      @header["tags"].as_a.each do |tag|
        @tags.not_nil! << tag.to_s
      end
    end
  end

  def towns_initialize
    @towns = Array(String).new
  end

  def towns_from_headers
    if @header["towns"]?
      @header["towns"].as_a.each do |town|
        @towns.not_nil! << town.to_s
      end
    end
  end

  def lands_initialize
    @lands = Array(String).new
  end

  def lands_from_headers
    if @header["lands"]?
      @header["lands"].as_a.each do |land|
        @lands.not_nil! << land.to_s
      end
    end
  end

  def pois_initialize
    @pois = Array(PoiEntity).new
  end

  def pois_from_headers
    if @header["pois"]? && "" != @header["pois"]?.to_s
      @header["pois"].as_a.each do |poi|
        @pois.not_nil! << PoiEntity.new(poi)
      end
    end
  end

  def coords_initialize
    @coords = Array(PostRouteObject).new
  end

  def coords_from_headers
    if @header["coords"]?
      # TODO refactor to structure
      # easier to generate JSON
      coords = @header["coords"]
      coords.as_a.each do |ch|
        ro = PostRouteObject.new
        ro["type"] = ch["type"].to_s
        ro["route"] = Array(Array(Float64)).new

        ch["route"].as_a.each do |coord|
          if coord.size == 2
            ro["route"].as(Array) << [coord[0].to_s.to_f, coord[1].to_s.to_f]
          else
            @logger.error("Post #{@slug} - error in route coords")
          end
        end

        @coords.not_nil! << ro
      end
    end
  end

  def published_photos_entities_initialize
    @published_photo_entities = Array(PhotoEntity).new
  end

  def photos_entities_from_content
    # process helper functions: like photo and populate photo_entities
    @logger.debug("photos_entities_from_content pre")
    content_html
    @logger.debug("photos_entities_from_content post")
  end

  def basic_initialize
    @distance = 0.0
    @time_spent = 0.0
  end

  def basic_from_headers
    if @header["distance"]?
      @distance = @header["distance"].to_s.to_f
    end

    if @header["time_spent"]?
      @time_spent = @header["time_spent"].to_s.to_f
    end
  end

  def seo_initialize
    @desc = String.new
    @keywords = Array(String).new
  end

  def seo_from_headers
    if @header["keywords"]? && "" != @header["keywords"]?.to_s
      @header["keywords"].as_a.each do |keyword|
        @keywords.not_nil! << keyword.to_s
      end
    end

    @desc = @header["desc"].to_s if @header["desc"]?
  end

  def finished_at_from_headers
    if @header["finished_at"]?
      @finished_at = Time.parse(
        time: @header["finished_at"].to_s,
        pattern: "%Y-%m-%d %H:%M:%S",
        location: Time::Location.load_local
      ).as(Time)
    end
  end

  def header_image_defaults
    # easily changable post image
    @image_filename = "header.jpg"
    # ignore some posts and not add them to gallery
    @header_nogallery = false
    # header image is not best suitable for seasonal timeline gallery by default
    @header_timeline = false
    # some new posts have phtos taken by M43/Olympus camera
    @image_format = DEFAULT_IMAGE_FORMAT
  end

  def header_post_photo_from_headers
    # easily changable post image
    if @header["image_filename"]?
      @image_filename = @header["image_filename"].to_s
      @image_filename = @image_filename.not_nil!.gsub(/\.jpg/, "") + ".jpg"
    else
      @image_filename = "header.jpg"
    end

    # nogallery
    if @header["header_nogallery"]?
      @header_nogallery = true
    end

    # seasonal timeline gallery
    if @header["header_timeline"]?
      @header_timeline = true
    end

    # set head_photo_entity
    @head_photo_entity = PhotoEntity.new(
      image_filename: @image_filename.not_nil!,
      desc: @title,
      is_gallery: gallery?,
      is_timeline: @header_timeline.not_nil!,
      post: self,
      param_string: "",
      is_header: true
    )

    if @header["image_format"]? && @header["image_format"]?.to_s == IMAGE_FORMAT_M43.to_s
      @image_format = IMAGE_FORMAT_M43
    end
  end
end
