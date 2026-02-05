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
      all_town_slugs = Set(String).new
      all_meso_region_slugs = Set(String).new

      @context.posts.each do |post|
        post.area_slugs(AreaType::Town).each { |s| all_town_slugs << s }
        post.area_slugs(AreaType::MesoRegion).each { |s| all_meso_region_slugs << s }
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

                  # Tags as objects with slug, url, name
                  json.field "tags" do
                    json.raw post.tags.to_json
                  end

                  # Top photos for hero selection (sorted by points, highest first)
                  json.field "photos" do
                    json.array do
                      top_photos_for_post(post).each do |photo|
                        json.object do
                          json.field("src", photo.card_image_src)
                          json.field("alt", photo.desc)
                          json.field("points", photo.points)
                        end
                      end
                    end
                  end

                  # Area slugs for filtering (just slugs, lookup via towns/meso_regions tables)
                  json.field "town_slugs" do
                    json.raw post.area_slugs(AreaType::Town).to_json
                  end
                  json.field "meso_region_slugs" do
                    json.raw post.area_slugs(AreaType::MesoRegion).to_json
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

          # Towns lookup table (only towns that appear in posts)
          json.field "towns" do
            json.array do
              all_town_slugs.each do |slug|
                town = @context.areas_of_type(AreaType::Town).find { |a| a.slug == slug }
                next unless town

                json.object do
                  json.field("slug", town.slug)
                  json.field("url", router.area_post_list_url(town))
                  json.field("name", town.name)
                end
              end
            end
          end

          # Meso regions lookup table (only regions that appear in posts)
          json.field "meso_regions" do
            json.array do
              all_meso_region_slugs.each do |slug|
                region = @context.areas_of_type(AreaType::MesoRegion).find { |a| a.slug == slug }
                next unless region

                json.object do
                  json.field("slug", region.slug)
                  json.field("url", router.area_post_list_url(region))
                  json.field("name", region.name)
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
