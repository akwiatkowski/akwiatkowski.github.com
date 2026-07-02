require "json"

module SpecialView
  class PhotosMapJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/photos_map.json",
    )
      @context = context
    end

    getter :url

    def output
      to_json
    end

    def add_to_sitemap?
      return false
    end

    def to_json
      all_photos = Array(PhotoEntity).new
      @context.posts.each do |post|
        all_photos += post.all_photo_entities_unsorted
      end

      result = JSON.build do |json|
        json.object do
          json.field "photos" do
            json.array do
              all_photos.each do |photo_entity|
                next if photo_entity.desc.to_s.size < 4
                next unless photo_entity.exif
                next unless photo_entity.exif.lat
                next unless photo_entity.exif.lon

                json.object do
                  json.field("desc", photo_entity.desc)
                  json.field("full_url", photo_entity.full_image_src)
                  json.field("article_url", photo_entity.article_image_src)
                  json.field("article_url_avif", photo_entity.article_avif_src)
                  json.field("grid_url", photo_entity.grid_image_src)
                  json.field("grid_url_avif", photo_entity.grid_avif_src)
                  json.field("thumbnail_url", photo_entity.thumbnail_image_src)
                  json.field("time", photo_entity.time)
                  json.field("post_slug", photo_entity.post_slug)
                  json.field("post_url", photo_entity.post_url)
                  json.field("points", photo_entity.points)
                  json.field("tags", photo_entity.tags)

                  json.field("exif.lat", photo_entity.exif.lat)
                  json.field("exif.lon", photo_entity.exif.lon)
                  json.field("exif.altitude", photo_entity.exif.altitude)
                  json.field("exif.time", photo_entity.exif.time)
                  json.field("exif.camera_name", photo_entity.exif.camera_name)
                  json.field("exif.lens_name", photo_entity.exif.lens_name)
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
