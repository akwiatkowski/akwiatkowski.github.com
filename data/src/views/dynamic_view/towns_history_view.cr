module DynamicView
  class TownsHistoryView < PageView
    Log = ::Log.for(self)

    def initialize(context : RenderContext, @url : String)
      super(context: context, url: @url)
      meta = context.page_meta("towns_history")
      @image_url = meta[:backgrounds].as(String)
      @title = meta[:title].as(String)
      @subtitle = meta[:subtitle].as(String)

      @posts = context.posts.as(Array(Tremolite::Post))
      # Use unified AreaEntity system
      @towns = context.areas_of_type(AreaType::Town).as(Array(AreaEntity))
      @voivodeships = context.areas_of_type(AreaType::Voivodeship).as(Array(AreaEntity))
    end

    # a bit internal at this moment
    def add_to_sitemap?
      return false
    end

    getter :image_url, :title, :subtitle

    def inner_html
      s = ""
      s += "<p>"
      s += "Razem <strong>#{@towns.size}</strong> zdefiniowanych gmin, "
      s += "a <strong>#{town_hike_or_bicycle}</strong> zaliczone pieszo lub rowerem."
      s += "</p>\n"

      s += "<ol>\n"

      @voivodeships.each do |voivodeship|
        towns = Array(Tuple(AreaEntity, Time)).new
        towns_in_voivodeship(voivodeship).each do |t|
          vt = visited_since(t)
          towns << {t, vt.not_nil!} unless vt.nil?
        end

        s += "<li>\n<h2>#{voivodeship.name} - #{towns.size} gmin</h2>\n"
        s += "<ol>\n"

        towns.sort { |a, b| a[1] <=> b[1] }.map { |a| a[0] }.each do |town|
          s += town_element(town)
        end

        s += "</ol></li>\n"
      end

      return s
    end

    def towns_in_voivodeship(voivodeship : AreaEntity)
      @towns.select { |t| t.voivodeship_slug == voivodeship.slug }
    end

    def visited_since(town : AreaEntity)
      posts_for_town = @posts.select { |post| post.towns && post.towns.not_nil!.includes?(town.slug) }
      if posts_for_town.size > 0
        return posts_for_town.sort { |a, b| a.time <=> b.time }.first.time
      else
        return nil
      end
    end

    def town_element(town : AreaEntity)
      s = "<li><a href=\"#{town.show_url}\">#{town.name}</a>"

      if town.lat && town.lon
        lat = town.lat.not_nil!
        lon = town.lon.not_nil!
        ump_link = "http://mapa.ump.waw.pl/ump-www/?zoom=13&lat=#{lat}&lon=#{lon}&layers=B000000FFFFTFF&mlat=#{lat}&mlon=#{lon}"
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

    def town_hike_or_bicycle
      @posts.select { |p| p.bicycle? || p.hike? }.map { |p| p.towns.not_nil! }.flatten.uniq.size
    end
  end
end
