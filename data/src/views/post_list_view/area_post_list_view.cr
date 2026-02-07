require "./collection_dynamic_view"

module PostListView
  # Displays a list of posts for a specific area (town, county, voivodeship, etc.)
  # Uses the unified AreaEntity system
  #
  # URL pattern: /wpisy-dla/<type>/<slug>.html
  # Example: /wpisy-dla/gminy/pobiedziska.html
  class AreaPostListView < CollectionDynamicView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @area : AreaEntity)
      @filter_by = area_type_to_filter(@area.area_type)
      @filter_value = @area.slug
      super(
        context: context,
        url: @area.post_list_url,
        filter_by: @filter_by,
        filter_value: @filter_value
      )
    end

    # Map AreaType to filter_by string expected by JavaScript
    private def area_type_to_filter(type : AreaType) : String
      case type
      when AreaType::Town        then "town"
      when AreaType::County      then "county"
      when AreaType::Voivodeship then "voivodeship"
      when AreaType::MesoRegion  then "meso_region"
      when AreaType::MacroRegion then "macro_region"
      else "town"
      end
    end

    def title
      "Wpisy dla: #{@area.name}"
    end

    def image_url
      best = context.photo_selector.best_photo_for(@area)
      best ? best.full_image_src : ""
    end
  end
end
