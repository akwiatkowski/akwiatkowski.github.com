require "../services/map/base"

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
    m = Map::Base.new(
      blog: @blog,
    )

    return m.to_s

    #
    # content_string = ""
    #
    # # background tiles
    # content_string += map_tiles_svg
    #
    # # photos
    # # photo_array = process_photos
    # #
    # # # add photos
    # # photo_array.each do |ph|
    # #   content_string += load_html(
    # #     "photo_map/photo",
    # #     convert_photo_map_set_to_html_hash(ph)
    # #   )
    # # end
    #
    # # add towns if enabled
    # if @append_towns
    #   @towns.each do |town|
    #     content_string += load_html(
    #       "photo_map/town",
    #       convert_town_to_html_hash(town)
    #     )
    #   end
    # end
    #
    # # all posts routes as svg
    # # TODO temporary disabled because it block photos and not look good enough
    # #content_string += posts_routes_svg
    #
    # data = Hash(String, String).new
    # data["photos"] = content_string
    # return load_html("photo_map/main", data)
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

  def convert_lat_long_to_position(lat, lon, round_to = 1)
    x = (lon.to_f - @min_lon.to_f) * @css_pixel_per_geo_unit.to_f
    y = (@max_lat.to_f - lat.to_f) * @css_pixel_per_geo_unit.to_f

    if round_to > 1
      x = (x / round_to.to_f).round.to_i * round_to.to_i
      y = (y / round_to.to_f).round.to_i * round_to.to_i
    end

    return x, y
  end

  def convert_photo_map_set_to_html_hash(pms : PhotoMapSet)
    left, top = convert_lat_long_to_position(
      lat: pms[:lat],
      lon: pms[:lon],
      round_to: @quant_css_width
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

  def use_tiles_as_background
    # TODO
  end
end
