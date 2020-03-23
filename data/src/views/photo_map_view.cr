alias PhotoMapSet = NamedTuple(
  lat: Float64,
  lon: Float64,
  photo: PhotoEntity)

class PhotoMapView < WidePageView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    # size of small quant - one image per quant
    @quant_width = 0.10,
    # pixel width of @quant_width
    @quant_css_width = 100,
    # append towns on map
    @append_towns = true
  )
    # select only photos with lat/lon
    @photos = @blog.data_manager.not_nil!.photos.not_nil!.select do |photo|
      photo.exif.not_nil!.lat != nil && photo.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))
    logger.info("#{self.class}: selected #{@photos.size} photos with lat/lon")

    # we cannot process if there is no photos
    return nil if @photos.size == 0

    # coeff used for translating position to css
    @css_quant_coeff = (@quant_css_width.to_f / @quant_width.to_f).as(Float64)
    # it's easier to set here than to fiddle with css
    @quant_css_min_width = (@quant_css_width.to_f * 1.2).to_i.as(Int32)

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

    # store here to speed up
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # only towns with coords
    @towns = @blog.data_manager.not_nil!.towns.not_nil!.select do |town|
      town.lat && town.lon
    end.as(Array(TownEntity))
  end

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  # w/o header image
  def content
    return inner_html
  end

  # because of absolute positioning we don't want copyright footer here
  def footer
    return ""
  end

  def inner_html
    content_string = ""

    photo_array = process_photos

    # add photos
    photo_array.each do |ph|
      content_string += load_html(
        "photo_map/photo",
        convert_photo_map_set_to_html_hash(ph)
      )
    end

    # add towns if enabled
    if @append_towns
      @towns.each do |town|
        content_string += load_html(
          "photo_map/town",
          convert_town_to_html_hash(town)
        )
      end
    end

    data = Hash(String, String).new
    data["photos"] = content_string
    return load_html("photo_map/main", data)
  end

  def process_photos
    # lat - Y, higher, closer to top
    # lon - X, higher, closer to left

    pm_array = Array(PhotoMapSet).new

    # x -> lon, y -> lat, reverse order
    lon = @min_lon
    while lon <= @max_lon
      lat = @max_lat
      while lat >= @min_lat
        result = select_photo_in_quant(
          lat: lat,
          lon: lon
        )
        # most quants have no photos within
        if result
          pm_array << result.not_nil!
        end

        lat -= @quant_width
      end
      lon += @quant_width
    end

    return pm_array
  end

  def select_photos(lat, lon)
    return @photos.select do |photo|
      photo_lat = photo.exif.not_nil!.lat.not_nil!
      photo_lon = photo.exif.not_nil!.lon.not_nil!

      photo_lon >= lon && photo_lon < (lon + @quant_width) &&
      photo_lat >= (lat - @quant_width) && photo_lat < lat
    end
  end

  def select_photo_in_quant(lat, lon)
    photos = select_photos(
      lat: lat,
      lon: lon
    )

    # there is no photos
    return nil if photos.size == 0

    logger.info("#{self.class}: #{lat},#{lon} photos.size=#{photos.size}")

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
      lat: lat,
      lon: lon,
      photo: selected.last
    )
  end

  def convert_lat_long_to_position(lat, lon)
    x = (lon.to_f - @min_lon.to_f) * @css_quant_coeff.to_f
    y = (@max_lat.to_f - lat.to_f) * @css_quant_coeff.to_f

    return x, y
  end

  def convert_photo_map_set_to_html_hash(pms : PhotoMapSet)
    left, top = convert_lat_long_to_position(
      lat: pms[:lat],
      lon: pms[:lon]
    )
    img = pms[:photo].gallery_thumb_image_src

    post_url = @posts.select do |post|
      post.slug == pms[:photo].post_slug
    end.first.url

    return {
      "top"       => top.to_i.to_s,
      "left"      => left.to_i.to_s,
      "width"     => @quant_css_width.to_s,
      "height"    => @quant_css_width.to_s,
      "min-width" => @quant_css_min_width.to_s,
      "img"       => img.to_s,
      "post.url"  => post_url,
    }.to_h
  end

  def convert_town_to_html_hash(town : TownEntity)
    left, top = convert_lat_long_to_position(
      lat: town.lat.not_nil!,
      lon: town.lon.not_nil!
    )

    return {
      "top"       => top.to_i.to_s,
      "left"      => left.to_i.to_s,
      "town.url"  => town.url,
      "town.name" => town.name,
    }.to_h
  end
end
