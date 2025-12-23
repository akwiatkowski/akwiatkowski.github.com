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
  @start : String
  @finish : String
  @surfaces : Array(String)
  @towns : Array(String)

  getter :link, :distance, :elevation, :days_min, :days_normal,
    :start, :finish, :surfaces, :towns, :slug

  def initialize(y : YAML::Any)
    @slug = y["slug"].as_s
    @link = y["link"].as_s
    @distance = y["distance"].as_i
    @elevation = y["elevation"].as_i?
    @days_min = y["days_min"].as_i
    @days_normal = y["days_normal"].as_i
    @start = y["start"].as_s
    @finish = y["finish"].as_s

    @surfaces = Array(String).new
    y["surfaces"].as_a.each do |surface|
      @surfaces << surface.as_s
    end

    @towns = Array(String).new
    y["towns"].as_a.each do |town|
      @towns << town.as_s
    end
  end

  def photo_map_url
    Map::LinkGenerator.url_photomap_for_idea(slug: slug)
  end

  # load and process assigned YAML coord file and generate array of PostRouteObject
  # TODO: maybe move it to service?
  def routes(blog : Tremolite::Blog, type : String) : Array(PostRouteObject)
    ideas_path = File.join([blog.data_path, "ideas"])
    idea_routes_path = File.join([ideas_path, "#{slug}.json"])

    json = File.open(idea_routes_path) do |file|
      JSON.parse(file)
    end

    routes = Array(PostRouteObject).new

    json.as_a.each do |route_json|
      single_route = SingleRouteObject.new

      route_json.as_a.each do |coord|
        single_route << [coord[0].as_f, coord[1].as_f]
      end

      route = PostRouteObject.new(
        type: type,
        route: single_route
      )

      routes << route
    end

    return routes
  end

  # TODO: maybe allow to get array of strings also?
  def towns_already_visited(visited_towns : Array(TownEntity)) : Int32
    visited_slugs = visited_towns.map { |town_entity| town_entity.slug }.flatten
    common = [visited_slugs & @towns].flatten
    return common.size
  end

  # TODO: maybe allow to get array of strings also?
  def towns_not_visited(visited_towns : Array(TownEntity)) : Int32
    visited_slugs = visited_towns.map { |town_entity| town_entity.slug }.flatten
    not_visited = [visited_slugs - @towns].flatten
    not_visited.size
  end

  def time_cost_to_visit_new_town(
    visited_towns : Array(TownEntity),
    total_train_ride_time : Int32,     # rounded, ceiling
    realistic_velocity : Int32 = 10,   # km/h per ride-time (no sleeping and rest time)
    max_per_day_ride_time : Int32 = 8, # hours
  ) : Int32
    sleep_and_rest_time = 0.0
    realistic_ride_time = distance.to_f / realistic_velocity.to_f

    time = realistic_ride_time
    while time > max_per_day_ride_time.to_f
      time -= max_per_day_ride_time.to_f
      sleep_and_rest_time += (24.0 - max_per_day_ride_time.to_f)
    end

    total_train_ride_time.to_f

    total_time = sleep_and_rest_time + realistic_ride_time + total_train_ride_time.to_f

    not_visited = towns_not_visited(visited_towns)

    if not_visited == 0
      return 100 # failsafe
    else
      return (total_time / not_visited.to_f).ceil.to_i
    end
  end
end
