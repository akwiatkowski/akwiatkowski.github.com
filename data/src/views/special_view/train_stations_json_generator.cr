require "json"

module SpecialView
  class TrainStationsJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/train_stations.json",
    )
      @context = context
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
      result = JSON.build do |json|
        json.object do
          json.field "train_stations" do
            json.array do
              @context.train_stations.each do |train_station|
                json.object do
                  json.field("name", train_station.name)
                  json.field("lat", train_station.lat)
                  json.field("lon", train_station.lon)
                  json.field("time_distance", train_station.poznan_time_distance)
                end
              end
            end
          end
        end
      end

      return result
    end
  end
end
