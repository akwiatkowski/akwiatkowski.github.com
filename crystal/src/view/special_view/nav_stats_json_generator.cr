require "json"

module SpecialView
  class NavStatsJsonGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/nav_stats.json",
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
      nav_stats_cache = @context.nav_stats_cache

      result = JSON.build do |json|
        json.object do
          json.field "post_counts" do
            json.array do
              nav_stats_cache.stats.voivodeships_nav.each do |nav|
                json.object do
                  json.field("name", nav.name)
                  json.field("slug", nav.slug)
                  json.field("type", nav.type)
                  json.field("url", nav.url)
                  json.field("count", nav.count)
                  json.field("html_id", nav.html_id)
                end
              end

              nav_stats_cache.stats.lands_nav.each do |nav|
                json.object do
                  json.field("name", nav.name)
                  json.field("slug", nav.slug)
                  json.field("type", nav.type)
                  json.field("url", nav.url)
                  json.field("count", nav.count)
                  json.field("html_id", nav.html_id)
                end
              end

              nav_stats_cache.stats.tags_nav.each do |nav|
                json.object do
                  json.field("name", nav.name)
                  json.field("slug", nav.slug)
                  json.field("type", nav.type)
                  json.field("url", nav.url)
                  json.field("count", nav.count)
                  json.field("html_id", nav.html_id)
                end
              end
            end
          end
        end
      end
    end
  end
end
