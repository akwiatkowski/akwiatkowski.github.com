require "./collection_dynamic_view"

module PostListView
  class TagDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @tag : TagEntity)
      super(
        context: context,
        url: @tag.view_url,
        filter_by: "tag",
        filter_value: @tag.slug
      )
    end

    def title
      @tag.name
    end

    def image_url
      return @tag.image_url
    end
  end
end
