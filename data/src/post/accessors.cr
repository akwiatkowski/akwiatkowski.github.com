class Tremolite::Post
  BICYCLE_TAG           = "bicycle"
  HIKE_TAG              = "hike"
  TRAIN_TAG             = "train"
  BUS_TAG               = "bus"
  CAR_TAG               = "car"
  PHOTO_OF_THE_YEAR_TAG = "photo_of_the_year"
  TODO_TAG              = "todo"
  TODO_MEDIA_TAG        = "todo_media"
  HIDDEN_TAG            = "hidden"

  CATEGORY_TRIP = "trip"

  getter :tag_slugs, :town_slugs, :land_slugs, :pois
  getter :desc, :keywords
  getter :distance, :time_spent, :temperature
  getter :image_filename, :header_nogallery, :image_position
  getter :finished_at
  getter :head_photo_entity
  getter :default_suggested_map_zooms
  getter :old_url # for 301 redirects

  def bicycle?
    self.tag_slugs.includes?(BICYCLE_TAG)
  end

  def hike?
    self.tag_slugs.includes?(HIKE_TAG)
  end

  def train?
    self.tag_slugs.includes?(TRAIN_TAG)
  end

  def bus?
    self.tag_slugs.includes?(BUS_TAG)
  end

  def car?
    self.tag_slugs.includes?(CAR_TAG)
  end

  def hidden?
    self.tag_slugs.includes?(HIDDEN_TAG)
  end

  def visible?
    !hidden?
  end

  def todo?
    self.tag_slugs.includes?(TODO_TAG)
  end

  def todo_media?
    self.tag_slugs.includes?(TODO_MEDIA_TAG)
  end

  def photo_of_the_year?
    self.tag_slugs.includes?(PHOTO_OF_THE_YEAR_TAG)
  end

  def ready?
    return false if todo?
    return true
  end

  # all other types of light walking activities with >0 distance
  def walk?
    return false if externally_propelled?
    return false if bicycle? || hike?

    return true if self.distance && self.distance.not_nil! > 0.0
    return false
  end

  def externally_propelled?
    train? || car? || bus?
  end

  # distance can be used in stats
  def self_propelled?
    return false if externally_propelled?
    return true if bicycle? || hike? || walk?
    return false
  end

  def trip?
    self.category == CATEGORY_TRIP
  end

  def gallery?
    self.header_nogallery.not_nil! != true
  end

  # Check if post was in a given entity
  # For areas, use was_in_area? from post/areas.cr instead
  def was_in?(model : TagEntity) : Bool
    return model.belongs_to_post?(self)
  end

  def finished_date
    if self.finished_at
      return self.finished_at.not_nil!.to_s("%y-%m-%d")
    else
      return ""
    end
  end

  def default_map_zoom
    possible_default_zooms = (self.default_suggested_map_zooms & Map::VALID_ZOOMS)
    if possible_default_zooms.size > 0
      return possible_default_zooms.first
    else
      return nil
    end
  end
end
