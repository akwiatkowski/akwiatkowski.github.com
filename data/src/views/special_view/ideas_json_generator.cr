require "json"

module SpecialView
  class IdeasJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @url : String = "/ideas.json",
    )
    end

    getter :url

    def output
      to_json
    end

    # a bit internal
    def add_to_sitemap?
      return false
    end

    def to_json
      visited_towns = @blog.data_manager.towns_already_visited_only_selfpropelled

      result = JSON.build do |json|
        json.object do
          # towns
          json.field "towns" do
            json.array do
              @blog.data_manager.not_nil!.towns.not_nil!.each do |town|
                json.object do
                  json.field("url", town.view_url)
                  json.field("slug", town.slug)
                  json.field("name", town.name)
                  json.field("image_url", town.image_url)
                  json.field("voivodeship", town.voivodeship)
                  json.field("inside", town.voivodeship)
                end
              end
            end
          end
          # ideas
          json.field "ideas" do
            json.array do
              @blog.data_manager.ideas.not_nil!.each do |idea|
                json.object do
                  start_train_station = get_train_station_for_name(idea.start)
                  finish_train_station = get_train_station_for_name(idea.finish)
                  direction = calculate_direction(
                    start: start_train_station,
                    finish: finish_train_station
                  )
                  total_train_ride_time = (
                    start_train_station.time_distance + finish_train_station.time_distance
                  ).ceil.to_i
                  time_cost_to_visit_new_town = idea.time_cost_to_visit_new_town(
                    visited_towns: visited_towns,
                    total_train_ride_time: total_train_ride_time
                  )

                  json.field("slug", idea.slug)
                  json.field("link", idea.link)
                  json.field("distance", idea.distance)
                  json.field("elevation", idea.elevation)
                  json.field("lindays_mink", idea.days_min)
                  json.field("days_normal", idea.days_normal)
                  json.field("start", start_train_station)
                  json.field("finish", finish_train_station)
                  json.field("direction", direction)
                  json.field("direction_char", compass_normalized(direction))
                  json.field("time_cost_to_visit_new_town", time_cost_to_visit_new_town)
                  json.field("surfaces", idea.surfaces)
                  json.field("towns", idea.towns)
                  json.field("photo_map_url", idea.photo_map_url)
                  json.field("towns_already_visited", idea.towns_already_visited(visited_towns: visited_towns))
                  json.field("towns_not_visited", idea.towns_not_visited(visited_towns: visited_towns))
                end
              end
            end
          end
          # END
        end
      end

      return result
    end

    def get_train_station_for_name(name)
      train_stations = @blog.data_manager.train_stations.not_nil!
      selected = train_station_start = train_stations.select do |train_station|
        train_station.name == name
      end
      if selected.size == 0
        Log.error { "#{name} train station is missing" }
      end
      return selected.first.as(TrainStationEntity)
    end

    def calculate_direction(start : TrainStationEntity, finish : TrainStationEntity)
      return start.direction_to_other_train_station(other: finish)
    end

    def compass_normalized(bearing : Float64) : String
      normalized_bearing = bearing % 180.0

      points = [
        "000 - północny", "022 - północny lekko wschód", "045 - północny wschód", "067 - wschód lekko północ",
        "090 - wschód-zachód", "112 - zachód lekko północ", "135 - północny zachód", "157 - północ lekko zachód",
      ]

      b = ((normalized_bearing % 360.0) + 360.0) % 360.0

      seg_size = 360.0 / points.size # 22.5
      idx = ((b + seg_size / 2.0) / seg_size).floor.to_i % points.size

      points[idx]
    end

    def compass8(bearing : Float64) : String
      points = [
        "N", "NE", "E", "SE",
        "S", "SW", "W", "NW",
      ]

      # Normalize to [0, 360)
      b = ((bearing % 360.0) + 360.0) % 360.0

      seg_size = 360.0 / points.size # 45.0
      # + seg_size/2 so boundaries fall in the middle of segments
      idx = ((b + seg_size / 2.0) / seg_size).floor.to_i % points.size

      points[idx]
    end

    def compass16(bearing : Float64) : String
      points = [
        "N", "NNE", "NE", "ENE",
        "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW",
        "W", "WNW", "NW", "NNW",
      ]

      b = ((bearing % 360.0) + 360.0) % 360.0

      seg_size = 360.0 / points.size # 22.5
      idx = ((b + seg_size / 2.0) / seg_size).floor.to_i % points.size

      points[idx]
    end
  end
end
