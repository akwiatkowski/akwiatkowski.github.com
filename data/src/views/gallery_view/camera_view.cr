require "./abstract_view"

module GalleryView
  # camera showcase
  class CameraView < AbstractView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @camera : String,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false
    )
      @photo_entities = photo_entities_with_tags(@tags, @include_headers).select { |p|
        p.exif.camera_name == @camera
      }.as(Array(PhotoEntity))

      @title = @camera
      @camera_sanitized = @camera.gsub(/\s/, "_").downcase.as(String)
      @url = "/gallery/camera/#{@camera_sanitized}"
    end
  end
end
