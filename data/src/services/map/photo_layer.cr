alias PhotoMapSet = NamedTuple(
  lat_min: Float64,
  lat_max: Float64,
  lon_min: Float64,
  lon_max: Float64,
  photo: PhotoEntity)

class Map::PhotoLayer
  def initialize(
    @photos : Array(PhotoEntity),
    @tiles_layer : TilesLayer,
    @quant_size = PHOTO_SIZE,
    @logger : Logger = Logger.new(STDOUT)
  )
    # to calculate coord offset we need to specify center of map
    # because at 0,0 lat offset is different
    center_tile_x = (@tiles_layer.x_tile1 + @tiles_layer.x_tile2) / 2
    center_tile_y = (@tiles_layer.y_tile1 + @tiles_layer.y_tile2) / 2

    # calculate coord offset of photo quant (photo box)
    @photo_lat_size, @photo_lon_size = @tiles_layer.geo_coords_from_map_pixels(
      pixel_x: @quant_size,
      pixel_y: @quant_size,
      zoom: @tiles_layer.zoom,
      initial_tile_x: center_tile_x,
      initial_tile_y: center_tile_y,
    ).as(Tuple(Float64, Float64))

    # operate on positive values for simple logic
    @photo_lat_size = @photo_lat_size.abs
    @photo_lon_size = @photo_lon_size.abs

    map_lat1 = @tiles_layer.map_lat1.as(Float64)
    map_lat2 = @tiles_layer.map_lat2.as(Float64)
    map_lon1 = @tiles_layer.map_lon1.as(Float64)
    map_lon2 = @tiles_layer.map_lon2.as(Float64)

    # sort to make logic simpler
    @map_lat_min = [map_lat1, map_lat2].min.as(Float64)
    @map_lat_max = [map_lat1, map_lat2].max.as(Float64)
    @map_lon_min = [map_lon1, map_lon2].min.as(Float64)
    @map_lon_max = [map_lon1, map_lon2].max.as(Float64)

    @logger.info("#{self.class}: @photo_lat_size=#{@photo_lat_size} @photo_lon_size=#{@photo_lon_size}")

    @photo_map_sets = Array(PhotoMapSet).new

    # run time consuming process to select photo per photo quant/box
    quantize_photo_areas
  end

  def render_svg
    return String.build do |s|
      @photo_map_sets.each do |photo_map_set|
        s << photo_map_set_to_svg_image(photo_map_set)
      end
    end
  end

  def quantize_photo_areas
    # lon is X axis
    # lat is Y axis but reversed
    @logger.info("#{self.class}: @map_lat_min= #{@map_lat_min} < @map_lat_max= #{@map_lat_max}")

    lat = @map_lat_min
    while lat <= @map_lat_max
      lon = @map_lon_min
      while lon <= @map_lon_max
        # XXX used only in dev
        #return if @photo_map_sets.size > 100

        # when using absolute values logic is a bit easier
        # however higher lat means something is closer to top -> Y is lower
        lat_min = lat
        lat_max = lat + @photo_lat_size
        lon_min = lon
        lon_max = lon + @photo_lon_size

        # moved outside to make this method cleaner
        select_photos_for_area_and_add_to_list(
          lat_min: lat_min,
          lat_max: lat_max,
          lon_min: lon_min,
          lon_max: lon_max,
        )

        # remember to increment
        lon += @photo_lon_size
      end
      lat += @photo_lat_size
    end

    @logger.info("#{self.class}: selected total #{@photo_map_sets.size} photos")
  end

  def select_photos_for_area_and_add_to_list(
    lat_min : Float64,
    lat_max : Float64,
    lon_min : Float64,
    lon_max : Float64
  )
    selected_photos = select_photos_for_area(
      lat_min: lat_min,
      lat_max: lat_max,
      lon_min: lon_min,
      lon_max: lon_max,
    )

    # no photos, move along
    if selected_photos.size > 0
      @logger.info("#{self.class}: #{selected_photos.size} selected_photos lat: #{lat_min}-#{lat_max} lon: #{lon_min}-#{lon_max}")

      # having array of photos take the best one
      # TODO: we need some logic to select which photos are better
      # even if they are not post published
      selected_photo = select_suitable_photo(selected_photos)

      if selected_photo
        @photo_map_sets << PhotoMapSet.new(
          lat_min: lat_min,
          lat_max: lat_max,
          lon_min: lon_min,
          lon_max: lon_max,
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
    x, y = @tiles_layer.in_map_position_from_geo_coords(
      lat_deg: photo_map_set[:lat_min],
      lon_deg: photo_map_set[:lon_min],
    )

    return String.build do |s|
      s << "<svg x='#{x.to_i}' y='#{y.to_i}' width='#{@quant_size}' height='#{@quant_size}'>"
      s << "<image href='#{url}' preserveAspectRatio='xMidYMid slice' width='#{@quant_size}' height='#{@quant_size}' />\n"
      s << "</svg>"
    end
  end
end
