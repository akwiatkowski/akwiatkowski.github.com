require "./collection_dynamic_view"

module PostListView
  # DEPRECATED: Use AreaPostListView with AreaEntity instead
  # This view will be removed once area entity migration is complete
  class LandDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @land : LandEntity)
      super(
        context: context,
        url: @land.view_url,
        filter_by: "land",
        filter_value: @land.slug
      )
    end

    def title
      @land.name
    end

    def image_url
      return @land.image_url
    end
  end
end
