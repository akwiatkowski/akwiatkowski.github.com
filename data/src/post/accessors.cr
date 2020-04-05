class Tremolite::Post
  BICYCLE_TAG           = "bicycle"
  HIKE_TAG              = "hike"
  TRAIN_TAG             = "train"
  CAR_TAG               = "car"
  PHOTO_OF_THE_YEAR_TAG = "photo_of_the_year"
  TODO_TAG              = "todo"
  TODO_MEDIA_TAG        = "todo_media"
  HIDDEN_TAG            = "hidden"

  CATEGORY_TRIP = "trip"

  getter :coords
  getter :tags, :towns, :lands, :pois
  getter :desc, :keywords
  getter :distance, :time_spent
  getter :image_filename, :header_nogallery
  getter :finished_at

  def bicycle?
    self.tags.not_nil!.includes?(BICYCLE_TAG)
  end

  def hike?
    self.tags.not_nil!.includes?(HIKE_TAG)
  end

  def train?
    self.tags.not_nil!.includes?(TRAIN_TAG)
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
    return false if train? || car?
    return false if bicycle? || hike?

    return true if self.distance && self.distance.not_nil! > 0.0
    return false
  end

  # distance can be used in stats
  def self_propelled?
    return false if train? || car?
    return true if bicycle? || hike? || walk?
    return false
  end

  def trip?
    self.category == CATEGORY_TRIP
  end

  def gallery?
    self.header_nogallery.not_nil! != true
  end

  def was_in_voivodeship(voivodeship_slug : String) : Bool
    @towns.not_nil!.includes?(voivodeship_slug)
  end

  def was_in_voivodeship(voivodeship : TownEntity) : Bool
    @towns.not_nil!.includes?(voivodeship.slug)
  end
end
