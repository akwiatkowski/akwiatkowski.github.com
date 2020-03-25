class Map::TilesLayer
  def initialize(
    @min_lat : Float64,
    @max_lat : Float64,
    @min_lon : Float64,
    @max_lon : Float64,
    @logger = Logger.new(STDOUT),
    @zoom = DEFAULT_ZOOM,
    @type = MapType::Ump,
  )
    @x_from, @y_to = tile_numbers_from_geo_coords(@min_lat, @min_lon).as(Tuple(Int32, Int32))
    @x_to, @y_from = tile_numbers_from_geo_coords(@max_lat, @max_lon).as(Tuple(Int32, Int32))

    @x_size = (@x_to - @x_from).as(Int32)
    @y_size = (@y_to - @y_from).as(Int32)

    @map_height = (TILE_WIDTH * @y_size).as(Int32)
    @map_width = (TILE_WIDTH * @x_size).as(Int32)
  end

  getter :x_from, :y_to, :x_to, :y_from
  getter :zoom, :map_height, :map_width

  def tile_numbers_from_geo_coords(lat_deg, lng_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lng_deg, zoom)
    return x.to_i, y.to_i
  end

  def in_tile_position_from_geo_coords(lat_deg, lng_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lng_deg, zoom)
    return (x.modulo(1.0) * TILE_WIDTH.to_f).round.to_i, (y.modulo(1.0) * TILE_WIDTH.to_f).round.to_i
  end

  def in_map_position_from_geo_coords(lat_deg, lng_deg, zoom = @zoom) : Tuple(Int32, Int32)
    x, y = tile_coords_from_geo_coords(lat_deg, lng_deg, zoom)
    return ((x - @x_from.to_f) * TILE_WIDTH.to_f).round.to_i,
      ((y - @y_from.to_f) * TILE_WIDTH.to_f).round.to_i
  end

  # float, keep in mind that tiles in Poland start not from 0
  def tile_coords_from_geo_coords(lat_deg, lng_deg, zoom = @zoom) : Tuple(Float64, Float64)
    lat_rad = lat_deg / 180.0 * Math::PI
    n = 2.0 ** zoom
    x = ((lng_deg + 180.0) / 360.0 * n)
    y = ((1.0 - Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI) / 2.0 * n)

    return x, y
  end

  def get_lat_lng_for_number(x, y, zoom = @zoom)
    n = 2.0 ** zoom
    lon_deg = x / n * 360.0 - 180.0
    lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * y / n)))
    lat_deg = 180.0 * (lat_rad / Math::PI)

    return lat_deg, lon_deg
  end

  def render_svg
    return String.build do |s|
      ((@x_from)..(@x_to)).each do |tile_x|
        ((@y_from)..(@y_to)).each do |tile_y|
          relative_title_x = tile_x - @x_from
          relative_title_y = tile_y - @y_from
          x = relative_title_x * TILE_WIDTH
          y = relative_title_y * TILE_WIDTH
          url = "/tiles/ump/#{@zoom}/#{tile_x}/#{tile_y}.png"

          s << "<image href='#{url}' x='#{x.to_i}' y='#{y.to_i}' />\n"
        end
      end
    end
  end
end
