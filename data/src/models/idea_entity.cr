require "json"

struct IdeaEntity
  include YAML::Serializable
  include JSON::Serializable

  Log = ::Log.for(self)

  @slug : String
  @link : String
  @distance : Int32
  @elevation : Int32?
  @days_min : Int32
  @days_normal : Int32

  @start : NamedTuple(name: String, lat: Float64, lon: Float64, train_time_distance: Float64)
  @finish : NamedTuple(name: String, lat: Float64, lon: Float64, train_time_distance: Float64)

  @surface : String

  @towns : Array(String)

  getter :link, :distance, :elevation, :days_min, :days_normal,
    :start, :finish, :surface, :towns, :slug

  def initialize(y : YAML::Any)
    @slug = y["slug"].as_s
    @link = y["link"].as_s
    @distance = y["distance"].as_i
    @elevation = y["elevation"].as_i?
    @days_min = y["days_min"].as_i
    @days_normal = y["days_normal"].as_i

    @start = {
      name:                y["start"]["name"].as_s,
      lat:                 y["start"]["lat"].as_f,
      lon:                 y["start"]["lon"].as_f,
      train_time_distance: y["start"]["train_time_distance"].as_f,
    }
    @finish = {
      name:                y["finish"]["name"].as_s,
      lat:                 y["finish"]["lat"].as_f,
      lon:                 y["finish"]["lon"].as_f,
      train_time_distance: y["finish"]["train_time_distance"].as_f,
    }

    @surface = y["surface"].as_s

    @towns = Array(String).new
    y["towns"].as_a.each do |town|
      @towns << town.as_s
    end
  end

  def photo_map_url
    "/photo_map/for_idea/#{slug}/normal.svg"
  end
end
