require "./abstract_view"

module GalleryView
  class FocalLengthView < AbstractView
    Log = ::Log.for(self)

    getter :focal_from, :focal_to

    def initialize(
      @blog : Tremolite::Blog,
      @focal_from : Float64,
      @focal_to : Float64,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false,
      @fill_until : Int32 = 0
    )
      @photo_entities = photo_entities_with_tags(
        all_photos: all_published_photo_entities.select { |p|
          p.exif.focal_length_35 && p.exif.focal_length_35.not_nil! >= @focal_from && p.exif.focal_length_35.not_nil! < @focal_to
        },
        tags: @tags,
        include_headers: @include_headers,
        fill_until: fill_until,
      ).as(Array(PhotoEntity))

      @title = "#{@focal_from.to_i}-#{@focal_to.to_i}mm"
      @url = "/gallery/focal_length/#{@focal_from.to_i}_#{@focal_to.to_i}"
    end
  end
end
