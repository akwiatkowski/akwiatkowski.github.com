require "./collection_dynamic_view"

module PostListView
  # Displays a list of posts for a specific area (town, county, voivodeship, etc.)
  # Uses the unified AreaEntity system
  #
  # URL pattern: /wpisy_dla/<type>/<slug>.html
  # Example: /wpisy_dla/gminy/pobiedziska.html
  class AreaPostListView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @area : AreaEntity)
      super(
        context: context,
        url: @area.post_list_url,
        filter_by: @area.area_type.url_type,
        filter_value: @area.slug
      )
    end

    def title
      "Wpisy dla: #{@area.name}"
    end

    def image_url
      # Get best photo for area using AreaPhotoSelector
      selector = AreaPhotoSelector.new(all_published_photos)
      best = selector.best_photo_for(@area)
      best ? best.full_image_src : ""
    end

    private def all_published_photos : Array(PhotoEntity)
      context.posts.flat_map { |p| p.published_photo_entities }
    end
  end
end
