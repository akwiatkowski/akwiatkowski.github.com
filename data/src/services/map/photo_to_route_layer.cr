struct Map::PhotoToRouteSlot
  @photo : PhotoEntity?
  @photo_point_x : Int32?
  @photo_point_y : Int32?

  getter :corner_photo_x, :corner_photo_y, :size_x, :size_y
  getter :photo, :is_blocked_by_route
  getter :photo_point_x, :photo_point_y
  getter :x, :y

  def initialize(
    @corner_photo_x : Int32,
    @corner_photo_y : Int32,
    @size_x : Int32,
    @size_y : Int32,
  )
    @x = (@corner_photo_x + (@size_x / 2).to_i).as(Int32)
    @y = (@corner_photo_y + (@size_y / 2).to_i).as(Int32)
    @is_blocked_by_route = false
  end

  def is_blocked_by_route!
    return false if @is_blocked_by_route
    @is_blocked_by_route = true
  end

  def is_free?
    return @is_blocked_by_route != true && @photo.nil?
  end

  def assign_photo_position!(photo_position : PhotoToRoutePosition)
    @photo = photo_position.photo_entity
    @photo_point_x = photo_position.point_x
    @photo_point_y = photo_position.point_y
  end
end

struct Map::PhotoToRoutePosition
  getter :photo_entity, :point_x, :point_y

  def initialize(
    @photo_entity : PhotoEntity,
    @point_x : Int32,
    @point_y : Int32
  )
  end
end

class Map::PhotoToRouteLayer

  SLOT_SPACING_COEF    = 1.3
  SLOT_INITIAL_PADDING =   30
  BLOCK_SPOT_RANGE_COEFF = 1.1
  CLOSEST_SPOT_RANGE = 350

  def initialize(
    @photos : Array(PhotoEntity),
    @posts : Array(Tremolite::Post),
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

    # new attempt is to divide map into possible slots first
    @photo_slot_distance = (@image_size.to_f * SLOT_SPACING_COEF).to_i.as(Int32)
    @photo_block_distance = (@photo_slot_distance * BLOCK_SPOT_RANGE_COEFF).to_i.as(Int32)
    @slots_matrix = Hash(Int32, Hash(Int32, PhotoToRouteSlot)).new
    @slots_matrix_xs = Array(Int32).new
    @slots_matrix_ys = Array(Int32).new
    @photo_to_route_positions = Array(PhotoToRoutePosition).new
    # 1. initialize slots
    initialize_empty_slots
    # 2. mark blocked by route
    mark_blocked_slots_by_route
    # 3. add in closest possible slots
    calculate_point_positions_and_assign_slot
    # 4. if there is not slot, ignore

    # @photo_to_route_map_sets = Array(PhotoToRouteMapSet).new
    # @photo_to_route_map_sets = @filtered_photos.map do |photo|
    #   photo_to_photo_route_map_set(photo)
    # end.as(Array(PhotoToRouteMapSet))
  end

  private def initialize_empty_slots
    @logger.debug("#{self.class} initialize_empty_slots")
    x = SLOT_INITIAL_PADDING
    while x < (@map_width - @photo_slot_distance)
      @slots_matrix[x] = Hash(Int32, PhotoToRouteSlot).new
      @slots_matrix_xs << x unless @slots_matrix_xs.includes?(x)

      y = SLOT_INITIAL_PADDING
      while y < (@map_width - @photo_slot_distance)
        @slots_matrix_ys << y unless @slots_matrix_ys.includes?(y)
        @slots_matrix[x][y] = PhotoToRouteSlot.new(
          corner_photo_x: x,
          corner_photo_y: y,
          size_x: @image_size,
          size_y: @image_size,
        )

        y += @photo_slot_distance
      end

      x += @photo_slot_distance
    end
  end

  private def mark_blocked_slots_by_route
    @posts.each do |post|
      post.detailed_routes.each do |route_object|
        geo_coords = route_object.route.as(SingleRouteObject)
        geo_coords.each do |geo_coord|
          x, y = @tiles_layer.in_map_position_from_geo_coords(
            lat_deg: geo_coord[0],
            lon_deg: geo_coord[1]
          ).as(Tuple(Int32, Int32))

          # TODO move 2 to
          block_slots_near(x: x, y: y, range: @photo_block_distance)
        end
      end
    end
  end

  private def block_slots_near(x, y, range)
    @slots_matrix_xs.each do |x_key|
      @slots_matrix_ys.each do |y_key|
        distance = Math.sqrt(((x_key - x) ** 2) + ((y_key - y) ** 2))
        if distance <= range
          slot = @slots_matrix[x_key][y_key]
          if slot.is_blocked_by_route
            @logger.debug("block_slots: x,y=#{x},#{y} x_key,y_key=#{x_key},#{y_key} distance=#{distance} <= range=#{range}")
          end
          slot.is_blocked_by_route!
          @slots_matrix[x_key][y_key] = slot
        end
      end
    end
  end


  private def calculate_point_positions_and_assign_slot
    @photos.each do |photo|
      x, y = @tiles_layer.in_map_position_from_geo_coords(
        lat_deg: photo.exif.lat.not_nil!,
        lon_deg: photo.exif.lon.not_nil!,
      ).as(Tuple(Int32, Int32))

      @photo_to_route_positions << PhotoToRoutePosition.new(
        photo_entity: photo,
        point_x: x,
        point_y: y,
      )
    end

    @photo_to_route_positions.each do |photo_position|
      slots = closest_free_slots(
        x: photo_position.point_x,
        y: photo_position.point_y,
        range: CLOSEST_SPOT_RANGE
      )

      if slots.size > 0
        slot = slots.first
        slot.assign_photo_position!(photo_position)
        # need to set
        # not sure why :(
        @slots_matrix[slot.corner_photo_x][slot.corner_photo_y] = slot
      end
    end
  end

  private def closest_free_slots(x, y, range)
    slots = Array(PhotoToRouteSlot).new
    @slots_matrix_xs.each do |x_key|
      @slots_matrix_ys.each do |y_key|
        slot = @slots_matrix[x_key][y_key]
        if slot.is_free?
          distance = Math.sqrt(((x_key - x) ** 2) + ((y_key - y) ** 2))
          if distance <= range
            slots << slot
          end
        end
      end
    end

    return slots.sort do |a, b|
      distance_a = Math.sqrt(((a.x - x) ** 2) + ((a.y - y) ** 2))
      distance_b = Math.sqrt(((b.x - x) ** 2) + ((b.y - y) ** 2))
      distance_a <=> distance_b
    end
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

      @slots_matrix_xs.each do |x_key|
        @slots_matrix_ys.each do |y_key|
          slot = @slots_matrix[x_key][y_key]
          if slot.photo
            s << photo_slot_to_svg_image(slot)
          end
        end
      end

      s << "</g>\n"
    end
  end

  def photo_slot_to_svg_image(slot)
    photo_entity = slot.photo.not_nil!
    url = photo_entity.gallery_thumb_image_src
    post_url = photo_entity.post_url

    photo_center_x = slot.x
    photo_center_y = slot.y
    point_x = slot.photo_point_x.not_nil!
    point_y = slot.photo_point_y.not_nil!
    corner_photo_x = slot.corner_photo_x
    corner_photo_y = slot.corner_photo_y

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
