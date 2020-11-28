require "./gallery_abstract_view"

class GalleryFocalLengthView < GalleryAbstractView
  Log = ::Log.for(self)

  getter :focal_from, :focal_to

  def initialize(
    @blog : Tremolite::Blog,
    @focal_from : Float64,
    @focal_to : Float64,
    @tags : Array(String) = Array(String).new,
    @include_headers : Bool = false
  )

    @photo_entities = photo_entities_with_tags(@tags, @include_headers).select do |p|
      p.exif.focal_length_35 && p.exif.focal_length_35.not_nil! >= @focal_from && p.exif.focal_length_35.not_nil! < @focal_to
    end.as(Array(PhotoEntity))

    @title = "#{@focal_from.to_i}-#{@focal_to.to_i}mm"
    @url = "/gallery/focal_length/#{@focal_from.to_i}_#{@focal_to.to_i}"
  end
end
