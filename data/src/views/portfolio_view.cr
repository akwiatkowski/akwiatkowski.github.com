require "json"
require "./page_view"

# Portfolio page - showcases best photography work
#
# URL: /portfolio.html
#
# Features:
# - Tiered photo selection: portfolio tag > best tag > good tag
# - Stats computed from posts (distance, hours, photo count, towns)
# - JSON inlined in template for Preact rendering
# - Full-viewport hero, masonry grid with ambilight, lightbox with EXIF
class PortfolioView < PageView
  Log = ::Log.for(self)

  MAX_PHOTOS = 70

  @photos : Array(PhotoEntity)
  @hero_photo : PhotoEntity?

  def initialize(context : RenderContext)
    super(context: context, url: "/portfolio.html")
    @photos = select_photos
    @hero_photo = @photos.first?
  end

  def additional_bundles : Array(String)
    ["react-runtime"]
  end

  def page_css : Array(String)
    ["portfolio", "photo-lightbox"]
  end

  def page_js : String?
    "/js/self/portfolio.js"
  end

  def add_to_sitemap?
    true
  end

  def title
    "Portfolio"
  end

  def page_desc
    "Portfolio fotograficzne. Rowerem i pieszo przez Polskę."
  end

  def image_url
    @hero_photo ? @hero_photo.not_nil!.full_image_src : ""
  end

  # Skip PageView header — portfolio has its own full-viewport hero
  def content
    inner_html
  end

  def inner_html
    data = Hash(String, String).new
    data["portfolio_data"] = generate_json
    load_html("portfolio/portfolio", data)
  end

  private def select_photos : Array(PhotoEntity)
    all_posts = context.posts.select(&.ready?)
    seen = Set(String).new
    result = [] of PhotoEntity

    # Tier 1: portfolio-tagged photos
    all_posts.each do |post|
      post.published_photo_entities.each do |photo|
        if photo.has_tag?("portfolio") && !seen.includes?(photo.full_image_src)
          result << photo
          seen << photo.full_image_src
        end
      end
    end

    # Tier 2: best-tagged photos not already included
    all_posts.each do |post|
      post.published_photo_entities.each do |photo|
        if photo.has_tag?("best") && !seen.includes?(photo.full_image_src)
          result << photo
          seen << photo.full_image_src
        end
      end
    end

    # Tier 3: good-tagged photos if needed
    if result.size < MAX_PHOTOS
      all_posts.each do |post|
        post.published_photo_entities.each do |photo|
          if photo.has_tag?("good") && !seen.includes?(photo.full_image_src)
            result << photo
            seen << photo.full_image_src
          end
        end
      end
    end

    # Sort by points descending, then limit
    result.sort_by! { |p| -p.points }
    result.first(MAX_PHOTOS)
  end

  private def generate_json : String
    posts = context.posts.select(&.ready?)

    bicycle_distance = posts.select(&.bicycle?).compact_map(&.distance).sum.to_i
    hike_distance = posts.select(&.hike?).compact_map(&.distance).sum.to_i
    total_hours = posts.compact_map(&.time_spent).sum.to_i
    post_count = posts.size
    photo_count = posts.sum { |p| p.published_photo_entities.size }
    years = context.years
    years_str = years.size > 0 ? "#{years.min}-#{years.max}" : ""
    towns_visited = context.visited_town_slugs_selfpropelled.size

    JSON.build do |json|
      json.object do
        # Hero photo
        if hero = @hero_photo
          json.field "hero_photo" do
            json.object do
              json.field("src", hero.article_image_src)
              json.field("full_src", hero.full_image_src)
              json.field("alt", hero.desc)
            end
          end
        end

        # Stats
        json.field "stats" do
          json.object do
            json.field("bicycle_distance_km", bicycle_distance)
            json.field("hike_distance_km", hike_distance)
            json.field("total_hours", total_hours)
            json.field("post_count", post_count)
            json.field("photo_count", photo_count)
            json.field("years_active", years_str)
            json.field("towns_visited", towns_visited)
          end
        end

        # Photos
        json.field "photos" do
          json.array do
            @photos.each do |photo|
              json.object do
                json.field("src", photo.article_image_src)
                json.field("full_src", photo.full_image_src)
                json.field("alt", photo.desc)
                json.field("post_url", photo.post_url)
                json.field("post_title", photo.post_title)
                json.field("points", photo.points)
                json.field("tags") { json.raw photo.tags.to_json }

                # EXIF data
                exif = photo.exif
                json.field "exif" do
                  json.object do
                    camera = exif.camera_name
                    json.field("camera", camera.to_s.strip.empty? ? nil : camera)
                    lens = exif.lens_name
                    json.field("lens", lens.to_s.strip.empty? ? nil : lens)
                    fl = exif.focal_length
                    json.field("focal", fl ? "#{fl.to_i}mm" : nil)
                    ap = exif.aperture
                    json.field("aperture", ap && ap > 0.1 ? "f/#{ap}" : nil)
                    json.field("exposure", exif.exposure_string)
                    json.field("iso", exif.iso)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
