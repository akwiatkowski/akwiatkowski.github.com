alias PhotoToRouteMapSet = NamedTuple(
  photo_center_x: Int32,
  photo_center_y: Int32,
  point_x: Int32,
  point_y: Int32,
  corner_photo_x: Int32,
  corner_photo_y: Int32,
  photo: PhotoEntity)

struct Map::PhotoPosition
  getter :x, :y

  def initialize(@x : Int32, @y : Int32)
  end

  def distance_to(x, y)
    return Math.sqrt((@x - x) ** 2 + (@y - y) ** 2)
  end

  def self.min_distance(
    array : Array(PhotoPosition),
    x : Int32,
    y : Int32,
    distance_min : Int32
  ) : Int32
    return distance_min if array.size == 0
    return array.map { |pp| pp.distance_to(x, y) }.min.to_i
  end

  def self.find_best_place(
    array : Array(PhotoPosition),
    x : Int32,
    y : Int32,
    x_distance : Int32,
    y_distance : Int32,
    distance_min : Int32
  )

    calc_min_distance = min_distance(array, x, y, distance_min)
    if calc_min_distance >= distance_min
      puts "calc_min_distance=#{calc_min_distance} >= distance_min=#{distance_min}"
      return new(
        x, y
      )
    end

    possible_positions = Array(PhotoPosition).new
    (1..3).each do |distance_multiplier|
      degree = 0
      while degree < 360
        new_x = x + (Math.sin(degree) * distance_min.to_f * distance_multiplier.to_f).to_i
        new_y = y + (Math.cos(degree) * distance_min.to_f * distance_multiplier.to_f).to_i
        possible_positions << new(new_x, new_y)

        degree += 20
      end
    end
    puts "possible_positions.size=#{possible_positions.size}"

    possible_positions.each do |pp|
      if min_distance(array, pp.x, pp.y, distance_min) > distance_min
        puts "found #{pp.x},#{pp.y}"
        return new(
          pp.x, pp.y
        )
      end
    end

    puts 4
    # TODO error!
    return new(
      x, y
    )
  end
end

