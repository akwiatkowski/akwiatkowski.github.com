# render post photos assigned to route

struct Map::MapCoordRange
  getter :x_from, :y_from, :x_to, :y_to

  def initialize(
    @x_from : Int32,
    @y_from : Int32,
    @x_to : Int32,
    @y_to : Int32
  )
  end

  def x_center
    return ((@x_from + @x_to) / 2).to_i
  end

  def y_center
    return ((@y_from + @y_to) / 2).to_i
  end

  def overlap_other(other : Map::MapCoordRange) : Bool
    x_overlap_other = Range.new(other.x_from, other.x_to).includes?(self.x_from)
    x_overlap_self = Range.new(self.x_from, self.x_to).includes?(other.x_from)

    y_overlap_other = Range.new(other.y_from, other.y_to).includes?(self.y_from)
    y_overlap_self = Range.new(self.y_from, self.y_to).includes?(other.y_from)

    x_overlap = x_overlap_other || x_overlap_self
    y_overlap = y_overlap_other || y_overlap_self

    result = x_overlap && y_overlap

    return result
  end
end

struct Map::PhotoToRoutePosition
  getter :photo_entity
  getter :point_x, :point_y
  getter :photo_center_x, :photo_center_y
  getter :corner_photo_x, :corner_photo_y

  def initialize(
    @photo_entity : PhotoEntity,
    @point_x : Int32,
    @point_y : Int32,
    @photo_center_x : Int32,
    @photo_center_y : Int32,
    @corner_photo_x : Int32,
    @corner_photo_y : Int32
  )
  end
end

