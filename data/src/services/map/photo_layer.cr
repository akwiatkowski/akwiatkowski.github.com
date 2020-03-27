alias PhotoMapSet = NamedTuple(
  pixel_x: Int32,
  pixel_y: Int32,
  photo: PhotoEntity)

class Map::PhotoLayer
  def initialize(
    @photos : Array(PhotoEntity),
    @tiles_layer : TilesLayer,
    @quant_size = PHOTO_SIZE,
    @logger : Logger = Logger.new(STDOUT)
  )
    @x_tile1 = @tiles_layer.x_tile1.as(Int32)
    @x_tile2 = @tiles_layer.x_tile2.as(Int32)
    @y_tile1 = @tiles_layer.y_tile1.as(Int32)
    @y_tile2 = @tiles_layer.y_tile2.as(Int32)

    @map_height = @tiles_layer.map_height.as(Int32)
    @map_width = @tiles_layer.map_width.as(Int32)

    @photo_map_sets = Array(PhotoMapSet).new

    # run time consuming process to select photo per photo quant/box
    quantize_photo_areas
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-photos' >\n"

      @photo_map_sets.each do |photo_map_set|
        s << photo_map_set_to_svg_image(photo_map_set)
      end

      s << "</g>\n"
    end
  end

  def quantize_photo_areas
    x = 0
    while x <= @map_width
      y = 0
      while y <= @map_height
        select_photos_for_quant_and_add_to_list(
          x: x,
          y: y,
        )

        # remember to increment
        y += PHOTO_SIZE
      end
      x += PHOTO_SIZE
    end

    @logger.info("#{self.class}: selected total #{@photo_map_sets.size} photos")
  end

  def select_photos_for_quant_and_add_to_list(
    x : Int32,
    y : Int32,
  )
    lat1, lon1 = @tiles_layer.geo_coords_from_map_pixel_position(x, y)
    lat2, lon2 = @tiles_layer.geo_coords_from_map_pixel_position(x + PHOTO_SIZE, y + PHOTO_SIZE)

    selected_photos = select_photos_for_area(
      lat_min: lat2, # Y/lat axis is reversed
      lat_max: lat1,
      lon_min: lon1,
      lon_max: lon2,
    )

    # no photos, move along
    if selected_photos.size > 0
      @logger.info("#{self.class}: #{selected_photos.size} selected_photos x: #{x} y: #{y}")

      # having array of photos take the best one
      # TODO: we need some logic to select which photos are better
      # even if they are not post published
      selected_photo = select_suitable_photo(selected_photos)

      if selected_photo
        @photo_map_sets << PhotoMapSet.new(
          pixel_x: x,
          pixel_y: y,
          photo: selected_photo.not_nil!
        )
      end
    end
  end

  # using min and max because it's compared math.
  # we ignore direction of growth
  def select_photos_for_area(
    lat_min : Float64,
    lat_max : Float64,
    lon_min : Float64,
    lon_max : Float64
  )
    @photos.select do |photo|
      photo_lat = photo.exif.not_nil!.lat.not_nil!
      photo_lon = photo.exif.not_nil!.lon.not_nil!

      photo_lat >= lat_min &&
        photo_lat < lat_max &&
        photo_lon >= lon_min &&
        photo_lon < lon_max
    end
  end

  def select_suitable_photo(array : Array(PhotoEntity)) : (PhotoEntity | Nil)
    return nil if array.size == 0

    selected = array.select { |photo| photo.is_map }
    # then PhotoEntity#is_timeline last
    if selected.size == 0
      selected = array.select { |photo| photo.is_timeline }
    end
    if selected.size == 0
      selected = array
    end

    return selected.last
  end

  def photo_map_set_to_svg_image(photo_map_set)
    url = photo_map_set[:photo].gallery_thumb_image_src
    x = photo_map_set[:pixel_x]
    y = photo_map_set[:pixel_y]

    return String.build do |s|
      s << "<svg x='#{x.to_i}' y='#{y.to_i}' width='#{@quant_size}' height='#{@quant_size}' class='photo-map-photo'>"
      s << "<image href='#{url}' preserveAspectRatio='xMidYMid slice' width='#{@quant_size}' height='#{@quant_size}' />\n"
      s << "</svg>"
    end
  end
end
