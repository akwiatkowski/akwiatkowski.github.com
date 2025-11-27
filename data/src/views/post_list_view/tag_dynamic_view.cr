require "./collection_dynamic_view"

module PostListView
  class TagDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @tag : TagEntity)
      @filter_by = "tag"
      @filter_value = @tag.slug
      @url = @tag.view_url
    end

    def title
      @tag.name
    end

    def image_url
      return @tag.image_url
    end
  end
end