class Map::PhotoLayer::PhotosAssignedToRouteLayer
  Log = ::Log.for(self)

  BLOCKED_ROUTE_PADDING          = 20
  DISTANCES_FROM_POINT           = [150, 200, 250]
  DEGREE_INCREMENTAL             =    15
  MARGIN_COEFF                   =   1.3
  CLOSEST_PHOTO_POINT            =    10 # not sure why not working :(
  MIN_GEO_DISTANCE               = 0.004
  DISTANCES_FROM_POINT_SIDE      = [150, 200, 220]
  BEARING_ROUTE_CROP_SIZE        =   10
  BEARING_ROUTE_CLOSEST_DISTANCE = 0.05

  def initialize(
    photos : Array(PhotoEntity),
    @crop : Map::Crop,
    @posts : Array(Tremolite::Post),
    @tiles_layer : TilesLayer,
    @image_size = DEFAULTH_PHOTO_SIZE.as(Int32),
    @photo_link_to : Map::MapPhotoLinkTo = Map::MapPhotoLinkTo::LinkToPost
  )
    @x_tile1 = @tiles_layer.x_tile1.as(Int32)
    @x_tile2 = @tiles_layer.x_tile2.as(Int32)
    @y_tile1 = @tiles_layer.y_tile1.as(Int32)
    @y_tile2 = @tiles_layer.y_tile2.as(Int32)

    @map_height = @tiles_layer.map_height.as(Int32)
    @map_width = @tiles_layer.map_width.as(Int32)

    @filtered_photos = filter_photos(photos).as(Array(PhotoEntity))

    # do not render photos closes to each other
    @last_photo_point_x = 0
    @last_photo_point_y = 0

    # this is used for calculating ideal place for photo
    @all_route_points = SingleRouteObject.new

    @posts.each do |post|
      post.detailed_routes.each do |route_object|
        @all_route_points += route_object.route.as(SingleRouteObject)
      end
    end

    # 1. populate blocking @blocked_coord_ranges
    @blocked_coord_ranges = Array(Map::MapCoordRange).new
    populate_route_coord_ranges

    # 2. iterate by photo and find suitable spot
    @photo_center_to_corner = (@image_size / 2).to_i.as(Int32)
    @photo_margin = (MARGIN_COEFF * @photo_center_to_corner).to_i.as(Int32)
    @photo_positions = Array(Map::PhotoToRoutePosition).new
    assign_photo_positions

    # 3. fix crossed photos
    fix_crossing_photos
  end

  private def populate_route_coord_ranges
    @posts.each do |post|
      post.detailed_routes.each do |route_object|
        geo_coords = route_object.route.as(SingleRouteObject)
        next if geo_coords.size < 2

        # coord range requre from and to
        (1...geo_coords.size).each do |i|
          x_from, y_from = @tiles_layer.in_map_position_from_geo_coords(
            lat_deg: geo_coords[i - 1][0],
            lon_deg: geo_coords[i - 1][1]
          ).as(Tuple(Int32, Int32))

          x_to, y_to = @tiles_layer.in_map_position_from_geo_coords(
            lat_deg: geo_coords[i][0],
            lon_deg: geo_coords[i][1]
          ).as(Tuple(Int32, Int32))

          map_coord = MapCoordRange.new(
            x_from: [x_from, x_to].min - BLOCKED_ROUTE_PADDING,
            y_from: [y_from, y_to].min - BLOCKED_ROUTE_PADDING,
            x_to: [x_from, x_to].max + BLOCKED_ROUTE_PADDING,
            y_to: [y_from, y_to].max + BLOCKED_ROUTE_PADDING,
          )

          @blocked_coord_ranges << map_coord
        end
      end
    end
  end

  private def find_route_bearing_for_point(lat, lon)
    # sort
    sorted_points = @all_route_points.sort do |a, b|
      distance_a = Math.sqrt(((a[0] - lat) ** 2) + ((a[1] - lon) ** 2))
      distance_b = Math.sqrt(((b[0] - lat) ** 2) + ((b[1] - lon) ** 2))
      distance_a <=> distance_b
    end

    # select only few closest
    cropped_points = sorted_points.select do |a|
      distance_a = Math.sqrt(((a[0] - lat) ** 2) + ((a[1] - lon) ** 2))
      distance_a < BEARING_ROUTE_CLOSEST_DISTANCE
    end[0..BEARING_ROUTE_CROP_SIZE]

    # convert to x/y
    converted_points = cropped_points.map do |geo_coord|
      @tiles_layer.in_map_position_from_geo_coords(
        lat_deg: geo_coord[0],
        lon_deg: geo_coord[1]
      ).as(Tuple(Int32, Int32))
    end

    x_array = converted_points.map { |g| g[0] }
    y_array = converted_points.map { |g| g[1] }

    return nil if x_array.size == 0 || y_array.size == 0

    x_distance = x_array.max - x_array.min
    y_distance = y_array.max - y_array.min

    degree = 180.0 * Math.atan2(x_distance.to_f, y_distance.to_f) / Math::PI

    return degree
  end

  private def assign_photo_positions
    @filtered_photos.sort.each do |photo|
      lat = photo.exif.lat.not_nil!
      lon = photo.exif.lon.not_nil!

      point_x, point_y = @tiles_layer.in_map_position_from_geo_coords(
        lat_deg: lat,
        lon_deg: lon,
      ).as(Tuple(Int32, Int32))

      degree = find_route_bearing_for_point(lat, lon)

      if (@last_photo_point_x - point_x).abs + (@last_photo_point_y - point_y).abs > CLOSEST_PHOTO_POINT
        distance_to_last_photo = CLOSEST_PHOTO_POINT
      else
        distance_to_last_photo = Math.sqrt((@last_photo_point_x - point_x) ** 2 + (@last_photo_point_y - point_y) ** 2).to_i
        # distance_longer = distance_to_last_photo > CLOSEST_PHOTO_POINT
      end

      spot_for_photo = find_photo_spot_for_point(point_x, point_y, degree)

      if spot_for_photo && distance_to_last_photo
        # set photo coordinates (not point) on map
        photo_center_x = spot_for_photo.not_nil!.x_center
        photo_center_y = spot_for_photo.not_nil!.y_center

        photo_position = PhotoToRoutePosition.new(
          photo_entity: photo,
          point_x: point_x,
          point_y: point_y,
          photo_center_x: photo_center_x,
          photo_center_y: photo_center_y,
          corner_photo_x: photo_center_x - @photo_center_to_corner,
          corner_photo_y: photo_center_y - @photo_center_to_corner,
        )

        @photo_positions << photo_position

        @last_photo_point_x = point_x
        @last_photo_point_y = point_y

        # add as blocked
        @blocked_coord_ranges << spot_for_photo.not_nil!
      end
    end
  end

  private def find_photo_spot_for_point(point_x, point_y, degree)
    possible_map_coords = Array(MapCoordRange).new
    possible_photo_coords = Array(Tuple(Int32, Int32)).new

    # degree bases, best strategy
    if degree
      DISTANCES_FROM_POINT_SIDE.each do |distance|
        [degree.not_nil! - 90.0, degree.not_nil! + 90.0].each do |iteration_degree|
          photo_x = point_x - (Math.sin(iteration_degree) * distance.to_f).to_i
          photo_y = point_y - (Math.cos(iteration_degree) * distance.to_f).to_i

          # TODO think about logging
          # Log.debug { "route side photo spot #{photo_x},#{photo_y}" }

          possible_photo_coords << {photo_x, photo_y}
        end
      end
    end

    # circle around point, good but not great
    iteration_degree = 0
    DISTANCES_FROM_POINT.each do |distance|
      while iteration_degree < 360
        # minus to start from top
        photo_x = point_x - (Math.sin(iteration_degree) * distance.to_f).to_i
        photo_y = point_y - (Math.cos(iteration_degree) * distance.to_f).to_i

        # Log.debug { "rotated photo spot #{photo_x},#{photo_y}" }

        possible_photo_coords << {photo_x, photo_y}

        iteration_degree += DEGREE_INCREMENTAL
      end
    end

    # process photo center point
    possible_photo_coords.each do |coord|
      photo_x = coord[0]
      photo_y = coord[1]

      x_from = photo_x - @photo_margin
      y_from = photo_y - @photo_margin
      x_to = photo_x + @photo_margin
      y_to = photo_y + @photo_margin

      positioned_on_map = x_from >= 0 && y_from >= 0 && x_to <= @map_width && y_to <= @map_height

      if positioned_on_map
        possible_map_coords << MapCoordRange.new(
          x_from: x_from,
          y_from: y_from,
          x_to: x_to,
          y_to: y_to,
        )
      end
    end

    filtered_map_coords = possible_map_coords.select do |map_coord|
      @blocked_coord_ranges.select do |blocked_coord_range|
        blocked_coord_range.overlap_other(map_coord)
      end.size == 0
    end

    if filtered_map_coords.size > 0
      Log.debug { "point #{point_x},#{point_y} - filtered possible coords #{filtered_map_coords.size}" }
      return filtered_map_coords.first
    else
      return nil
    end
  end

  private def filter_photos(photos)
    array = Array(PhotoEntity).new
    photos.sort do |a, b|
      # sort by taken at
      a.exif.time.not_nil! <=> b.exif.time.not_nil!
    end.each do |photo|
      if array.size > 0
        last_photo = array.last
        last_photo_lat = last_photo.exif.lat.not_nil!
        last_photo_lon = last_photo.exif.lon.not_nil!

        current_photo_lat = photo.exif.lat.not_nil!
        current_photo_lon = photo.exif.lon.not_nil!

        distance = Math.sqrt(((last_photo_lat - current_photo_lat) ** 2) + ((last_photo_lon - current_photo_lon) ** 2))
        array << photo if distance > MIN_GEO_DISTANCE
      else
        # always add first
        array << photo
      end
    end
    return array
  end

  private def fix_crossing_photos
    # TODO not working as intended
    return

    (1...@photo_positions.size).each do |i|
      previous = @photo_positions[i - 1]
      current = @photo_positions[i]

      point_distance = Math.sqrt(
        ((previous.point_x - current.point_x) ** 2) +
        ((previous.point_y - current.point_y) ** 2)
      )

      switch = false

      if point_distance < 150 && (previous.point_x > current.photo_center_x && current.point_x < previous.photo_center_x)
        # Log.debug { "switch X @photo_positions #{i - 1} <> #{i}" }
        switch = true
      end

      if point_distance < 150 && (previous.point_y > current.photo_center_y && current.point_y < previous.photo_center_y)
        # Log.debug { "switch Y @photo_positions #{i - 1} <> #{i}" }
        switch = true
      end

      if switch
        new_previous = PhotoToRoutePosition.new(
          photo_entity: previous.photo_entity,
          point_x: previous.point_x,
          point_y: previous.point_y,
          photo_center_x: current.photo_center_x,
          photo_center_y: current.photo_center_y,
          corner_photo_x: current.corner_photo_x,
          corner_photo_y: current.corner_photo_y,
        )

        new_current = PhotoToRoutePosition.new(
          photo_entity: current.photo_entity,
          point_x: current.point_x,
          point_y: current.point_y,
          photo_center_x: previous.photo_center_x,
          photo_center_y: previous.photo_center_y,
          corner_photo_x: previous.corner_photo_x,
          corner_photo_y: previous.corner_photo_y,
        )

        @photo_positions[i - 1] = new_previous
        @photo_positions[i] = new_current
      end
    end
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-to-route-photos' >\n"

      @photo_positions.each do |photo_position|
        s << photo_position_to_svg_pointer(photo_position)
      end

      # to not play with z-index it's better to render
      # drawing before putting images
      @photo_positions.each do |photo_position|
        s << photo_position_to_svg_image(photo_position)
      end

      s << "</g>\n"
    end
  end

  def photo_position_to_svg_image(photo_position)
    photo_entity = photo_position.photo_entity
    url = photo_entity.map_thumb_image_src
    post_url = photo_entity.post_url
    photo_url = photo_entity.full_image_src

    corner_photo_x = photo_position.corner_photo_x
    corner_photo_y = photo_position.corner_photo_y

    @crop.mark_point(corner_photo_x.to_i, corner_photo_y.to_i, :assigned_photo_position1)
    @crop.mark_point(corner_photo_x.to_i + @image_size, corner_photo_y.to_i + @image_size, :assigned_photo_position2)
    # no need to add route point for cropping

    # for single post maps render link to image full size not post

    href_url = case @photo_link_to
               when Map::MapPhotoLinkTo::LinkToPhoto
                 photo_url
               when Map::MapPhotoLinkTo::LinkToPost
                 post_url
               end

    return String.build do |s|
      s << "<svg x='#{corner_photo_x.to_i}' y='#{corner_photo_y.to_i}' width='#{@image_size}' height='#{@image_size}' class='photo-map-photo'>\n"
      s << "<a href='#{href_url}' target='_blank'>\n"
      s << "<image href='#{url}' preserveAspectRatio='xMidYMid slice' width='#{@image_size}' height='#{@image_size}' />\n"
      s << "</a>\n"
      s << "</svg>\n"
    end
  end

  def photo_position_to_svg_pointer(photo_position)
    photo_center_x = photo_position.photo_center_x
    photo_center_y = photo_position.photo_center_y
    point_x = photo_position.point_x
    point_y = photo_position.point_y

    return String.build do |s|
      s << "<polyline class='photo-pointer' fill='none' style='stroke:rgb(0,0,0);stroke-width:1' points='"
      s << "#{photo_center_x.to_i},#{photo_center_y.to_i} #{point_x.to_i},#{point_y.to_i}'  />\n"
      s << "<circle cx='#{point_x.to_i}' cy='#{point_y.to_i}' r='5' stroke='black' stroke-width='2' fill='white' />\n"
    end
  end
end
