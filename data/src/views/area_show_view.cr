require "./page_view"

# Show view for a specific area - displays area info, stats, and links
#
# URL pattern: /<type>/<slug>.html
# Example: /gminy/pobiedziska.html
class AreaShowView < PageView
  Log = ::Log.for(self)

  @posts : Array(Tremolite::Post)
  @photo_count : Int32
  @best_photo : PhotoEntity?

  def initialize(context : RenderContext, @area : AreaEntity)
    super(context: context, url: @area.show_url)
    @posts = context.posts_for_area(@area)
    @photo_count = count_photos_in_area
    @best_photo = find_best_photo
  end

  def add_to_sitemap?
    true
  end

  def title
    @area.name
  end

  def subtitle
    @area.area_type.polish_name
  end

  def image_url
    @best_photo ? @best_photo.not_nil!.full_image_src : ""
  end

  def inner_html
    data = Hash(String, String).new

    # Basic area info
    data["slug"] = @area.slug
    data["name"] = @area.name
    data["area_type"] = @area.area_type.polygon_dir.chomp("s") # "town", "county", etc.
    data["area_type_label"] = @area.area_type.polish_name.capitalize
    data["area_field"] = @area.area_type.payload_field

    # Parent area info
    parent_info = get_parent_info
    data["parent_name"] = parent_info[:name]
    data["parent_url"] = parent_info[:url]

    # Voivodeship info
    voivodeship_info = get_voivodeship_info
    data["voivodeship_name"] = voivodeship_info[:name]
    data["voivodeship_url"] = voivodeship_info[:url]

    # Bounding box
    if bbox = @area.bbox
      data["bbox_south"] = bbox.south.to_s
      data["bbox_north"] = bbox.north.to_s
      data["bbox_west"] = bbox.west.to_s
      data["bbox_east"] = bbox.east.to_s
    else
      # Default to Poland's approximate center if no bbox
      data["bbox_south"] = "51.0"
      data["bbox_north"] = "52.0"
      data["bbox_west"] = "17.0"
      data["bbox_east"] = "18.0"
    end

    load_html("area/show", data)
  end

  private def get_parent_info : NamedTuple(name: String, url: String)
    case @area.area_type
    when AreaType::Town
      # For towns, parent is the voivodeship (we don't have county info readily available)
      if voivodeship_slug = @area.voivodeship_slug
        if voivodeship = context.area_data_loader.area_by_slug(AreaType::Voivodeship, voivodeship_slug)
          return {name: voivodeship.name, url: voivodeship.show_url}
        end
      end
    when AreaType::County
      # For counties, parent is voivodeship
      if voivodeship_slug = @area.voivodeship_slug
        if voivodeship = context.area_data_loader.area_by_slug(AreaType::Voivodeship, voivodeship_slug)
          return {name: voivodeship.name, url: voivodeship.show_url}
        end
      end
    when AreaType::Voivodeship
      # Voivodeships don't have a parent, use Poland
      return {name: "Polska", url: "/"}
    when AreaType::MesoRegion, AreaType::MacroRegion
      # Regions don't have a direct parent in our model
      return {name: "", url: ""}
    end

    {name: "", url: ""}
  end

  private def get_voivodeship_info : NamedTuple(name: String, url: String)
    # For voivodeships themselves, return empty
    return {name: "", url: ""} if @area.area_type == AreaType::Voivodeship

    if voivodeship_slug = @area.voivodeship_slug
      if voivodeship = context.area_data_loader.area_by_slug(AreaType::Voivodeship, voivodeship_slug)
        return {name: voivodeship.name, url: voivodeship.show_url}
      end
    end

    {name: "", url: ""}
  end

  private def count_photos_in_area : Int32
    all_photos = context.posts.flat_map { |p| p.published_photo_entities }
    selector = AreaPhotoSelector.new(all_photos)
    selector.photos_in_area(@area).size
  end

  private def find_best_photo : PhotoEntity?
    all_photos = context.posts.flat_map { |p| p.published_photo_entities }
    selector = AreaPhotoSelector.new(all_photos)
    selector.best_photo_for(@area)
  end
end
