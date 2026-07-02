require "json"

module SpecialView
  # Optimized JSON endpoint for photo planner page
  # Only includes lat/lon coordinate pairs from photos with valid EXIF data
  # Expected size: ~50KB vs 20MB for full /jsons/photos.json
  class PhotoGridJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/photo_grid.json",
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
          json.field "coords" do
            json.array do
              @context.posts.each do |post|
                post.all_photo_entities_unsorted.each do |photo_entity|
                  next unless photo_entity.exif
                  exif = photo_entity.exif
                  next if exif.lat.nil? || exif.lon.nil?

                  json.array do
                    json.number exif.lat.not_nil!
                    json.number exif.lon.not_nil!
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
