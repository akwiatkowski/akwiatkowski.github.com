require "./abstract_view"

module GalleryView
  class TagView < AbstractView
    Log = ::Log.for(self)

    getter :tag_pl

    @tag : String
    @tag_pl : String
    @title : String
    @subtitle : String

    def initialize(@blog : Tremolite::Blog, @photo_tag : PhotoTagEntity)
      # trick used in GalleryAbstractView
      @tag = @photo_tag.slug
      @tag_pl = @photo_tag.slug_pl
      @tags = [@tag].as(Array(String))
      @photo_entities = photo_entities_with_tags(tags: @tags).as(Array(PhotoEntity))
      @title = @photo_tag.title.to_s
      @subtitle = @photo_tag.subtitle.to_s
      @url = @photo_tag.view_url
      @reverse = true
    end
  end
end
