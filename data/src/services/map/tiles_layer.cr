class Map::TilesLayer
  def initialize(
    # coord range of photos exif location
    @lat_min : Float64,
    @lat_max : Float64,
    @lon_min : Float64,
    @lon_max : Float64,
    @logger = Logger.new(STDOUT),
    @zoom = DEFAULT_ZOOM,
    @type = MapType::Ump
  )
    # convert extreme geo coords to tile number (tile url coords)
    x_tile1, y_tile1 = tile_numbers_from_geo_coords(@lat_min, @lon_min).as(Tuple(Int32, Int32))
    x_tile2, y_tile2 = tile_numbers_from_geo_coords(@lat_max, @lon_max).as(Tuple(Int32, Int32))

    # sort, because I don't want to hardcore translation logic
    @x_tile1 = [x_tile1, x_tile2].min.as(Int32)
    @x_tile2 = [x_tile1, x_tile2].max.as(Int32)
    @y_tile1 = [y_tile1, y_tile2].min.as(Int32)
    @y_tile2 = [y_tile1, y_tile2].max.as(Int32)

    # add additional row and column to fix lack of round
    @x_tile1 -= 1
    @y_tile1 -= 1

    # add additional row and column to fix lack of round
    @x_tile2 += 1
    @y_tile2 += 1

    @x_tile_size = (@x_tile2 - @x_tile1).as(Int32)
    @y_tile_size = (@y_tile2 - @y_tile1).as(Int32)

    @map_height = (TILE_WIDTH * @y_tile_size).as(Int32)
    @map_width = (TILE_WIDTH * @x_tile_size).as(Int32)

    # padding viewBox calculation
    # when adding every object it will be stored
    @x_min = @map_width
    @x_max = 0
    @y_min = @map_height
    @y_max = 0

    @map_lat1, @map_lon2 = geo_coords_from_tile_number(@x_tile1, @y_tile1).as(Tuple(Float64, Float64))
    @map_lat2, @map_lon1 = geo_coords_from_tile_number(@x_tile2, @y_tile2).as(Tuple(Float64, Float64))

    @logger.info("#{self.class}: @x_tile1,@y_tile1=#{@x_tile1},#{@y_tile1} @x_tile2,@y_tile2=#{@x_tile2},#{@y_tile2}")
    @logger.info("#{self.class}: @x_tile_size=#{@x_tile_size} @y_tile_size=#{@y_tile_size}")
    @logger.info("#{self.class}: @map_width=#{@map_width} @map_height=#{@map_height}")
    @logger.info("#{self.class}: @map_lat1,@map_lon1=#{@map_lat1},#{@map_lon1} @map_lat2,@map_lon2=#{@map_lat2},#{@map_lon2}")
  end

  getter :x_tile1, :y_tile1, :x_tile2, :y_tile2
  getter :zoom, :map_height, :map_width
  getter :map_lat1, :map_lon1, :map_lat2, :map_lon2

  getter :x_min, :y_min, :x_max, :y_max

  CROP_PADDING = 50

  def mark_top_left_corner(x, y)
    @x_min = x if @x_min > x
    @y_min = y if @y_min > y
  end

  def mark_bottom_right_corner(x, y)
    @x_max = x if @x_max < x
    @y_max = y if @y_max < y
  end

  def cropped_width
    r = @x_max - self.cropped_x + CROP_PADDING
    max = @map_width - self.cropped_x

    return max if r > max
    return r
  end

  def cropped_x
    r = self.x_min - CROP_PADDING
    return 0 if r < 0
    return r
  end

  def cropped_height
    r = @y_max - self.cropped_y + CROP_PADDING
    max = @map_height - self.cropped_y

    return max if r > max
    return r
  end

  def cropped_y
    r = self.y_min - CROP_PADDING
    return 0 if r < 0
    return r
  end

  def tile_numbers_from_geo_coords(lat_deg, lon_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lon_deg, zoom)
    return x.to_i, y.to_i
  end

  def in_tile_position_from_geo_coords(lat_deg, lon_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lon_deg, zoom)
    return (x.modulo(1.0) * TILE_WIDTH.to_f).round.to_i, (y.modulo(1.0) * TILE_WIDTH.to_f).round.to_i
  end

  def in_map_position_from_geo_coords(lat_deg, lon_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lon_deg, zoom)
    return ((x - @x_tile1.to_f) * TILE_WIDTH.to_f).round.to_i,
      ((y - @y_tile1.to_f) * TILE_WIDTH.to_f).round.to_i
  end

  # float, keep in mind that tiles in Poland start not from 0
  def tile_coords_from_geo_coords(lat_deg, lon_deg, zoom = @zoom) : Tuple(Float64, Float64)
    return self.class.tile_coords_from_geo_coords(
      lat_deg: lat_deg,
      lon_deg: lon_deg,
      zoom: zoom,
    )
  end

  def self.tile_coords_from_geo_coords(lat_deg, lon_deg, zoom) : Tuple(Float64, Float64)
    lat_rad = lat_deg / 180.0 * Math::PI
    n = 2.0 ** zoom
    x = ((lon_deg + 180.0) / 360.0 * n)
    y = ((1.0 - Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI) / 2.0 * n)

    return x, y
  end

  def geo_coords_from_tile_number(tile_x, tile_y, zoom = @zoom) : Tuple(Float64, Float64)
    n = 2.0 ** zoom
    lon_deg = tile_x / n * 360.0 - 180.0
    lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * tile_y / n)))
    lat_deg = 180.0 * (lat_rad / Math::PI)

    return lat_deg, lon_deg
  end

  def geo_coords_from_map_pixel_position(pixel_x, pixel_y) : Tuple(Float64, Float64)
    tile_x = @x_tile1.to_f + (pixel_x.to_f / TILE_WIDTH.to_f)
    tile_y = @y_tile1.to_f + (pixel_y.to_f / TILE_WIDTH.to_f)

    return geo_coords_from_tile_number(tile_x, tile_y, @zoom)
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-tiles' >\n"

      ((@x_tile1)..(@x_tile2)).each do |tile_x|
        ((@y_tile1)..(@y_tile2)).each do |tile_y|
          relative_title_x = tile_x - @x_tile1
          relative_title_y = tile_y - @y_tile1
          x = relative_title_x * TILE_WIDTH
          y = relative_title_y * TILE_WIDTH
          url = "/tiles/ump/#{@zoom}/#{tile_x}/#{tile_y}.png"

          s << "<image href='#{url}' x='#{x.to_i}' y='#{y.to_i}' class='photo-map-tile' />\n"
        end
      end

      s << "</g>\n"
    end
  end
end
