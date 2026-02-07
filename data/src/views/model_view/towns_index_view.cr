require "json"
require "../page_view"

module ModelView
  class TownsIndexView < PageView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("towns")
      @title = meta[:title].as(String)
      @subtitle = meta[:subtitle].as(String)

      # Hero image: last finished post's card photo
      last_post = context.ready_posts.sort_by(&.time).last?
      @image_url = last_post.try(&.card_image_url) || meta[:backgrounds].as(String)

      @towns_with_posts = context.areas_with_posts(AreaType::Town).uniq(&.slug).as(Array(AreaEntity))
      @voivodeships = context.areas_of_type(AreaType::Voivodeship).as(Array(AreaEntity))
      # Own selector so unique photo tracking doesn't affect other views
      @selector = AreaPhotoSelector.new(context.posts.flat_map { |p| p.published_photo_entities })
    end

    def additional_bundles : Array(String)
      ["react-runtime"]
    end

    def page_js : String?
      "/js/self/towns_index.js"
    end

    def add_to_sitemap?
      true
    end

    getter :image_url, :title, :subtitle

    # Skip PageView header — page has its own hero
    def content
      inner_html
    end

    def inner_html
      data = Hash(String, String).new
      data["image_url"] = @image_url
      data["title"] = @title
      data["subtitle"] = @subtitle
      data["towns_data_json"] = generate_towns_json
      load_html("towns/index", data)
    end

    private def generate_towns_json : String
      JSON.build do |json|
        json.object do
          json.field "voivodeships" do
            json.array do
              @voivodeships.sort_by(&.name).each do |v|
                # Only include voivodeships that have towns with posts
                towns_in_v = @towns_with_posts.select { |t| t.voivodeship_slug == v.slug }
                next if towns_in_v.empty?

                json.object do
                  json.field("name", v.name)
                  json.field("slug", v.slug)
                  json.field("show_url", context.router.area_show_url(v))
                end
              end
            end
          end
          json.field "towns" do
            json.array do
              @towns_with_posts.sort_by(&.name).each do |town|
                posts = context.posts_for_area(town)
                next if posts.empty?

                dates = posts.map(&.time).sort
                best_photo = @selector.best_unique_photo_for(town)

                json.object do
                  json.field("name", town.name)
                  json.field("slug", town.slug)
                  json.field("voivodeship", town.voivodeship_slug || "")
                  json.field("show_url", context.router.area_show_url(town))
                  json.field("post_count", posts.size)
                  json.field("photo_url", best_photo ? best_photo.grid_image_src : "")
                  json.field("first_year", dates.first.year)
                  json.field("last_year", dates.last.year)
                end
              end
            end
          end
        end
      end
    end
  end
end
