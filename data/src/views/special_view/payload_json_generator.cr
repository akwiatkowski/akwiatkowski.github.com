require "json"

module SpecialView
  class PayloadJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/payload.json",
    )
      @context = context
    end

    getter :url

    def output
      to_json
    end

    # a bit internal
    def add_to_sitemap?
      return false
    end

    def to_json
      result = JSON.build do |json|
        json.object do
          # posts
          json.field "posts" do
            json.array do
              @context.posts.each do |post|
                json.object do
                  json.field("url", post.url)
                  json.field("slug", post.slug)
                  json.field("title", post.title)
                  json.field("subtitle", post.subtitle)
                  json.field("visible", post.visible?)
                  json.field("ready", post.ready?)
                  json.field("category", post.category)
                  json.field("date", post.date)
                  json.field("time", post.time)
                  json.field("distace", post.distance)
                  json.field("time_spent", post.time_spent)
                  # need to separate towns from voivodeships
                  # json.field("towns_count", post.towns.size)
                  json.field("year", post.time.year)
                  json.field("month", post.time.month)
                  json.field("image_url", post.image_url)
                  json.field("card_image_url", post.card_image_url)

                  json.field "coords" do
                    json.raw post.detailed_routes.to_json
                  end
                  json.field "tags" do
                    json.raw post.tags.to_json
                  end
                  # New area system - use area_slugs instead of old towns/lands
                  json.field "towns" do
                    json.raw post.area_slugs(AreaType::Town).to_json
                  end
                  json.field "counties" do
                    json.raw post.area_slugs(AreaType::County).to_json
                  end
                  json.field "voivodeships" do
                    json.raw post.area_slugs(AreaType::Voivodeship).to_json
                  end
                  json.field "meso_regions" do
                    json.raw post.area_slugs(AreaType::MesoRegion).to_json
                  end
                  json.field "macro_regions" do
                    json.raw post.area_slugs(AreaType::MacroRegion).to_json
                  end
                end
              end
            end
          end

          # tags (not an area type, keep as is)
          json.field "tags" do
            json.array do
              @context.tags.each do |tag|
                json.object do
                  json.field("url", tag.view_url)
                  json.field("slug", tag.slug)
                  json.field("name", tag.name)
                  json.field("header-ext-img", tag.image_url)
                  json.field("image_url", tag.image_url)
                end
              end
            end
          end

          # Areas - using new unified AreaEntity system
          render_areas(json, "towns", AreaType::Town)
          render_areas(json, "counties", AreaType::County)
          render_areas(json, "voivodeships", AreaType::Voivodeship)
          render_areas(json, "meso_regions", AreaType::MesoRegion)
          render_areas(json, "macro_regions", AreaType::MacroRegion)

          # END
        end
      end

      return result
    end

    private def render_areas(json : JSON::Builder, field_name : String, area_type : AreaType)
      json.field field_name do
        json.array do
          @context.areas_of_type(area_type).each do |area|
            json.object do
              json.field("slug", area.slug)
              json.field("name", area.name)
              json.field("code", area.code)
              json.field("voivodeship", area.voivodeship_slug)
              json.field("show_url", area.show_url)
              json.field("post_list_url", area.post_list_url)
              json.field("gallery_url", area.gallery_url)
            end
          end
        end
      end
    end
  end
end
