class Map::Crop
  CROP_PADDING = 50

  def initialize
    @x_points = Array(Int32).new
    @y_points = Array(Int32).new
  end

  def mark_point(x, y, debug_name)
    @x_points << x
    @y_points << y
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
end
