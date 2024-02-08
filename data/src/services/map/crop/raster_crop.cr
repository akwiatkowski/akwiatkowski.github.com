struct Map::Crop::Point
  def initialize(@x : Int32, @y : Int32, @type : Symbol)
  end

  getter :x, :y, :type

  def to_tuple
    {x: @x, y: @y, type: @type.to_s}
  end
end

class Map::Crop::RasterCrop
  # 30px is good for big linear routes
  CROP_PADDING = 80
  # in case when route is map and it takes only center
  # I want to enlarge center area to increase overall margin
  MIN_AXIS_RASTER_SIZE = 300

  # append points array in debug output
  FULL_DEBUG = true

  def initialize(@type : Map::CoordCropType)
    @additional_crop_for_small_route = false
    @half_x_distance = 0
    @half_y_distance = 0

    @points = Array(Point).new
  end

  def mark_point!(x, y, type : Symbol)
    @points << Point.new(
      x: x,
      y: y,
      type: type
    )
  end

  def x_points
    @points.map { |p| p.x }
  end

  def y_points
    @points.map { |p| p.y }
  end

  def photo(x, y)
    if photo_can_enlarge?
      mark_point!(x, y, :photo)
    end
  end

  def assigned_photo_photo(x1, y1, x2, y2)
    if photo_can_enlarge?
      mark_point!(x1, y2, :assigned_photo1)
      mark_point!(x2, y2, :assigned_photo2)
    end
  end

  def photo_dot(x, y)
    if photo_can_enlarge?
      mark_point!(x, y, :photo_dot)
    end
  end

  def square_photo(x, y, size)
    if photo_can_enlarge?
      mark_point!(x, y, :square_photo1)
      mark_point!(x + size, y + size, :square_photo1)
    end
  end

  def route(x, y)
    if route_can_enlarge?
      mark_point!(x, y, :route)
    end
  end

  # if map is quite small and zoom would be too much it's better to increase
  # central area and display "bigger margin" to show more area
  def increase_margin_for_small_maps
    # do it only once
    return if @additional_crop_for_small_route

    if uncropped_width < MIN_AXIS_RASTER_SIZE
      @half_x_distance = ((MIN_AXIS_RASTER_SIZE - uncropped_width) / 2).to_i
    end

    if uncropped_height < MIN_AXIS_RASTER_SIZE
      @half_y_distance = ((MIN_AXIS_RASTER_SIZE - uncropped_height) / 2).to_i
    end

    if @half_x_distance > 0 || @half_y_distance > 0
      @additional_crop_for_small_route = true

      mark_point!(x_min - @half_x_distance, y_min - @half_y_distance, :margin1)
      mark_point!(x_max + @half_x_distance, y_min - @half_y_distance, :margin2)

      mark_point!(x_min - @half_x_distance, y_max + @half_y_distance, :margin3)
      mark_point!(x_max + @half_x_distance, y_max + @half_y_distance, :margin4)
    end
  end

  # w/o padding
  def x_min
    return 0 if blank?

    return x_points.min
  end

  def x_max
    return 400 if blank?

    return x_points.max
  end

  def y_min
    return 0 if blank?

    return y_points.min
  end

  def y_max
    return 300 if blank?

    return y_points.max
  end

  def blank?
    x_points.size == 0 || y_points.size == 0
  end

  # with padding
  def crop_x
    return 0 if blank?

    increase_margin_for_small_maps

    x = x_min - CROP_PADDING
    x = 0 if x < 0
    return x
  end

  def crop_y
    return 0 if blank?

    increase_margin_for_small_maps

    y = y_min - CROP_PADDING
    y = 0 if y < 0

    return y
  end

  # helpers for max values (lower bottom)
  def crop_x_max(map_width)
    return map_width if blank?

    increase_margin_for_small_maps

    x = x_max + CROP_PADDING
    x = map_width if x > map_width
    return x
  end

  def crop_y_max(map_height)
    return map_height if blank?

    increase_margin_for_small_maps

    y = y_max + CROP_PADDING
    y = map_height if y > map_height
    return y
  end

  def cropped_width(map_width)
    return map_width if blank?

    return crop_x_max(map_width) - crop_x
  end

  def cropped_height(map_height)
    return map_height if blank?

    return crop_y_max(map_height) - crop_y
  end

  def uncropped_width
    return x_max - x_min
  end

  def uncropped_height
    return y_max - y_min
  end

  def debug_hash(map_width, map_height)
    if FULL_DEBUG
      detailed_debug = {
        points: @points.map { |p| p.to_tuple },
      }
    else
      detailed_debug = nil
    end

    return {
      detailed_debug: detailed_debug,
      blank:          blank?,
      basic:          {
        x_min: x_min,
        x_max: x_max,
        y_min: y_min,
        y_max: y_max,
      },
      crop_top_left: {
        crop_x: crop_x,
        crop_y: crop_y,
      },
      crop_bottom_right: {
        crop_x_max: crop_x_max(map_width),
        crop_y_max: crop_y_max(map_height),
      },
      cropped_dimenstion: {
        cropped_width:  cropped_width(map_width),
        cropped_height: cropped_height(map_height),
      },
      uncropped_dimenstion: {
        uncropped_width:  uncropped_width,
        uncropped_height: uncropped_height,
      },
      additional_margin_dimension: {
        half_x_distance:                 @half_x_distance,
        half_y_distance:                 @half_y_distance,
        additional_crop_for_small_route: @additional_crop_for_small_route,
      },
    }
  end

  def photo_can_enlarge?
    @type == CoordCropType::PhotoCrop || @type == CoordCropType::PhotoAndRouteCrop
  end

  def route_can_enlarge?
    @type == CoordCropType::RouteCrop || @type == CoordCropType::PhotoAndRouteCrop
  end
end
