require "./abstract_view"

module GalleryView
  class IsoView < AbstractView
    LIMIT_FOR_ISO = 50

    Log = ::Log.for(self)

    getter :iso_from, :iso_to

    def initialize(
      @blog : Tremolite::Blog,
      @iso_from : Int32,
      @iso_to : Int32,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false,
      @fill_until : Int32 = 0,
      @limit : Int32 = LIMIT_FOR_ISO,
    )
      @photo_entities = photo_entities_with_tags(
        all_photos: all_published_photo_entities.select { |p|
          p.exif.iso && p.exif.iso.not_nil! >= @iso_from && p.exif.iso.not_nil! < @iso_to
        },
        tags: @tags,
        include_headers: @include_headers,
        fill_until: fill_until,
        limit: limit
      ).as(Array(PhotoEntity))

      @title = "ISO #{@iso_from}"
      @url = "/gallery/iso/#{@iso_from}"
      @reverse = true
    end
  end
end
