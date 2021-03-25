require "json"

module SpecialView
  class PayloadJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
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
              @blog.post_collection.posts.each do |post|
                json.object do
                  json.field("url", post.url)
                  json.field("slug", post.slug)
                  json.field("title", post.title)
                  json.field("category", post.category)
                  json.field("date", post.date)
                  json.field("distace", post.distance)
                  json.field("time_spent", post.time_spent)
                  # need to separate towns from voivodeships
                  # json.field("towns_count", post.towns.size)
                  json.field("year", post.time.year)
                  json.field("month", post.time.month)
                  json.field("header-ext-img", post.image_url)
                  json.field("image_url", post.image_url)
                  json.field("small_image_url", post.small_image_url)

                  json.field "coords" do
                    json.raw post.detailed_routes.to_json
                  end
                  json.field "tags" do
                    json.raw post.tags.to_json
                  end
                  json.field "towns" do
                    json.raw post.towns.to_json
                  end
                  json.field "lands" do
                    json.raw post.lands.to_json
                  end
                end
              end
            end
          end

          # towns
          json.field "towns" do
            json.array do
              @blog.data_manager.not_nil!.towns.not_nil!.each do |town|
                json.object do
                  json.field("url", town.list_url)
                  json.field("slug", town.slug)
                  json.field("name", town.name)
                  json.field("header-ext-img", town.image_url)
                  json.field("image_url", town.image_url)
                  json.field("voivodeship", town.voivodeship)
                  json.field("inside", town.voivodeship)
                end
              end
            end
          end

          # voivodeships
          json.field "voivodeships" do
            json.array do
              @blog.data_manager.not_nil!.voivodeships.not_nil!.each do |voivodeship|
                json.object do
                  json.field("url", voivodeship.list_url)
                  json.field("slug", voivodeship.slug)
                  json.field("name", voivodeship.name)
                  json.field("header-ext-img", voivodeship.image_url)
                  json.field("image_url", voivodeship.image_url)
                end
              end
            end
          end

          # tags
          json.field "tags" do
            json.array do
              @blog.data_manager.not_nil!.tags.not_nil!.each do |tag|
                json.object do
                  json.field("url", tag.list_url)
                  json.field("slug", tag.slug)
                  json.field("name", tag.name)
                  json.field("header-ext-img", tag.image_url)
                  json.field("image_url", tag.image_url)
                end
              end
            end
          end

          # lands
          json.field "lands" do
            json.array do
              @blog.data_manager.not_nil!.lands.not_nil!.each do |land|
                json.object do
                  json.field("url", land.list_url)
                  json.field("slug", land.slug)
                  json.field("name", land.name)
                  json.field("header-ext-img", land.image_url)
                  json.field("image_url", land.image_url)
                  json.field("country", land.country)
                  json.field("visited", land.visited.to_s) if land.visited
                  json.field("type", land.type)
                  json.field("train_time_poznan", land.train_time_poznan)
                end
              end
            end
          end

          # land_types
          json.field "land_types" do
            json.array do
              @blog.data_manager.not_nil!.land_types.not_nil!.each do |land_type|
                json.object do
                  json.field("slug", land_type.slug)
                  json.field("name", land_type.name)
                end
              end
            end
          end

          # END
        end
      end

      return result
    end
  end
end
