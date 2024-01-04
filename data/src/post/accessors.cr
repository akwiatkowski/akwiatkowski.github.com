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

  getter :tags, :towns, :lands, :pois
  getter :desc, :keywords
  getter :distance, :time_spent
  getter :image_filename, :header_nogallery, :image_position
  getter :finished_at
  getter :head_photo_entity
  getter :default_suggested_map_zooms

  # getter :voivodeships
  def voivodeships
    self.towns
  end

  def bicycle?
    self.tags.not_nil!.includes?(BICYCLE_TAG)
  end

  def hike?
    self.tags.not_nil!.includes?(HIKE_TAG)
  end

  def train?
    self.tags.not_nil!.includes?(TRAIN_TAG)
  end

  def bus?
    self.tags.not_nil!.includes?(BUS_TAG)
  end

  def car?
    self.tags.not_nil!.includes?(CAR_TAG)
  end

  def hidden?
    self.tags.not_nil!.includes?(HIDDEN_TAG)
  end

  def visible?
    !hidden?
  end

  def todo?
    self.tags.not_nil!.includes?(TODO_TAG)
  end

  def todo_media?
    self.tags.not_nil!.includes?(TODO_MEDIA_TAG)
  end

  def photo_of_the_year?
    self.tags.not_nil!.includes?(PHOTO_OF_THE_YEAR_TAG)
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
    return true if train? || car? || bus?
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

  def was_in?(model : (TownEntity | VoivodeshipEntity | TagEntity | LandEntity)) : Bool
    return model.belongs_to_post?(self)
  end

  def was_in_voivodeship(voivodeship_slug : String) : Bool
    @towns.not_nil!.includes?(voivodeship_slug)
  end

  def was_in_voivodeship(voivodeship : TownEntity) : Bool
    @towns.not_nil!.includes?(voivodeship.slug)
  end

  def was_in_voivodeship(voivodeship : VoivodeshipEntity) : Bool
    self.voivodeships.not_nil!.includes?(voivodeship.slug)
  end

  # fix hyphen breaking
  def title
    @title.to_s.gsub("-", "&#x2011;")
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
