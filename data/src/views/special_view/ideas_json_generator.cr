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
                  json.field("slug", idea.slug)
                  json.field("link", idea.link)
                  json.field("distance", idea.distance)
                  json.field("elevation", idea.elevation)
                  json.field("lindays_mink", idea.days_min)
                  json.field("days_normal", idea.days_normal)
                  json.field("start", idea.start)
                  json.field("finish", idea.finish)
                  json.field("surface", idea.surface)
                  json.field("towns", idea.towns)
                  json.field("photo_map_url", idea.photo_map_url)
                end
              end
            end
          end
          # END
        end
      end

      return result
    end
  end
end
