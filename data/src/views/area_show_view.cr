require "json"
require "./page_view"

# Show view for a specific area - displays area info, stats, and links
#
# URL pattern: /<type>/<slug>.html
# Example: /gminy/pobiedziska.html
class AreaShowView < PageView
  Log = ::Log.for(self)

  @posts : Array(Tremolite::Post)
  @area_photos : Array(PhotoEntity)
  @best_photo : PhotoEntity?
  @selector : AreaPhotoSelector

  def initialize(context : RenderContext, @area : AreaEntity)
    super(context: context, url: @area.show_url)
    @selector = context.photo_selector
    @posts = context.posts_for_area(@area)
    @area_photos = collect_area_photos
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

  def page_desc
    "#{@area.name} — #{@area.area_type.polish_name}. #{@posts.size} wypraw, #{@area_photos.size} zdjęć."
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
    data["area_data"] = generate_unified_json
    load_html("area/show", data)
  end

  private def generate_unified_json : String
    parent_info = get_parent_info
    voivodeship_info = get_voivodeship_info
    bbox = @area.bbox

    JSON.build do |json|
      json.object do
        # Config (was area-config)
        json.field("slug", @area.slug)
        json.field("name", @area.name)
        json.field("areaType", @area.area_type.polygon_dir.chomp("s"))
        json.field("areaTypeLabel", @area.area_type.polish_name)
        json.field("parentName", parent_info[:name])
        json.field("parentUrl", parent_info[:url])
        json.field("voivodeshipName", voivodeship_info[:name])
        json.field("voivodeshipUrl", voivodeship_info[:url])
        json.field("postListUrl", context.router.area_post_list_url(@area))
        json.field("galleryUrl", context.router.area_gallery_url(@area))
        json.field("bestPhotoUrl", @best_photo ? @best_photo.not_nil!.article_image_src : "")
        json.field("bestPhotoUrlAvif", @best_photo ? @best_photo.not_nil!.article_avif_src : "")
        json.field "bbox" do
          json.object do
            if bbox
              json.field("south", bbox.south)
              json.field("north", bbox.north)
              json.field("west", bbox.west)
              json.field("east", bbox.east)
            else
              json.field("south", 51.0)
              json.field("north", 52.0)
              json.field("west", 17.0)
              json.field("east", 18.0)
            end
          end
        end

        # Polygon (raw GeoJSON from pre-generated file)
        polygon_path = File.join("data/config/polygons", @area.area_type.polygon_dir, "#{@area.slug}.json")
        if File.exists?(polygon_path)
          json.field("polygon") { json.raw File.read(polygon_path) }
        end

        # Posts
        json.field "posts" do
          json.array do
            @posts.each do |post|
              json.object do
                json.field("url", post.url)
                json.field("slug", post.slug)
                json.field("title", post.title)
                json.field("date", post.date)
                json.field("distance", post.distance)
                json.field("time_spent", post.time_spent)
                json.field("card_image_url", post.head_photo_entity.try(&.grid_image_src) || "")
                json.field("card_image_url_avif", post.head_photo_entity.try(&.grid_avif_src) || "")
                json.field("tags") { json.raw post.tag_slugs.to_json }
                json.field("coords") { json.raw post.detailed_routes.to_json }
              end
            end
          end
        end

        # Photos
        json.field "photos" do
          json.array do
            @area_photos.each do |photo|
              json.object do
                json.field("desc", photo.desc)
                json.field("article_url", photo.article_image_src)
                json.field("article_url_avif", photo.article_avif_src)
                json.field("grid_url", photo.grid_image_src)
                json.field("grid_url_avif", photo.grid_avif_src)
                json.field("time", photo.time.to_s("%Y-%m-%d"))
                json.field("post_url", photo.post_url)
                json.field("points", photo.points)
              end
            end
          end
        end

        # Related areas
        json.field "related_areas" do
          json.array do
            find_related_areas.each do |ra|
              json.object do
                json.field("name", ra[:area].name)
                json.field("slug", ra[:area].slug)
                json.field("area_type", ra[:area].area_type.polish_name)
                json.field("show_url", ra[:area].show_url)
                json.field("best_photo_url", ra[:photo_url])
                json.field("best_photo_url_avif", ra[:photo_url_avif])
              end
            end
          end
        end
      end
    end
  end

  private def collect_area_photos : Array(PhotoEntity)
    if cache = context.photo_area_cache
      cache.top_photos_for_area(@area, 50)
    else
      [] of PhotoEntity
    end
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

  private def find_related_areas : Array(NamedTuple(area: AreaEntity, photo_url: String, photo_url_avif: String))
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
        score *= Random.new(@area.slug.hash.to_u64).rand(0.8..1.2)

        candidates << {score, area} if score > 0
      end
    end

    candidates.sort_by! { |s, _| -s }
    candidates.first(4).map do |_, area|
      photo = @selector.best_photo_for(area)
      photo_url = photo ? photo.grid_image_src : ""
      photo_url_avif = photo ? photo.grid_avif_src : ""
      {area: area, photo_url: photo_url, photo_url_avif: photo_url_avif}
    end
  end
end
