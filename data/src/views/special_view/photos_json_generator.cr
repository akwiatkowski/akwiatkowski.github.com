require "json"

module SpecialView
  class PhotosJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/photos.json",
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
      all_photos = Array(PhotoEntity).new
      @context.posts.each do |post|
        all_photos += post.all_photo_entities_unsorted
      end

      result = JSON.build do |json|
        json.object do
          json.field "routes" do
            json.array do
              # TODO: in future
            end
          end

          json.field "photos" do
            json.array do
              all_photos.each do |photo_entity|
                next if photo_entity.desc.to_s.size < 4 # no desc
                json.object do
                  json.field("desc", photo_entity.desc)
                  json.field("full_url", photo_entity.full_image_src)
                  json.field("article_url", photo_entity.article_image_src)

                  json.field("time", photo_entity.time)
                  json.field("post_slug", photo_entity.post_slug)
                  json.field("post_url", photo_entity.post_url)
                  json.field("is_published", photo_entity.tags.size > 0)
                  json.field("points", photo_entity.points)

                  json.field("tags", photo_entity.tags)

                  if photo_entity.exif
                    json.field("exif.lat", photo_entity.exif.lat)
                    json.field("exif.lon", photo_entity.exif.lon)
                    json.field("exif.altitude", photo_entity.exif.altitude)

                    json.field("exif.focal_35mm", photo_entity.exif.focal_length_35)
                    json.field("exif.aperture", photo_entity.exif.aperture)
                    json.field("exif.exposure", photo_entity.exif.exposure)
                    json.field("exif.iso", photo_entity.exif.iso)

                    json.field("exif.lens_name", photo_entity.exif.lens_name)
                    json.field("exif.camera_name", photo_entity.exif.camera_name)
                    json.field("exif.time", photo_entity.exif.time)
                  end
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