class Map::PhotoToRouteLayer
  def initialize(
    @photos : Array(PhotoEntity),
    @tiles_layer : TilesLayer,
    @image_size = DEFAULTH_PHOTO_SIZE.as(Int32),
    @logger : Logger = Logger.new(STDOUT)
  )
    @x_tile1 = @tiles_layer.x_tile1.as(Int32)
    @x_tile2 = @tiles_layer.x_tile2.as(Int32)
    @y_tile1 = @tiles_layer.y_tile1.as(Int32)
    @y_tile2 = @tiles_layer.y_tile2.as(Int32)

    @map_height = @tiles_layer.map_height.as(Int32)
    @map_width = @tiles_layer.map_width.as(Int32)

    @filtered_photos = filtered_photos.as(Array(PhotoEntity))

    @x_avg = (@map_width / 2).to_i.as(Int32)
    @y_avg = (@map_height / 2).to_i.as(Int32)

    @x_tile_center = ((@x_tile1 + @x_tile2) / 2).to_i.as(Int32)
    @y_tile_center = ((@y_tile1 + @y_tile2) / 2).to_i.as(Int32)

    @photo_positions = Array(PhotoPosition).new
    # find place not closer to other photos
    @photo_position_distance = (@image_size.to_f * 1.25).to_i.as(Int32)

    @photo_to_route_map_sets = @filtered_photos.map do |photo|
      photo_to_photo_route_map_set(photo)
    end.as(Array(PhotoToRouteMapSet))
  end

  def filtered_photos
    # TODO
    return @photos
  end

  def find_photo_position(x, y, x_distance, y_distance) : Tuple(Int32, Int32)
    pp = PhotoPosition.find_best_place(
      array: @photo_positions,
      x: x,
      y: y,
      x_distance: x_distance,
      y_distance: y_distance,
      distance_min: @photo_position_distance,
    )

    @photo_positions << pp

    return pp.x, pp.y
  end

  def photo_to_photo_route_map_set(photo_entity) : PhotoToRouteMapSet
    x, y = @tiles_layer.in_map_position_from_geo_coords(
      lat_deg: photo_entity.exif.lat.not_nil!,
      lon_deg: photo_entity.exif.lon.not_nil!
    ).as(Tuple(Int32, Int32))

    # calculate direction from center
    x_diff_center = @x_avg - x
    y_diff_center = @y_avg - y
    center_distance = Math.sqrt((x_diff_center.to_f ** 2.0) + (y_diff_center.to_f ** 2.0)).to_i

    puts "x_diff_center=#{x_diff_center}, y_diff_center=#{y_diff_center}, center_distance=#{center_distance}"

    # ideal distance between point and photo
    ideal_distance = 250
    # Tales stuff
    coeff_distance = ideal_distance.to_f / center_distance.to_f
    x_new_distance = (x_diff_center.to_f * coeff_distance).to_i
    y_new_distance = (y_diff_center.to_f * coeff_distance).to_i

    point_x = x
    point_y = y

    photo_center_x = point_x - x_new_distance
    photo_center_y = point_y - y_new_distance

    # some advanced logic to make photos no overlap
    photo_center_x, photo_center_y = find_photo_position(
      x: photo_center_x,
      y: photo_center_y,
      x_distance: x_new_distance,
      y_distance: y_new_distance
    )

    corner_photo_x = photo_center_x - (@image_size / 2).to_i
    corner_photo_y = photo_center_y - (@image_size / 2).to_i

    puts "x_new_distance=#{x_new_distance}, y_new_distance=#{y_new_distance}"

    instance = PhotoToRouteMapSet.new(
      photo_center_x: photo_center_x,
      photo_center_y: photo_center_y,
      point_x: point_x,
      point_y: point_y,
      corner_photo_x: corner_photo_x,
      corner_photo_y: corner_photo_y,
      photo: photo_entity
    )

    return instance
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-to-route-photos' >\n"

      @photo_to_route_map_sets.each do |photo_map_to_route_set|
        s << photo_to_route_map_set_to_svg_image(photo_map_to_route_set)
      end

      s << "</g>\n"
    end
  end

  def photo_to_route_map_set_to_svg_image(photo_map_to_route_set)
    url = photo_map_to_route_set[:photo].gallery_thumb_image_src
    post_url = photo_map_to_route_set[:photo].post_url

    photo_center_x = photo_map_to_route_set[:photo_center_x]
    photo_center_y = photo_map_to_route_set[:photo_center_y]
    point_x = photo_map_to_route_set[:point_x]
    point_y = photo_map_to_route_set[:point_y]
    corner_photo_x = photo_map_to_route_set[:corner_photo_x]
    corner_photo_y = photo_map_to_route_set[:corner_photo_y]

    # for cropping
    @tiles_layer.mark_top_left_corner(corner_photo_x.to_i, corner_photo_y.to_i)
    @tiles_layer.mark_bottom_right_corner(corner_photo_x.to_i + @image_size, corner_photo_y.to_i + @image_size)
    # no need to add route point for cropping

    return String.build do |s|
      s << "<polyline class='photo-pointer' fill='none' style='stroke:rgb(0,0,0);stroke-width:2' points='"
      s << "#{photo_center_x.to_i},#{photo_center_y.to_i} #{point_x.to_i},#{point_y.to_i}'  />\n"

      s << "<svg x='#{corner_photo_x.to_i}' y='#{corner_photo_y.to_i}' width='#{@image_size}' height='#{@image_size}' class='photo-map-photo'>\n"
      s << "<a href='#{post_url}' target='_blank'>\n"
      s << "<image href='#{url}' preserveAspectRatio='xMidYMid slice' width='#{@image_size}' height='#{@image_size}' />\n"
      s << "</a>\n"
      s << "</svg>\n"
    end
  end
end
