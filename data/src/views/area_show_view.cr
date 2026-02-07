require "json"
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
  @selector : AreaPhotoSelector

  def initialize(context : RenderContext, @area : AreaEntity)
    super(context: context, url: @area.show_url)
    @selector = context.photo_selector
    @posts = context.posts_for_area(@area)
    @photo_count = @selector.photos_in_area(@area).size
    @best_photo = @selector.best_photo_for(@area)
  end

  # Area show page needs leaflet for maps and react for dynamic UI
  def additional_bundles : Array(String)
    ["leaflet", "react-runtime"]
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

  # Skip PageView header (intro-header) — area page has its own full-viewport hero
  def content
    inner_html
  end

  def inner_html
    data = Hash(String, String).new

    # Basic area info
    data["slug"] = @area.slug
    data["name"] = @area.name
    data["area_type"] = @area.area_type.polygon_dir.chomp("s") # "town", "county", etc.
    data["area_type_label"] = @area.area_type.polish_name
    data["area_field"] = @area.area_type.payload_field

    # Parent area info
    parent_info = get_parent_info
    data["parent_name"] = parent_info[:name]
    data["parent_url"] = parent_info[:url]

    # Voivodeship info
    voivodeship_info = get_voivodeship_info
    data["voivodeship_name"] = voivodeship_info[:name]
    data["voivodeship_url"] = voivodeship_info[:url]

    # URLs for navigation links
    data["post_list_url"] = context.router.area_post_list_url(@area)
    data["gallery_url"] = context.router.area_gallery_url(@area)

    # Best photo for hero background
    data["best_photo_url"] = @best_photo ? @best_photo.not_nil!.article_image_src : ""

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

    # Inline area data (posts + photos) as JSON for instant page load
    data["area_data_json"] = generate_area_data_json

    load_html("area/show", data)
  end

  private def generate_area_data_json : String
    photos = collect_area_photos

    JSON.build do |json|
      json.object do
        json.field "posts" do
          json.array do
            @posts.each do |post|
              json.object do
                json.field("url", post.url)
                json.field("slug", post.slug)
                json.field("title", post.title)
                json.field("date", post.date)
                json.field("distace", post.distance)
                json.field("time_spent", post.time_spent)
                json.field("card_image_url", post.card_image_url)
                json.field("tags") { json.raw post.tags.to_json }
                json.field("coords") { json.raw post.detailed_routes.to_json }
              end
            end
          end
        end
        json.field "photos" do
          json.array do
            photos.each do |photo|
              json.object do
                json.field("desc", photo.desc)
                json.field("article_url", photo.article_image_src)
                json.field("time", photo.time.to_s("%Y-%m-%d"))
                json.field("post_url", photo.post_url)
                json.field("points", photo.points)
              end
            end
          end
        end
        json.field "related_areas" do
          json.array do
            find_related_areas.each do |ra|
              json.object do
                json.field("name", ra[:area].name)
                json.field("slug", ra[:area].slug)
                json.field("area_type", ra[:area].area_type.polish_name)
                json.field("show_url", ra[:area].show_url)
                json.field("best_photo_url", ra[:photo_url])
              end
            end
          end
        end
      end
    end
  end

  private def collect_area_photos : Array(PhotoEntity)
    @posts.flat_map { |p| p.published_photo_entities }
      .select { |p| p.tags.size > 0 }
      .sort_by { |p| -p.points }
      .first(50)
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

  private def find_related_areas : Array(NamedTuple(area: AreaEntity, photo_url: String))
    my_post_slugs = @posts.map(&.slug).to_set

    candidates = [] of {Float64, AreaEntity}

    [AreaType::Town, AreaType::MesoRegion].each do |type|
      context.areas_with_posts(type).each do |area|
        next if area.slug == @area.slug && area.area_type == @area.area_type

        score = 0.0

        # BBox overlap scoring
        if my_bbox = @area.bbox
          if other_bbox = area.bbox
            overlap = my_bbox.intersection_area(other_bbox)
            my_area_size = my_bbox.area
            score += (overlap / my_area_size) * 10.0 if my_area_size > 0
          end
        end

        # Shared posts bonus
        other_posts = context.posts_for_area(area)
        shared = other_posts.count { |p| my_post_slugs.includes?(p.slug) }
        score += shared * 2.0

        # Same voivodeship bonus
        if @area.voivodeship_slug && @area.voivodeship_slug == area.voivodeship_slug
          score += 1.0
        end

        # Randomness for variety
        score *= rand(0.8..1.2)

        candidates << {score, area} if score > 0
      end
    end

    candidates.sort_by! { |s, _| -s }
    candidates.first(4).map do |_, area|
      photo = @selector.best_photo_for(area)
      photo_url = photo ? photo.article_image_src : ""
      {area: area, photo_url: photo_url}
    end
  end
end
