alias PhotoMapSet = NamedTuple(
  x: Float64,
  y: Float64,
  photo: PhotoEntity
)

class PhotoMapView < WidePageView
  # size of small quant - one image per quant
  QUANT_WIDTH = 0.10
  # pixel width of QUANT_WIDTH
  QUANT_CSS_WIDTH = 100

  # coeff used for translating position to css
  CSS_QUANT_COEFF = QUANT_CSS_WIDTH.to_f / QUANT_WIDTH
  # it's easier to set here than to fiddle with css
  QUANT_CSS_MIN_WIDTH = (QUANT_CSS_WIDTH.to_f * 1.2).to_i

  def initialize(@blog : Tremolite::Blog, @url : String)
    # select only photos with lat/lon
    @photos = @blog.data_manager.not_nil!.photos.not_nil!.select do |photo|
      photo.exif.not_nil!.lat != nil && photo.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))
    logger.info("#{self.class}: selected #{@photos.size} photos with lat/lon")

    # we cannot process if there is no photos
    return nil if @photos.size == 0

    # assign now to have not nil value
    @min_lat = @photos.first.exif.not_nil!.lat.not_nil!.as(Float64)
    @max_lat = @min_lat.as(Float64)

    @min_lon = @photos.first.exif.not_nil!.lon.not_nil!.as(Float64)
    @max_lon = @min_lon.as(Float64)

    @photos.each do |photo|
      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!

      @min_lat = lat if lat < @min_lat
      @min_lon = lon if lon < @min_lon

      @max_lat = lat if lat > @max_lat
      @max_lon = lon if lon > @max_lon
    end

    logger.info("#{self.class}: area #{@min_lat},#{@min_lon} - #{@max_lat}-#{@max_lon} (lat,lon)")

    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
  end

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  def inner_html
    photos_string = ""

    photo_array = process_photos

    photo_array.each do |ph|
      photos_string += load_html(
        "photo_map/photo",
        convert_photo_map_set_to_html_hash(ph)
      )
    end

    data = Hash(String, String).new
    data["photos"] = photos_string
    return load_html("photo_map/main", data)
  end

  def process_photos
    # lat - Y, higher, closer to top
    # lon - X, higher, closer to left

    pm_array = Array(PhotoMapSet).new

    # x -> lon, y -> lat, reverse order
    x = @min_lon
    while x <= @max_lon
      y = @max_lat
      while y >= @min_lat
        result = select_photo_in_quant(x, y)
        # most quants have no photos within
        if result
          pm_array << result.not_nil!
        end

        y -= QUANT_WIDTH
      end
      x += QUANT_WIDTH
    end

    return pm_array
  end

  def select_photos(x, y)
    return @photos.select do |photo|
      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!

      lon >= x && lon < (x + QUANT_WIDTH) &&
      lat >= (y - QUANT_WIDTH) && lat < y
    end
  end

  def select_photo_in_quant(x, y)
    photos = select_photos(x, y)

    # there is no photos
    return nil if photos.size == 0

    logger.info("#{self.class}: x=#{x},y=#{y},photos.size=#{photos.size}")

    # select PhotoEntity#is_map last
    selected = photos.select { |photo| photo.is_map }
    # then PhotoEntity#is_timeline last
    if selected.size == 0
      selected = photos.select { |photo| photo.is_timeline }
    end
    if selected.size == 0
      selected = photos
    end

    # TODO sort?
    return PhotoMapSet.new(
      x: x,
      y: y,
      photo: selected.last
    )
  end

  def convert_photo_map_set_to_html_hash(pms : PhotoMapSet)
    left = (pms[:x] - @min_lon) * CSS_QUANT_COEFF
    top = (@max_lat - pms[:y]) * CSS_QUANT_COEFF
    img = pms[:photo].gallery_thumb_image_src

    post_url = @posts.select do |post|
      post.slug == pms[:photo].post_slug
    end.first.url

    return {
      "top" => top.to_i.to_s,
      "left" => left.to_i.to_s,
      "width" => QUANT_CSS_WIDTH.to_s,
      "height" => QUANT_CSS_WIDTH.to_s,
      "min-width" => QUANT_CSS_MIN_WIDTH.to_s,
      "img" => img.to_s,
      "post.url" => post_url,
    }.to_h
  end
end
