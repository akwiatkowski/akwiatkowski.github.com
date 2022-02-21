require "./abstract_view"

module GalleryView
  class ExposureView < AbstractView
    LIMIT_FOR_EXPOSURE = 50

    Log = ::Log.for(self)

    getter :exposure_from, :exposure_to

    def initialize(
      @blog : Tremolite::Blog,
      @exposure_from : Float64,
      @exposure_to : Float64,
      @tags : Array(String) = Array(String).new,
      @include_headers : Bool = false,
      @fill_until : Int32 = 0,
      @limit : Int32 = LIMIT_FOR_EXPOSURE
    )
      @photo_entities = photo_entities_with_tags(
        all_photos: all_published_photo_entities.select { |p|
          p.exif.exposure && p.exif.exposure.not_nil! >= @exposure_from && p.exif.exposure.not_nil! < @exposure_to
        },
        tags: @tags,
        include_headers: @include_headers,
        fill_until: @fill_until,
        limit: @limit
      ).as(Array(PhotoEntity))

      @title = "Naświetlenie #{exposure_to_human(@exposure_from)} - #{exposure_to_human(@exposure_to)}"
      @url = "/gallery/iso/#{@exposure_from.to_s}"
      @reverse = true
    end

    def exposure_to_human(exposure : Float64)
      if exposure > 1.0
        return "#{exposure}s"
      elsif exposure > 0.0
        return "1 / #{1.0 / exposure} s"
      else
        return "-"
      end
    end
  end
end
