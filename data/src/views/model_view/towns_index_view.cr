require "../page_view"

module ModelView
  class TownsIndexView < PageView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("towns")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
      @subtitle = meta[:subtitle].as(String)

      @posts = context.posts.as(Array(Tremolite::Post))
    end

    def add_to_sitemap?
      true
    end

    getter :image_url, :title, :subtitle

    def inner_html
      s = "<ol>"

      context.voivodeships.each do |voivodeship|
        s += "<li>\n<h2>#{voivodeship.name}</h2>\n"
        s += "<ol>\n"

        context.towns.select { |t| t.voivodeship == voivodeship.slug }.each do |town|
          s += town_element(town)
        end

        s += "</ol></li>\n"
      end

      return s
    end

    def town_element(town)
      s = "<li><a href=\"#{town.view_url}\">#{town.name}</a>"

      if town.lat && town.lon
        # s += "<a class=\"small\" href"
        ump_link = "http://mapa.ump.waw.pl/ump-www/?zoom=13&lat=#{town.lat}&lon=#{town.lon}&layers=B000000FFFFTFF&mlat=#{town.lat}&mlon=#{town.lon}"
        s += " <a href=\"#{ump_link}\" target=\"_blank\"><span class=\"small glyphicon glyphicon-map-marker\"></span></a>"
      end

      # posts
      posts_for_town = @posts.select { |post| post.towns && post.towns.not_nil!.includes?(town.slug) }
      if posts_for_town.size > 0
        # s += " - #{posts_for_town.size} wpisów od "
        s += " - od "
        s += "<strong>"
        s += posts_for_town.sort { |a, b| a.time <=> b.time }.first.date
        s += "</strong>"
      end

      s += "</li>\n"
      return s
    end
  end
end
