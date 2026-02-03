require "./abstract_view"

module GalleryView
  class TagView < AbstractView
    Log = ::Log.for(self)

    getter :tag_pl

    @tag : String
    @tag_pl : String
    @title : String
    @subtitle : String

    def initialize(context : RenderContext, @photo_tag : PhotoTagEntity)
      # trick used in GalleryAbstractView
      @tag = @photo_tag.slug
      @tag_pl = @photo_tag.slug_pl
      @tags = [@tag].as(Array(String))
      @title = @photo_tag.title.to_s
      @subtitle = @photo_tag.subtitle.to_s
      @url = @photo_tag.view_url
      @reverse = true
      super(context: context, url: @url)

      @photo_entities = photo_entities_with_tags(tags: @tags).as(Array(PhotoEntity))
    end
  end
end
