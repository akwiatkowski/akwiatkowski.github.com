require "./../model/post_route_object"

class Tremolite::Post
  @coords_file : String?
  @coords_type : String?
  @detailed_routes : Array(PostRouteObject)?
  @routes_coord_range : CoordRange?
  @routes_coord_range_set : Bool?
  @image_other_post_slug : String?
  @head_photo_entity : PhotoEntity?

  @tag_slugs : Array(String) = Array(String).new
  @town_slugs : Array(String) = Array(String).new
  @land_slugs : Array(String) = Array(String).new
  @foreign_slugs : Array(String) = Array(String).new

  @temperature : Int32?

  @default_suggested_map_zooms = Array(Int32).new

  def initialize(@path : String, @data_path : String = "", @output_path : String = "")
    @content_string = String.new
    @header = YAML::Any.new(nil)

    @slug = (File.basename(@path)).gsub(/\..{1,10}$/, "").as(String)
    @title = String.new
    @subtitle = String.new
    @author = String.new
    @category = String.new
    @time = Time::UNIX_EPOCH.as(Time)
    @url = String.new

    header_image_defaults
    basic_initialize
    tags_initialize
    towns_initialize
    lands_initialize
    foreign_initialize
    pois_initialize
    coords_initialize
    published_photos_entities_initialize
    seo_initialize
  end

  def process
    process_header
    process_paths
    tags_from_headers
    towns_from_headers
    lands_from_headers
    foreign_from_headers
    pois_from_headers
    coords_from_headers
    basic_from_headers
    seo_from_headers
    finished_at_from_headers
    header_post_photo_from_headers
    photo_map_data_from_headers
  end

  # override post url
  def process_paths
    time_part_wo_day = @time.to_s("%Y/%m/")
    slug_with_day = @slug.gsub(/\d{4}-\d{2}-/, "")
    @url = "/#{time_part_wo_day}#{slug_with_day}.html"
    # used for 301. If there will be another url change in # future
    # this must be changed here
    @old_url = "/#{@category || "trip"}/#{@slug}"
  end

  # TODO this will require a lot of operations
  def slow_process_header
    photos_entities_from_content
  end

  def tags_initialize
    @tag_slugs = Array(String).new
  end

  def tags_from_headers
    if @header["tags"]?
      @header["tags"].as_a.each do |tag|
        @tag_slugs << tag.to_s
      end
    end
  end

  def towns_initialize
    @town_slugs = Array(String).new
  end

  def towns_from_headers
    if @header["towns"]?
      @header["towns"].as_a.each do |town|
        @town_slugs << town.to_s
      end
    end
  end

  def lands_initialize
    @land_slugs = Array(String).new
  end

  def lands_from_headers
    if @header["lands"]?
      @header["lands"].as_a.each do |land|
        @land_slugs << land.to_s
      end
    end
  end

  def foreign_initialize
    @foreign_slugs = Array(String).new
  end

  def foreign_from_headers
    if @header["foreign"]?
      @header["foreign"].as_a.each do |foreign_slug|
        @foreign_slugs << foreign_slug.to_s
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
    @coords_file = nil
    @coords_type = nil
    @routes_coord_range_set = false
  end

  def coords_from_headers
    if @header["coords"]?
      # TODO refactor to structure
      # easier to generate JSON
      coords = @header["coords"]
      coords.as_a.each do |ch|
        ro = PostRouteObject.new(ch)
        @coords.not_nil! << ro
      end
    end

    if @header["coords_file"]?
      @coords_file = @header["coords_file"].to_s

      unless File.exists?(route_path)
        raise RuntimeError.new("file #{route_path} not exists")
      end
    end
    if @header["coords_type"]?
      @coords_type = @header["coords_type"].to_s
    end
  end

  def has_detailed_route?
    return true if @coords_file && @coords_type
    return false
  end

  def route_path
    return File.join(
      [
        routes_path,
        @coords_file,
      ]
    )
  end

  private def routes_path
    File.join([@data_path, "routes"])
  end

  def detailed_routes : Array(PostRouteObject)
    if has_detailed_route?
      # detailed route file is specified
      if @detailed_routes.nil?
        # load it when not loaded yet
        file_path = route_path

        routes_array = Array(SingleRouteObject).from_json(File.open(file_path))

        @detailed_routes = routes_array.map do |route|
          PostRouteObject.new(
            route: route,
            type: @coords_type.not_nil! # bicycle, hike, train
          )
        end.as(Array(PostRouteObject))
      end
      return @detailed_routes.not_nil!
    else
      # not specified, using coords defined in post
      return @coords.not_nil!
    end
  end

  def routes_coord_range : CoordRange?
    unless @routes_coord_range_set
      @routes_coord_range = PostRouteObject.array_to_coord_range(
        array: detailed_routes
      )
      @routes_coord_range_set = true
    end
    return @routes_coord_range
  end

  def published_photos_entities_initialize
    @published_photo_entities = Array(PhotoEntity).new
  end

  def photos_entities_from_content
    # process helper functions: like photo and populate photo_entities
    Log.debug { "photos_entities_from_content pre" }
    content_html
    Log.debug { "photos_entities_from_content post" }
  end

  def basic_initialize
    @distance = 0.0
    @time_spent = 0.0
  end

  def basic_from_headers
    if @header["distance"]?.to_s.strip != ""
      @distance = @header["distance"].to_s.to_f
    end

    if @header["time_spent"]?.to_s.strip != ""
      @time_spent = @header["time_spent"].to_s.to_f
    end

    if @header["temperature"]?.to_s.strip != ""
      @temperature = @header["temperature"].to_s.to_i
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
    # 'end of year' posts can use header from other post
    @image_other_post_slug = nil

    # most photos don't look good being centered
    # you can specify background position css style to fix it
    # https://www.w3schools.com/cssref/pr_background-position.asp
    @image_position = ""
  end

  # most of the time header photo is taken from same post
  def header_post_photo_post
    if @image_other_post_slug.nil?
      return self
    else
      # find post using slug and
      collection = @post_collection
      if collection
        other_posts = collection.posts.select do |other_post|
          other_post.slug == @image_other_post_slug.not_nil!
        end
        return other_posts.first.not_nil!
      else
        return self
      end
    end
  end

  def header_post_photo_from_headers
    # easily changable post image
    if @header["image_filename"]?
      @image_filename = @header["image_filename"].to_s
      @image_filename = @image_filename.not_nil!.gsub(/\.jpg/, "") + ".jpg"
    else
      @image_filename = "header.jpg"
    end

    if @header["image_other_post_slug"]?
      @image_other_post_slug = @header["image_other_post_slug"].to_s
    end

    # background image css position
    if @header["image_position"]?
      @image_position = @header["image_position"].to_s
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
      photo_tags: photo_tags,
      image_filename: @image_filename.not_nil!,
      desc: @title,
      is_gallery: gallery?,
      is_timeline: @header_timeline.not_nil!,
      post: header_post_photo_post,
      param_string: "",
      is_header: true
    )

    if @header["image_format"]? && @header["image_format"]?.to_s == IMAGE_FORMAT_M43.to_s
      @image_format = IMAGE_FORMAT_M43
    end
  end

  def specified_suggested_photo_map_zoom?
    return photo_map_data_from_headers && photo_map_data_from_headers.not_nil!.size > 0
  end

  def photo_map_data_from_headers
    if @header["map_zooms"]?
      string = @header["map_zooms"].to_s
      string = "[#{string}]" if string[0] != '['

      @default_suggested_map_zooms = Array(Int32).from_json(string)
    end
  end
end
