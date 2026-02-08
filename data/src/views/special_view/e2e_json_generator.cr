require "json"

module SpecialView
  # Minimal JSON for E2E tests only — not a public endpoint
  # Contains just enough data for smoke, post, gallery, and map tests
  class E2eJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/jsons/e2e.json",
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

      JSON.build do |json|
        json.object do
          json.field "posts" do
            json.array do
              @context.posts.each do |post|
                json.object do
                  json.field("url", post.url)
                  json.field("ready", post.ready?)
                  json.field("photos_count", post.published_photo_entities.size)
                  json.field("has_route", !post.detailed_routes.empty?)
                  json.field "tags" do
                    json.raw post.tags.to_json
                  end
                  json.field "voivodeships" do
                    json.raw post.area_slugs(AreaType::Voivodeship).to_json
                  end
                end
              end
            end
          end

          json.field "tags" do
            json.array do
              @context.tags.each do |tag|
                json.object do
                  json.field("url", router.tag_link_url(tag))
                  json.field("slug", tag.slug)
                end
              end
            end
          end

          json.field "voivodeships" do
            json.array do
              @context.areas_of_type(AreaType::Voivodeship).each do |v|
                json.object do
                  json.field("slug", v.slug)
                  json.field("show_url", router.area_show_url(v))
                  json.field("gallery_url", router.area_gallery_url(v))
                end
              end
            end
          end
        end
      end
    end
  end
end
