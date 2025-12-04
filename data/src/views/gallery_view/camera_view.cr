require "./abstract_view"

module GalleryView
  # camera showcase
  class CameraView < AbstractView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @camera : String,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false,
      @fill_until : Int32 = 0,
    )
      @photo_entities = photo_entities_with_tags(
        all_photos: all_published_photo_entities.select { |p| p.exif.camera_name == @camera },
        tags: @tags,
        include_headers: @include_headers,
        fill_until: fill_until,
      ).as(Array(PhotoEntity))

      @title = @camera
      @camera_sanitized = @camera.gsub(/\s/, "_").downcase.as(String)
      @url = "/galeria/aparat/#{@camera_sanitized}.html"
      @reverse = true
    end
  end
end
