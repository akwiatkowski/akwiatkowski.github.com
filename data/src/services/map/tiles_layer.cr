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
    x_tile1, y_tile1 = tile_numbers_from_geo_coords(@lat_min, @lon_min).as(Tuple(Int32, Int32))
    x_tile2, y_tile2 = tile_numbers_from_geo_coords(@lat_max, @lon_max).as(Tuple(Int32, Int32))

    # sort, because I don't want to hardcore translation logic
    @x_tile1 = [x_tile1, x_tile2].min.as(Int32)
    @x_tile2 = [x_tile1, x_tile2].max.as(Int32)
    @y_tile1 = [y_tile1, y_tile2].min.as(Int32)
    @y_tile2 = [y_tile1, y_tile2].max.as(Int32)

    # add additional row and column to fix lack of round
    @x_tile2 += 1
    @y_tile2 += 1

    @x_tile_size = (@x_tile2 - @x_tile1).as(Int32)
    @y_tile_size = (@y_tile2 - @y_tile1).as(Int32)

    @map_height = (TILE_WIDTH * @y_tile_size).as(Int32)
    @map_width = (TILE_WIDTH * @x_tile_size).as(Int32)

    @map_lat1, @map_lon2 = geo_coords_from_tile_number(@x_tile1, @y_tile1).as(Tuple(Float64, Float64))
    @map_lat2, @map_lon1 = geo_coords_from_tile_number(@x_tile2, @y_tile2).as(Tuple(Float64, Float64))

    @logger.info("#{self.class}: @x_tile1,@y_tile1=#{@x_tile1},#{@y_tile1} @x_tile2,@y_tile2=#{@x_tile2},#{@y_tile2}")
    @logger.info("#{self.class}: @x_tile_size=#{@x_tile_size} @y_tile_size=#{@y_tile_size}")
    @logger.info("#{self.class}: @map_width=#{@map_width} @map_height=#{@map_height}")
    @logger.info("#{self.class}: @map_lat1,@map_lon1=#{@map_lat1},#{@map_lon1} @map_lat2,@map_lon2=#{@map_lat2},#{@map_lon2}")
  end

  getter :x_tile1, :y_tile2, :x_tile2, :y_tile1
  getter :zoom, :map_height, :map_width
  getter :map_lat1, :map_lon1, :map_lat2, :map_lon2

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
    lat_rad = lat_deg / 180.0 * Math::PI
    n = 2.0 ** zoom
    x = ((lon_deg + 180.0) / 360.0 * n)
    y = ((1.0 - Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI) / 2.0 * n)

    return x, y
  end

  def geo_coords_from_map_pixels(pixel_x, pixel_y, zoom = @zoom)
    tile_x = pixel_x.to_f / TILE_WIDTH.to_f
    tile_y = pixel_y.to_f / TILE_WIDTH.to_f

    zero_lat, zero_lon = geo_coords_from_tile_number(0.0, 0.0, zoom)
    pixel_lat, pixel_lon = geo_coords_from_tile_number(tile_x, tile_y, zoom)

    return (pixel_lat - zero_lat), (pixel_lon - zero_lon)
  end

  def geo_coords_from_tile_number(x, y, zoom = @zoom) : Tuple(Float64, Float64)
    n = 2.0 ** zoom
    lon_deg = x / n * 360.0 - 180.0
    lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * y / n)))
    lat_deg = 180.0 * (lat_rad / Math::PI)

    return lat_deg, lon_deg
  end

  def render_svg
    return String.build do |s|
      ((@x_tile1)..(@x_tile2)).each do |tile_x|
        ((@y_tile1)..(@y_tile2)).each do |tile_y|
          relative_title_x = tile_x - @x_tile1
          relative_title_y = tile_y - @y_tile1
          x = relative_title_x * TILE_WIDTH
          y = relative_title_y * TILE_WIDTH
          url = "/tiles/ump/#{@zoom}/#{tile_x}/#{tile_y}.png"

          s << "<image href='#{url}' x='#{x.to_i}' y='#{y.to_i}' />\n"
        end
      end
    end
  end
end
