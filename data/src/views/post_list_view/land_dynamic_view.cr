require "./collection_dynamic_view"

module PostListView
  class LandDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @land : LandEntity)
      @filter_by = "land"
      @filter_value = @land.slug
      @url = @land.view_url
    end

    def title
      @land.name
    end

    def image_url
      return @land.image_url
    end
  end
end
