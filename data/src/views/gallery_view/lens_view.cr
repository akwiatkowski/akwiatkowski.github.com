require "./abstract_view"

module GalleryView
  # lens showcase
  class LensView < AbstractView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @lens : String,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false,
      @fill_until : Int32 = 0
    )
      @photo_entities = photo_entities_with_tags(
        all_photos: all_published_photo_entities.select { |p| p.exif.lens_name == @lens },
        tags: @tags,
        include_headers: @include_headers,
        fill_until: fill_until,
      ).as(Array(PhotoEntity))

      @title = @lens
      @lens_sanitized = @lens.gsub(/\s/, "_").downcase.as(String)
      @url = "/gallery/lens/#{@lens_sanitized}"
    end
  end
end
