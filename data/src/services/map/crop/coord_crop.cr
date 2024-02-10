class Map::Crop::CoordCrop
  def initialize(@type : Map::CoordCropType, @fixed_coord_range : CoordRange?)
    @coord_range = CoordRange.new
  end

  def coord_range
    if @fixed_coord_range
      # more important than @coord_range which can be changed
      # by adding route element or photo
      @fixed_coord_range.not_nil!.limit_to_poland
    else
      @coord_range.limit_to_poland
    end
  end

  # TODO: write method which will crop depending on type
  # which is set
  #
  # TODO: get rid of croping code and params
  #
  # TODO: think about voivodeships

  def photo(lat, lon)
    if photo_can_enlarge?
      @coord_range.enlarge!(lat, lon)
    end
  end

  def route(lat, lon)
    if route_can_enlarge?
      @coord_range.enlarge!(lat, lon)
    end
  end

  def photo_can_enlarge?
    @type == CoordCropType::PhotoCrop || @type == CoordCropType::PhotoAndRouteCrop
  end

  def route_can_enlarge?
    @type == CoordCropType::RouteCrop || @type == CoordCropType::PhotoAndRouteCrop
  end
end
