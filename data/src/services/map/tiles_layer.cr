class Map::TilesLayer
  Log = ::Log.for(self)

  def initialize(
    # coord range of photos exif location
    @lat_min : Float64,
    @lat_max : Float64,
    @lon_min : Float64,
    @lon_max : Float64,
    @zoom = DEFAULT_ZOOM,
    @type = Map::MapTile::Ump
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
    @x_min = 0
    @x_max = @map_width
    @y_min = 0
    @y_max = @map_height

    @map_lat1, @map_lon2 = geo_coords_from_tile_number(@x_tile1, @y_tile1).as(Tuple(Float64, Float64))
    @map_lat2, @map_lon1 = geo_coords_from_tile_number(@x_tile2, @y_tile2).as(Tuple(Float64, Float64))

    Log.debug { "@x_tile1,@y_tile1=#{@x_tile1},#{@y_tile1} @x_tile2,@y_tile2=#{@x_tile2},#{@y_tile2}" }
    Log.debug { "@x_tile_size=#{@x_tile_size} @y_tile_size=#{@y_tile_size}" }
    Log.debug { "@map_width=#{@map_width} @map_height=#{@map_height}" }
    Log.debug { "@map_lat1,@map_lon1=#{@map_lat1},#{@map_lon1} @map_lat2,@map_lon2=#{@map_lat2},#{@map_lon2}" }
  end

  getter :x_tile1, :y_tile1, :x_tile2, :y_tile2
  getter :zoom, :map_height, :map_width
  getter :map_lat1, :map_lon1, :map_lat2, :map_lon2

  getter :x_min, :y_min, :x_max, :y_max

  ###

  def map_lat_center
    (@map_lat1 + @map_lat2) / 2.0
  end

  def map_lon_center
    (@map_lon1 + @map_lon2) / 2.0
  end

  def diagonal
    return Math.sqrt(@map_height ** 2 + @map_width ** 2).to_i
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

  def self.ideal_zoom_for_photo_distance(
    coord_range : CoordRange,
    distance : Int32
  )
    possible_zooms = distance_to_zoom_for_coord_range(coord_range)

    distance_processed_zooms = Hash(Int32, Float64).new
    possible_zooms.map do |zoom, zoom_distance_tuple|
      # when selecting for distance we calculate on lower dimension
      zoom_distance = [zoom_distance_tuple[:x], zoom_distance_tuple[:y]].min

      distance_processed_zooms[zoom.to_i] = (((distance / zoom_distance) + (zoom_distance / distance)) / 2.0).to_f
    end

    closest_zoom = distance_processed_zooms.keys.sort do |a, b|
      distance_processed_zooms[a] <=> distance_processed_zooms[b]
    end.first

    return {
      zoom:                     closest_zoom.to_i32,
      distance_processed_zooms: distance_processed_zooms,
      possible_zooms:           possible_zooms,
    }
  end

  def self.distance_to_zoom_for_coord_range(coord_range : CoordRange)
    result = Hash(Int32, NamedTuple(x: Int32, y: Int32, diagonal: Int32)).new

    VALID_ZOOMS.each do |zoom|
      tile_from_x, time_from_y = tile_coords_from_geo_coords(
        lat_deg: coord_range.lat_from,
        lon_deg: coord_range.lon_from,
        zoom: zoom
      )

      tile_to_x, time_to_y = tile_coords_from_geo_coords(
        lat_deg: coord_range.lat_to,
        lon_deg: coord_range.lon_to,
        zoom: zoom
      )

      distance_x = (tile_from_x - tile_to_x).abs * TILE_WIDTH.to_f
      distance_y = (time_from_y - time_to_y).abs * TILE_WIDTH.to_f
      distance_diagonal = Math.sqrt(
        (distance_x.to_f ** 2.0) +
        (distance_y.to_f ** 2.0)
      )

      result[zoom.to_i] = {
        x:        distance_x.to_i,
        y:        distance_y.to_i,
        diagonal: distance_diagonal.to_i,
      }
    end
    return result
  end

  # TODO: old
  def self.ideal_zoom(
    coord_range : CoordRange,
    min_diagonal : Int32 = 300,
    max_diagonal : Int32 = 5000,
    # not always we need biggest map
    biggest : Bool = true
  ) : Int32?
    h = diagonal_for_zoom(coord_range)

    if biggest
      sorted = h.keys.sort.reverse
    else
      sorted = h.keys.sort
    end

    sorted.each do |zoom|
      diagonal = h[zoom]
      return zoom if diagonal >= min_diagonal && diagonal <= max_diagonal
    end

    # failsafe
    lowest_zoom = h.keys.min
    highest_zoom = h.keys.max

    lowest_diagonal = h[lowest_zoom]
    highest_diagonal = h[highest_zoom]

    # return highest zoom because even highest zoom is not big
    # enough for small post (strava-like) photo map
    return highest_zoom if highest_diagonal <= min_diagonal

    # return lowest zoom because even lowest zoom is too big
    # for small post (strava-like) photo map
    return lowest_zoom if lowest_diagonal >= max_diagonal

    # that shouldn't hapen
    return nil
  end

  # TODO: old
  def self.diagonal_for_zoom(coord_range : CoordRange)
    VALID_ZOOMS.map do |zoom|
      tile_from_x, time_from_y = tile_coords_from_geo_coords(
        lat_deg: coord_range.lat_from,
        lon_deg: coord_range.lon_from,
        zoom: zoom
      )

      tile_to_x, time_to_y = tile_coords_from_geo_coords(
        lat_deg: coord_range.lat_to,
        lon_deg: coord_range.lon_to,
        zoom: zoom
      )

      diagonal = Math.sqrt(
        (tile_from_x - tile_to_x) ** 2 +
        (time_from_y - time_to_y) ** 2
      ) * TILE_WIDTH.to_f

      [zoom, diagonal.to_i]
    end.to_h
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
