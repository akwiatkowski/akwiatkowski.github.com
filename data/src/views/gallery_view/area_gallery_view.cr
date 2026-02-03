require "./abstract_view"

module GalleryView
  # Gallery view for a specific area - shows photos within the area's bounding box
  #
  # URL pattern: /galeria/<type>/<slug>.html
  # Example: /galeria/gminy/pobiedziska.html
  class AreaGalleryView < AbstractView
    Log = ::Log.for(self)

    @photo_entities : Array(PhotoEntity)

    def initialize(context : RenderContext, @area : AreaEntity)
      @title = "Galeria: #{@area.name}"
      @url = @area.gallery_url
      super(context: context, url: @url)

      # Select photos using bbox
      selector = AreaPhotoSelector.new(all_published_photo_entities)
      @photo_entities = selector.top_photos_for(@area, limit: 200)
    end

    def subtitle
      type_name = @area.area_type.polish_name
      if @photo_entities.size > 0
        "#{type_name} - #{@photo_entities.size} zdjęć"
      else
        "#{type_name} - brak zdjęć w tym obszarze"
      end
    end
  end
end
