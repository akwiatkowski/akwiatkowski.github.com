require "./abstract_view"

module GalleryView
  class TagView < AbstractView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @tag : String)
      # trick used in GalleryAbstractView
      @tags = [@tag].as(Array(String))
      @photo_entities = photo_entities_with_tags(@tags).as(Array(PhotoEntity))
      @title = data_manager["gallery.#{@tag}.title"].as(String)
      @url = "/gallery/#{@tag}"
    end
  end
end
