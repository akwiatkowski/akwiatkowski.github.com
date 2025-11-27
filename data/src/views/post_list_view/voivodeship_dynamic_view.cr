require "./collection_dynamic_view"

module PostListView
  class VoivodeshipDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @voivodeship : VoivodeshipEntity)
      @filter_by = "town" # TODO: use town for towns and voivodeship ?
      @filter_value = @voivodeship.slug
      @url = @voivodeship.view_url
    end

    def title
      @voivodeship.name
    end

    def image_url
      return @voivodeship.image_url
    end
  end
end
