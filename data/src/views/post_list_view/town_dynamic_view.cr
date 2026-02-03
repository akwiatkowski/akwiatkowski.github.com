require "./collection_dynamic_view"

module PostListView
  class TownDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @town : TownEntity)
      super(
        context: context,
        url: @town.view_url,
        filter_by: "town",
        filter_value: @town.slug
      )
    end

    def title
      @town.name
    end

    def image_url
      return @town.image_url
    end
  end
end
