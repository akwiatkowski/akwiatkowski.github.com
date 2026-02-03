require "./collection_dynamic_view"

module PostListView
  # DEPRECATED: Use AreaPostListView with AreaEntity instead
  # This view will be removed once area entity migration is complete
  class VoivodeshipDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @voivodeship : VoivodeshipEntity)
      # TODO: use town for towns and voivodeship ?
      super(
        context: context,
        url: @voivodeship.view_url,
        filter_by: "town",
        filter_value: @voivodeship.slug
      )
    end

    def title
      @voivodeship.name
    end

    def image_url
      return @voivodeship.image_url
    end
  end
end
