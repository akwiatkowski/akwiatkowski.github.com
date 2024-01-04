class Map::Crop::RasterCrop
  CROP_PADDING = 30

  def initialize(@type : Map::CoordCropType)
    @x_points = Array(Int32).new
    @y_points = Array(Int32).new
  end

  def mark_point!(x, y)
    @x_points << x
    @y_points << y
  end

  def photo(x, y)
    if photo_can_enlarge?
      mark_point!(x, y)
    end
  end

  def assigned_photo_photo(x1, y1, x2, y2)
    if photo_can_enlarge?
      mark_point!(x1, y2)
      mark_point!(x2, y2)
    end
  end

  def photo_dot(x, y)
    if photo_can_enlarge?
      mark_point!(x, y)
    end
  end

  def square_photo(x, y, size)
    if photo_can_enlarge?
      mark_point!(x, y)
      mark_point!(x + size, y + size)
    end
  end

  def route(x, y)
    if route_can_enlarge?
      mark_point!(x, y)
    end
  end

  # w/o padding
  def x_min
    return 0 if blank?

    return @x_points.min
  end

  def x_max
    return 400 if blank?

    return @x_points.max
  end

  def y_min
    return 0 if blank?

    return @y_points.min
  end

  def y_max
    return 300 if blank?

    return @y_points.max
  end

  def blank?
    @x_points.size == 0 || @y_points.size == 0
  end

  # with padding
  def crop_x
    return 0 if blank?

    x = x_min - CROP_PADDING
    x = 0 if x < 0
    return x
  end

  def crop_y
    return 0 if blank?

    y = y_min - CROP_PADDING
    y = 0 if y < 0

    return y
  end

  # helpers for max values (lower bottom)
  def crop_x_max(map_width)
    return map_width if blank?

    x = x_max + CROP_PADDING
    x = map_width if x > map_width
    return x
  end

  def crop_y_max(map_height)
    return map_height if blank?

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

  def debug_hash(map_width, map_height)
    return {
      # arrays: {
      #   x_points: @x_points.sort,
      #   y_points: @y_points.sort
      # },
      blank: blank?,
      basic: {
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
    }
  end

  def photo_can_enlarge?
    @type == CoordCropType::PhotoCrop || @type == CoordCropType::PhotoAndRouteCrop
  end

  def route_can_enlarge?
    @type == CoordCropType::RouteCrop || @type == CoordCropType::PhotoAndRouteCrop
  end
end
