class Map::Crop::CoordCrop
  def initialize(@type : Map::CoordCropType)
    @coord_range = CoordRange.new
  end

  def coord_range
    @coord_range.limit_to_poland
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
