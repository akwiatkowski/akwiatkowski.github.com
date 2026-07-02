require "./collection_dynamic_view"

module PostListView
  # Displays a list of posts for an external (foreign) area
  #
  # URL pattern: /wpisy-dla/zagranica/<slug>.html
  # Example: /wpisy-dla/zagranica/praga.html
  class ExternalAreaPostListView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @area : AreaEntity)
      super(
        context: context,
        url: @area.post_list_url,
        filter_by: "foreign",
        filter_value: @area.slug
      )
    end

    def title
      "Wpisy dla: #{@area.name}"
    end

    def image_url
      # Get first photo from posts with this foreign area
      posts = context.posts_for_external_area(@area)
      return "" if posts.empty?

      posts.first.head_photo_entity.try(&.full_image_src) || ""
    end
  end
end
