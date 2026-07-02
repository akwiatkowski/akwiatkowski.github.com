require "json"

module SpecialView
  # Minimal JSON payload for homepage post collection view
  # Contains only fields needed by homepage.js
  # URL: /jsons/homepage.json
  #
  # This is much smaller than payload.json because it excludes:
  # - coords (GPS route data - huge)
  # - image_url (full size image URL)
  # - category, year, month
  # - Full area entity arrays
  #
  # Each post includes top 4 photos (by points) for hero image selection.
  #
  class HomePageJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    TOP_PHOTOS_COUNT = 4

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/homepage.json",
    )
      @context = context
    end

    getter :url

    def output
      to_json
    end

    def add_to_sitemap?
      false
    end

    def to_json
      router = @context.router

      # Collect unique area slugs across all posts for lookup tables
      all_area_slugs = Hash(AreaType, Set(String)).new { |h, k| h[k] = Set(String).new }

      @context.posts.each do |post|
        AreaType.each do |area_type|
          post.area_slugs(area_type).each { |s| all_area_slugs[area_type] << s }
        end
      end

      JSON.build do |json|
        json.object do
          # Posts - minimal fields only
          json.field "posts" do
            json.array do
              @context.posts.each do |post|
                json.object do
                  json.field("url", post.url)
                  json.field("title", post.title)
                  json.field("subtitle", post.subtitle)
                  json.field("visible", post.visible?)
                  json.field("ready", post.ready?)
                  json.field("date", post.date)
                  json.field("time", post.time)
                  json.field("distance_km", post.distance)
                  json.field("time_spent", post.time_spent)
                  json.field("card_image_url", post.card_image_url)
                  json.field("card_image_url_avif", post.head_photo_entity.try(&.card_avif_src) || "")

                  # Tags as objects with slug, url, name
                  json.field "tags" do
                    json.raw post.tag_slugs.to_json
                  end

                  # Top photos for hero selection (sorted by points, highest first)
                  json.field "photos" do
                    json.array do
                      top_photos_for_post(post).each do |photo|
                        json.object do
                          json.field("src", photo.card_image_src)
                          json.field("src_avif", photo.card_avif_src)
                          json.field("alt", photo.desc)
                          json.field("points", photo.points)
                        end
                      end
                    end
                  end

                  # Area slugs for filtering (used by homepage.js and post_collection.js)
                  json.field "town_slugs" do
                    json.raw post.area_slugs(AreaType::Town).to_json
                  end
                  json.field "county_slugs" do
                    json.raw post.area_slugs(AreaType::County).to_json
                  end
                  json.field "voivodeship_slugs" do
                    json.raw post.area_slugs(AreaType::Voivodeship).to_json
                  end
                  json.field "meso_region_slugs" do
                    json.raw post.area_slugs(AreaType::MesoRegion).to_json
                  end
                  json.field "macro_region_slugs" do
                    json.raw post.area_slugs(AreaType::MacroRegion).to_json
                  end
                end
              end
            end
          end

          # Tags lookup table
          json.field "tags" do
            json.array do
              @context.tags.each do |tag|
                json.object do
                  json.field("slug", tag.slug)
                  json.field("url", router.tag_post_list_url(tag))
                  json.field("name", tag.name)
                end
              end
            end
          end

          # Area lookup tables (only areas that appear in posts)
          {
            "towns"         => AreaType::Town,
            "counties"      => AreaType::County,
            "voivodeships"  => AreaType::Voivodeship,
            "meso_regions"  => AreaType::MesoRegion,
            "macro_regions" => AreaType::MacroRegion,
          }.each do |field_name, area_type|
            json.field field_name do
              json.array do
                all_area_slugs[area_type].each do |slug|
                  area = @context.areas_of_type(area_type).find { |a| a.slug == slug }
                  next unless area

                  json.object do
                    json.field("slug", area.slug)
                    json.field("url", router.area_post_list_url(area))
                    json.field("name", area.name)
                  end
                end
              end
            end
          end
        end
      end
    end

    # Select top N photos from post, sorted by points (highest first)
    # Returns empty array if post has no photos
    private def top_photos_for_post(post : Tremolite::Post) : Array(PhotoEntity)
      photos = post.published_photo_entities
      return [] of PhotoEntity if photos.empty?

      photos.sort_by { |p| -p.points }.first(TOP_PHOTOS_COUNT)
    end
  end
end
