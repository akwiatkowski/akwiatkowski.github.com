require "json"

module SpecialView
  # Optimized JSON endpoint for /mapa_tras.html
  # Only includes posts with GPS coords and minimal fields needed for map display
  # Expected size: ~300KB vs 5MB for full payload.json
  class MapJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/map.json",
    )
      @context = context
    end

    getter :url

    def output
      to_json
    end

    def add_to_sitemap?
      false
    end

    def to_json
      result = JSON.build do |json|
        json.object do
          json.field "posts" do
            json.array do
              @context.posts.each do |post|
                # Only include posts with coords
                next unless post.detailed_routes.any? { |r| r.route.size > 0 }

                json.object do
                  # Basic post info for popup
                  json.field("url", post.url)
                  json.field("slug", post.slug)
                  json.field("title", post.title)
                  json.field("date", post.date)

                  # Stats for popup display
                  json.field("distance", post.distance)
                  json.field("time_spent", post.time_spent)

                  # Image for popup thumbnail
                  json.field("card_image_url", post.card_image_url)

                  # Route data - the main payload
                  json.field "coords" do
                    json.raw post.detailed_routes.to_json
                  end
                end
              end
            end
          end
        end
      end

      result
    end
  end
end
