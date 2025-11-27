require "./collection_dynamic_view"

module PostListView
  class TownDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @town : TownEntity)
      @filter_by = "town"
      @filter_value = @town.slug
      @url = @town.view_url
    end

    def title
      @town.name
    end

    def image_url
      return @town.image_url
    end
  end
end
