require "./gallery_abstract_view"

# lens showcase
class GalleryLensView < GalleryAbstractView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @lens : String,
    @tags : Array(String) = Array(String).new,
    @include_headers : Bool = false
  )
    @photo_entities = photo_entities_with_tags(@tags, @include_headers).select { |p|
      p.exif.lens_name == @lens
    }.as(Array(PhotoEntity))

    @title = @lens
    @lens_sanitized = @lens.gsub(/\s/, "_").downcase.as(String)
    @url = "/gallery/lens/#{@lens_sanitized}"
  end
end
